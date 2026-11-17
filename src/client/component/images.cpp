#include <std_include.hpp>
#include "loader/component_loader.hpp"

#include "images.hpp"
#include "console.hpp"
#include "filesystem.hpp"

#include "game/game.hpp"

#include <utils/hook.hpp>
#include <utils/string.hpp>
#include <utils/image.hpp>
#include <utils/io.hpp>
#include <utils/concurrency.hpp>

#include <unordered_set>

// Reemplazo de imágenes: images/<nombre de la imagen>.png (o images/materials/<nombre>.png) sustituye a la del juego.
//
// Las imágenes se crean en dos sitios:
//   0x1406829C0 (load_texture_db): al cargar el fastfile, todas (también las 2D de la interfaz, que llevan los píxeles
//                en el propio fastfile y no pasan por el streaming: por eso no se cambiaban los iconos del mando)
//   0x1400A37A0 (load_texture):    streaming de los niveles de mip de alta resolución desde los .pak
// Y el streaming (0x1400A4AA0, setup_texture) vuelve a crear la textura de la imagen cuando cambia de nivel: con el
// nivel 0 la rehace con los píxeles del fastfile (0x1406829C0 sobre una copia) y salía la original en mitad de la
// partida. A las imágenes reemplazadas se les pone picmip/cardMemory a -1 para que el streaming no las toque.

namespace images
{
	namespace
	{
		utils::hook::detour load_texture_hook;
		utils::hook::detour load_texture_db_hook;
		utils::hook::detour setup_texture_hook;
		utils::concurrency::container<std::unordered_map<std::string, std::string>> overriden_textures;

		// Imágenes sin archivo de reemplazo: no se vuelve a buscar el archivo cada vez que se cargan
		utils::concurrency::container<std::unordered_set<std::string>> missing_images;

		std::optional<std::string> load_image(game::GfxImage* image)
		{
			if (!image || !image->name || !*image->name)
			{
				return {};
			}

			std::string data{};
			overriden_textures.access([&](const std::unordered_map<std::string, std::string>& textures)
			{
				if (const auto i = textures.find(image->name); i != textures.end())
				{
					data = i->second;
				}
			});

			if (!data.empty())
			{
				return {std::move(data)};
			}

			const std::string name = image->name;
			const auto missing = missing_images.access<bool>([&](const std::unordered_set<std::string>& images)
			{
				return images.contains(name);
			});

			if (missing)
			{
				return {};
			}

			if (!filesystem::read_file(utils::string::va("images/%s.png", name.data()), &data) &&
				!filesystem::read_file(utils::string::va("images/materials/%s.png", name.data()), &data))
			{
				missing_images.access([&](std::unordered_set<std::string>& images)
				{
					images.insert(name);
				});
				return {};
			}

			return {std::move(data)};
		}

		std::optional<utils::image> load_raw_image_from_file(game::GfxImage* image)
		{
			const auto image_file = load_image(image);
			if (!image_file)
			{
				return {};
			}

			return utils::image(*image_file);
		}

		bool load_custom_texture(game::GfxImage* image)
		{
			auto raw_image = load_raw_image_from_file(image);
			if (!raw_image)
			{
				return false;
			}

			image->mapType = game::MAPTYPE_2D;
			image->semantic = 2;
			image->category = 3;
			image->flags = 0;

			D3D11_SUBRESOURCE_DATA data{};
			data.SysMemPitch = raw_image->get_width() * 4;
			data.SysMemSlicePitch = data.SysMemPitch * raw_image->get_height();
			data.pSysMem = raw_image->get_buffer();

			game::Image_Setup(image, raw_image->get_width(), raw_image->get_height(), image->depth, image->numElements,
				image->mapType, DXGI_FORMAT_R8G8B8A8_UNORM, image->name, &data);

			// Fuera del streaming (setup_texture_stub): si no, vuelve a poner la textura original
			*reinterpret_cast<int*>(&image->picmip) = -1;

			return true;
		}

		bool try_load_custom_texture(game::GfxImage* image)
		{
			try
			{
				return load_custom_texture(image);
			}
			catch (std::exception& e)
			{
				console::error("Failed to load image %s: %s\n", image->name, e.what());
			}

			return false;
		}

		void load_texture_stub(game::GfxImage* image, void* a2, int* a3)
		{
			if (try_load_custom_texture(image))
			{
				return;
			}

			load_texture_hook.invoke<void>(image, a2, a3);
		}

		void load_texture_db_stub(void* a1, game::GfxImage* image)
		{
			if (try_load_custom_texture(image))
			{
				return;
			}

			load_texture_db_hook.invoke<void>(a1, image);
		}

		int setup_texture_stub(game::GfxImage* image, void* a2, void* a3)
		{
			if (*(int*)&image->picmip == -1) // resourceSize
			{
				return 0;
			}

			return setup_texture_hook.invoke<bool>(image, a2, a3);
		}
	}

	void override_texture(std::string name, std::string data)
	{
		overriden_textures.access([&](std::unordered_map<std::string, std::string>& textures)
		{
			textures[std::move(name)] = std::move(data);
		});
	}

	class component final : public component_interface
	{
	public:
		void post_unpack() override
		{
			if (game::environment::is_dedi())
			{
				return;
			}

			setup_texture_hook.create(SELECT_VALUE(0x83300_b, 0xA4AA0_b), setup_texture_stub);
			load_texture_hook.create(SELECT_VALUE(0x82050_b, 0xA37A0_b), load_texture_stub);
			load_texture_db_hook.create(SELECT_VALUE(0x55F870_b, 0x6829C0_b), load_texture_db_stub);
		}
	};
}

REGISTER_COMPONENT(images::component)
