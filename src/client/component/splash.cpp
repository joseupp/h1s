#include <std_include.hpp>
#include "loader/component_loader.hpp"
#include "game/game.hpp"
#include "scheduler.hpp"

#include <utils/hook.hpp>

// Pantalla de carga al arrancar: la imagen original del juego (mapa de bits 100 de h1_mp64_ship.exe, la misma que
// mostraría el juego) a pantalla completa desde que se lanza h1s, también mientras se desencripta el ejecutable
// (Arxan, antes de post_unpack). Va siempre encima de todo (también de la ventana del juego, que está en negro unos
// segundos mientras carga); cuando el juego cierra su propia pantalla de carga (0x5BE1D0 / 0x5BE210) y ha dibujado
// fotogramas durante un momento, se cierra. La ventana va en su propio hilo para
// que se siga pintando mientras el hilo principal está ocupado desencriptando y cargando.

namespace splash
{
	namespace
	{
		constexpr auto class_name = "H1S Splash Screen";

		std::mutex mutex;
		std::thread thread;
		HWND window{};
		HBITMAP image{};
		int image_width{};
		int image_height{};

		HBITMAP load_image()
		{
			// Solo los recursos del ejecutable original, sin cargarlo como programa
			auto* const module = LoadLibraryExA("h1_mp64_ship.exe", nullptr,
				LOAD_LIBRARY_AS_DATAFILE | LOAD_LIBRARY_AS_IMAGE_RESOURCE);
			if (!module)
			{
				return nullptr;
			}

			auto* const bitmap = static_cast<HBITMAP>(LoadImageA(module, MAKEINTRESOURCEA(100), IMAGE_BITMAP, 0, 0,
				LR_CREATEDIBSECTION));
			FreeLibrary(module);
			return bitmap;
		}

		void paint(HWND hwnd)
		{
			PAINTSTRUCT ps{};
			auto* const dc = BeginPaint(hwnd, &ps);

			RECT rect{};
			GetClientRect(hwnd, &rect);
			const auto width = rect.right - rect.left;
			const auto height = rect.bottom - rect.top;

			FillRect(dc, &rect, static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH)));

			if (image && image_width > 0 && image_height > 0)
			{
				// Ocupa toda la pantalla sin deformarse (franjas negras si la proporción no es la misma)
				const auto scale_x = static_cast<double>(width) / image_width;
				const auto scale_y = static_cast<double>(height) / image_height;
				const auto scale = scale_x < scale_y ? scale_x : scale_y;
				const auto draw_width = static_cast<int>(image_width * scale);
				const auto draw_height = static_cast<int>(image_height * scale);
				const auto x = (width - draw_width) / 2;
				const auto y = (height - draw_height) / 2;

				auto* const memory_dc = CreateCompatibleDC(dc);
				auto* const old = SelectObject(memory_dc, image);
				SetStretchBltMode(dc, HALFTONE);
				SetBrushOrgEx(dc, 0, 0, nullptr);
				StretchBlt(dc, x, y, draw_width, draw_height, memory_dc, 0, 0, image_width, image_height, SRCCOPY);
				SelectObject(memory_dc, old);
				DeleteDC(memory_dc);
			}

			EndPaint(hwnd, &ps);
		}

		// Ventana del juego (la otra ventana visible del proceso)
		HWND find_game_window(HWND splash_window)
		{
			struct search
			{
				HWND splash;
				HWND result;
			} data{splash_window, nullptr};

			EnumWindows([](HWND hwnd, LPARAM param) -> BOOL
			{
				auto* const data = reinterpret_cast<search*>(param);
				DWORD pid{};
				GetWindowThreadProcessId(hwnd, &pid);
				if (hwnd != data->splash && pid == GetCurrentProcessId() && IsWindowVisible(hwnd)
					&& !GetWindow(hwnd, GW_OWNER))
				{
					data->result = hwnd;
					return FALSE;
				}
				return TRUE;
			}, reinterpret_cast<LPARAM>(&data));

			return data.result;
		}

		LRESULT CALLBACK window_proc(HWND hwnd, const UINT message, const WPARAM w_param, const LPARAM l_param)
		{
			switch (message)
			{
			case WM_PAINT:
				paint(hwnd);
				return 0;
			case WM_ERASEBKGND:
				return 1;
			case WM_TIMER:
				// Siempre por encima de todo, también de la ventana del juego en cuanto aparece (en negro mientras carga)
				SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
				return 0;
			case WM_CLOSE:
				// La pantalla de carga tiene el foco: se lo pasa a la ventana del juego para que no quede detrás
				if (auto* const game_window = find_game_window(hwnd))
				{
					SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
					SetForegroundWindow(game_window);
					BringWindowToTop(game_window);
				}
				DestroyWindow(hwnd);
				return 0;
			case WM_DESTROY:
				PostQuitMessage(0);
				return 0;
			default:
				return DefWindowProcA(hwnd, message, w_param, l_param);
			}
		}

		void run(const HANDLE ready)
		{
			auto* const instance = GetModuleHandleA(nullptr);

			WNDCLASSA wnd_class{};
			wnd_class.lpfnWndProc = window_proc;
			wnd_class.hInstance = instance;
			wnd_class.hIcon = LoadIconA(instance, MAKEINTRESOURCEA(102));
			wnd_class.hCursor = LoadCursorA(nullptr, IDC_APPSTARTING);
			wnd_class.hbrBackground = static_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));
			wnd_class.lpszClassName = class_name;
			RegisterClassA(&wnd_class);

			// Pantalla completa en el monitor principal
			const auto screen_width = GetSystemMetrics(SM_CXSCREEN);
			const auto screen_height = GetSystemMetrics(SM_CYSCREEN);

			auto* const hwnd = CreateWindowExA(WS_EX_APPWINDOW | WS_EX_TOPMOST, class_name, "H1S", WS_POPUP, 0, 0, screen_width,
				screen_height, nullptr, nullptr, instance, nullptr);

			{
				std::lock_guard _(mutex);
				window = hwnd;
			}

			SetEvent(ready);

			if (!hwnd)
			{
				return;
			}

			ShowWindow(hwnd, SW_SHOW);
			UpdateWindow(hwnd);
			SetTimer(hwnd, 1, 50, nullptr);

			MSG msg{};
			while (GetMessageA(&msg, nullptr, 0, 0) > 0)
			{
				TranslateMessage(&msg);
				DispatchMessageA(&msg);
			}

			{
				std::lock_guard _(mutex);
				window = nullptr;
			}

			UnregisterClassA(class_name, instance);
		}

		void show()
		{
			image = load_image();
			if (image)
			{
				BITMAP info{};
				GetObjectA(image, sizeof(info), &info);
				image_width = info.bmWidth;
				image_height = std::abs(info.bmHeight);
			}

			auto* const ready = CreateEventA(nullptr, TRUE, FALSE, nullptr);
			thread = std::thread([ready]
			{
				run(ready);
			});

			// Que la ventana exista antes de seguir (si el juego la cierra enseguida, se cierra de verdad)
			WaitForSingleObject(ready, 2000);
			CloseHandle(ready);
		}

		void destroy()
		{
			// Puede llamarse a la vez desde el renderer y al cerrar el juego
			static std::mutex destroy_mutex;
			std::lock_guard destroy_lock(destroy_mutex);

			{
				std::lock_guard _(mutex);
				if (window)
				{
					PostMessageA(window, WM_CLOSE, 0, 0);
				}
			}

			if (thread.joinable())
			{
				thread.join();
			}

			if (image)
			{
				DeleteObject(image);
				image = nullptr;
			}
		}

		// El juego cierra su pantalla de carga: su ventana ya existe pero aún no dibuja nada
		void game_window_created_stub()
		{
			static std::atomic_bool done{false};
			if (done.exchange(true))
			{
				return;
			}

			// Se cierra cuando el juego lleva un momento dibujando fotogramas
			scheduler::schedule([]
			{
				static const auto first_frame = std::chrono::steady_clock::now();
				if (std::chrono::steady_clock::now() - first_frame < 500ms)
				{
					return scheduler::cond_continue;
				}

				std::thread(destroy).detach();
				return scheduler::cond_end;
			}, scheduler::pipeline::renderer);
		}
	}

	class component final : public component_interface
	{
	public:
		void post_load() override
		{
			if (game::environment::is_dedi())
			{
				return;
			}

			show();
		}

		void post_unpack() override
		{
			if (game::environment::is_dedi())
			{
				return;
			}

			// La pantalla de carga del juego no se muestra (la nuestra ya está); al cerrarla se cierra la nuestra
			utils::hook::set<uint8_t>(SELECT_VALUE(0x462B90_b, 0x5BDF20_b), 0xC3);
			utils::hook::jump(SELECT_VALUE(0x462E40_b, 0x5BE1D0_b), game_window_created_stub, true);
			utils::hook::jump(SELECT_VALUE(0x462E80_b, 0x5BE210_b), game_window_created_stub, true);
		}

		void pre_destroy() override
		{
			destroy();
		}
	};
}

// Desactivada (como en s1s): sin pantalla de carga propia a pantalla completa, queda la del juego
// REGISTER_COMPONENT(splash::component)
