#include <std_include.hpp>
#include "loader/component_loader.hpp"

#include "command.hpp"
#include "console.hpp"
#include "lobby_bots.hpp"
#include "public_lobby.hpp"
#include "scheduler.hpp"
#include "gsc/script_extension.hpp"

#include "game/game.hpp"

#include <utils/hook.hpp>
#include <utils/io.hpp>
#include <utils/string.hpp>

#include <random>
#include <unordered_map>

// Bots que entran en la sala pública como si fueran jugadores (como lobby_bots de s1-mod).
//
// Se añaden como miembros del party de la sala (0x1439228B0): salen en la lista con su nombre, rango y prestigio y
// se reparten en los equipos de la sala. Cuántos entran lo deciden los bots de Configurar partida (aliados y
// enemigos, o todos contra todos), y son los mismos que entran en la partida: el juego los crea con
// bot_SystemStatus 2 y cada bot toma el nombre de un miembro de la sala (bots.cpp, SV_BotGetRandomName).
//
// Party (Lobby.GetMemberName, 0x140360320): miembros en +0x1C8 + i * 0x270 (18)
// Miembro:
//   +0x000 uint8 estado (0 libre, 5 dentro de la sala)       +0x008 uint64 id del party privado del miembro
//   +0x010 rango (0..54)  +0x014 prestigio  +0x02C nombre (32)  +0x04C clan
//   +0x1B8 netadr         +0x1C8 último paquete               +0x218 equipo (1 axis, 2 allies)
//   +0x21E uint16 puntuación  +0x220 muertes (lista de la sala, 0x140360FD0)
//   +0x230 xuid

namespace lobby_bots
{
	namespace
	{
		constexpr auto max_members = 18;
		constexpr auto member_size = 0x270;

		namespace member
		{
			constexpr auto status = 0x0;
			constexpr auto party_id = 0x8;
			constexpr auto rank = 0x10;
			constexpr auto prestige = 0x14;
			constexpr auto name = 0x2C;
			constexpr auto name_size = 32;
			constexpr auto clan_tag = 0x4C;
			constexpr auto address = 0x1B8;
			constexpr auto last_packet = 0x1C8;
			constexpr auto team = 0x218;
			constexpr auto score = 0x21E;
			constexpr auto deaths = 0x220;
			constexpr auto xuid = 0x230;
		}

		constexpr std::uint8_t status_in_lobby = 5;

		std::recursive_mutex mutex;
		std::vector<std::uint64_t> fake_xuids{};
		int next_join_time = 0;
		bool first_wave_done = false;
		bool was_in_match = false;
		bool match_from_lobby = false; // la partida se ha iniciado desde la sala (Iniciar partida)
		int match_wait_start = 0;

		// Nombres de los bots de la sala para los bots de la partida, en orden
		std::deque<std::string> match_names{};
		bool picking_lobby_name = false; // pick_name pide nombres a SV_BotGetRandomName sin gastar los de la partida

		// Puntuación y muertes de cada bot en la última partida (scripts/mp/lobby_bots.gsc): el juego solo pone las
		// de los jugadores de verdad, así que se vuelven a poner en cada actualización
		std::unordered_map<std::string, std::pair<int, int>> match_stats{};

		std::uint8_t* lobby_party()
		{
			return reinterpret_cast<std::uint8_t*>(0x39228B0_b);
		}

		template <typename... Args>
		void write_log(const char* fmt, Args... args)
		{
			console::info("%s", utils::string::va(fmt, args...));
		}

		std::mt19937& rng()
		{
			static std::mt19937 engine{std::random_device{}()};
			return engine;
		}

		int random_int(const int min, const int max)
		{
			std::uniform_int_distribution<int> distribution(min, std::max(min, max));
			return distribution(rng());
		}

		std::uint8_t* get_member(const int index)
		{
			return lobby_party() + 0x1C8 + index * member_size;
		}

		template <typename T>
		T& field(std::uint8_t* m, const std::size_t offset)
		{
			return *reinterpret_cast<T*>(m + offset);
		}

		bool is_in_match()
		{
			return game::CL_IsCgameInitialized() && !game::VirtualLobby_Loaded();
		}

		bool is_fake(const std::uint64_t xuid)
		{
			return std::find(fake_xuids.begin(), fake_xuids.end(), xuid) != fake_xuids.end();
		}

		bool is_active(std::uint8_t* m)
		{
			return field<std::uint8_t>(m, member::status) >= status_in_lobby;
		}

		bool is_fake_member(std::uint8_t* m)
		{
			return is_active(m) && is_fake(field<std::uint64_t>(m, member::xuid));
		}

		void mark_party_dirty()
		{
			utils::hook::invoke<void>(0x3536B0_b, lobby_party()); // aviso de cambio del party
		}

		std::string get_member_name(std::uint8_t* m)
		{
			const auto* name = reinterpret_cast<const char*>(m + member::name);
			return {name, strnlen(name, member::name_size)};
		}

		bool is_name_taken(const std::string& name)
		{
			for (auto i = 0; i < max_members; ++i)
			{
				auto* m = get_member(i);
				if (is_active(m) && utils::string::to_lower(get_member_name(m)) == utils::string::to_lower(name))
				{
					return true;
				}
			}

			return false;
		}

		std::string pick_name()
		{
			picking_lobby_name = true;
			const auto _ = gsl::finally([]
			{
				picking_lobby_name = false;
			});

			for (auto attempt = 0; attempt < 20; ++attempt)
			{
				const auto* name = game::SV_BotGetRandomName();
				if (name && *name && !is_name_taken(name))
				{
					return std::string(name).substr(0, 15);
				}
			}

			for (auto i = 1;; ++i)
			{
				auto name = utils::string::va("Player%d", random_int(100, 9999) + i);
				if (!is_name_taken(name))
				{
					return name;
				}
			}
		}

		void roll_rank(int& rank, int& prestige)
		{
			const auto roll = random_int(0, 99);
			if (roll < 35)
			{
				prestige = 0;
				rank = random_int(0, 54);
			}
			else if (roll < 75)
			{
				prestige = random_int(1, 5);
				rank = random_int(0, 54);
			}
			else
			{
				prestige = random_int(6, 10);
				rank = random_int(20, 54);
			}
		}

		std::uint8_t* find_host_member()
		{
			for (auto i = 0; i < max_members; ++i)
			{
				auto* m = get_member(i);
				if (is_active(m) && !is_fake(field<std::uint64_t>(m, member::xuid)))
				{
					return m;
				}
			}

			return nullptr;
		}

		// Bots de Configurar partida (reglas de la partida privada, 0x1402C1190): aliados, enemigos y todos contra todos
		int get_bots_limit(const int team)
		{
			return utils::hook::invoke<int>(0x2C1190_b, team);
		}

		// Modo de Configurar partida con o sin equipos: lo dice el menú de la sala (lobbybots_teambased,
		// public_lobby/__init__.lua). Desde aquí no se pueden leer bien los dvars de la sala (Dvar_FindVar)
		std::atomic_bool team_based_mode{true};

		// Bots de la sala que manda el menú (lobbybots_teambased modo aliados enemigos): en los modos sin equipos
		// 0x1402C1190 no da los de todos contra todos. -1 = sin datos del menú
		std::atomic_int menu_friendly_bots{-1};
		std::atomic_int menu_enemy_bots{-1};

		bool is_team_based()
		{
			return team_based_mode;
		}

		int get_target_bots(int& friendly, int& enemy)
		{
			if (menu_friendly_bots >= 0 && menu_enemy_bots >= 0)
			{
				friendly = menu_friendly_bots;
				enemy = menu_enemy_bots;
			}
			else if (is_team_based())
			{
				friendly = get_bots_limit(0);
				enemy = get_bots_limit(1);
			}
			else
			{
				friendly = 0;
				enemy = get_bots_limit(2);
			}

			// Todos los huecos de la sala menos el del host (la sala pública admite 18, public_lobby/__init__.lua)
			constexpr auto max_bots = max_members - 1;
			const auto total = std::min(friendly + enemy, max_bots);
			if (friendly + enemy > total)
			{
				enemy = std::min(enemy, total);
				friendly = total - enemy;
			}

			return total;
		}

		std::vector<std::uint8_t*> get_fake_members()
		{
			std::vector<std::uint8_t*> members{};
			for (auto i = 0; i < max_members; ++i)
			{
				auto* m = get_member(i);
				if (is_fake_member(m))
				{
					members.push_back(m);
				}
			}

			return members;
		}

		bool add_fake_member()
		{
			auto* host = find_host_member();
			if (!host)
			{
				return false;
			}

			// Huecos detrás del host (la sala virtual reparte los personajes por número de miembro)
			auto host_index = 0;
			for (auto i = 0; i < max_members; ++i)
			{
				if (get_member(i) == host)
				{
					host_index = i;
					break;
				}
			}

			std::uint8_t* slot = nullptr;
			for (auto pass = 0; pass < 2 && !slot; ++pass)
			{
				for (auto i = pass == 0 ? host_index + 1 : 0; i < max_members; ++i)
				{
					auto* m = get_member(i);
					if (field<std::uint8_t>(m, member::status) == 0)
					{
						slot = m;
						break;
					}
				}
			}

			if (!slot)
			{
				return false;
			}

			// Se copia el miembro del host (datos de sesión, mapas) y se cambia la identidad
			std::memcpy(slot, host, member_size);

			std::uint64_t xuid{};
			do
			{
				xuid = 0x0110000100000000ull | static_cast<std::uint32_t>(rng()());
			}
			while (!xuid || is_fake(xuid));

			const auto name = pick_name();
			int rank{}, prestige{};
			roll_rank(rank, prestige);

			field<std::uint64_t>(slot, member::xuid) = xuid;
			field<std::uint64_t>(slot, member::party_id) = (static_cast<std::uint64_t>(rng()()) << 32) | rng()();
			field<int>(slot, member::rank) = rank;
			field<int>(slot, member::prestige) = prestige;
			std::memset(slot + member::clan_tag, 0, 5);

			std::memset(slot + member::name, 0, member::name_size);
			std::memcpy(slot + member::name, name.data(), std::min<std::size_t>(name.size(), member::name_size - 1));

			field<int>(slot, member::team) = 0;
			field<std::uint16_t>(slot, member::score) = 0;
			field<int>(slot, member::deaths) = 0;

			// NA_BOT: el juego no envía nada a esta dirección
			std::memset(slot + member::address, 0, 0x10);
			field<int>(slot, member::last_packet) = game::Sys_Milliseconds();

			fake_xuids.push_back(xuid);
			field<std::uint8_t>(slot, member::status) = status_in_lobby;

			mark_party_dirty();
			write_log("[lobby_bots] %s joined the lobby (rank %d, prestige %d)\n", name.data(), rank + 1, prestige);
			return true;
		}

		void remove_fake_member(std::uint8_t* m)
		{
			const auto xuid = field<std::uint64_t>(m, member::xuid);
			write_log("[lobby_bots] %s left the lobby\n", get_member_name(m).data());

			std::memset(m, 0, member_size);
			fake_xuids.erase(std::remove(fake_xuids.begin(), fake_xuids.end(), xuid), fake_xuids.end());
			mark_party_dirty();
		}

		void remove_all_fake_members()
		{
			for (auto i = 0; i < max_members; ++i)
			{
				auto* m = get_member(i);
				if (is_fake_member(m))
				{
					remove_fake_member(m);
				}
			}

			fake_xuids.clear();
		}

		// Equipo del host antes de ponerlo sin equipo en todos contra todos (se le devuelve en los modos con equipos)
		int saved_host_team = 0;

		// Equipos de la sala: los aliados con el equipo del host y los enemigos con el otro (sin equipo elegido, el host
		// cuenta como allies). En todos contra todos, todos sin equipo, también el host: con equipo, en la sala salía
		// aparte y en la partida no salía en la lista de jugadores (con los bots en su equipo no entraban en la partida).
		void assign_teams(const int friendly)
		{
			auto* host = find_host_member();
			const auto team_based = is_team_based();
			auto changed = false;

			if (host)
			{
				auto& team = field<int>(host, member::team);
				if (!team_based && team != 0)
				{
					saved_host_team = team;
					team = 0;
					changed = true;
				}
				else if (team_based && team == 0 && saved_host_team != 0)
				{
					team = saved_host_team;
					saved_host_team = 0;
					changed = true;
				}
			}

			auto host_team = host ? field<int>(host, member::team) : 0;
			if (host_team != 1 && host_team != 2)
			{
				host_team = 2;
			}

			const auto enemy_team = host_team == 1 ? 2 : 1;

			auto index = 0;
			for (auto* m : get_fake_members())
			{
				const auto team = !team_based ? 0 : index < friendly ? host_team : enemy_team;
				++index;

				if (field<int>(m, member::team) != team)
				{
					field<int>(m, member::team) = team;
					changed = true;
				}
			}

			if (changed)
			{
				mark_party_dirty();
			}
		}

		void schedule_next_join()
		{
			next_join_time = game::Sys_Milliseconds() + (first_wave_done ? random_int(1000, 3000) : random_int(100, 300));
		}

		void apply_match_stats()
		{
			auto changed = false;
			for (auto* m : get_fake_members())
			{
				const auto entry = match_stats.find(get_member_name(m));
				if (entry == match_stats.end())
				{
					continue;
				}

				const auto score = static_cast<std::uint16_t>(std::clamp(entry->second.first, 0, 0xFFFF));
				const auto deaths = std::max(entry->second.second, 0);
				if (field<std::uint16_t>(m, member::score) != score || field<int>(m, member::deaths) != deaths)
				{
					field<std::uint16_t>(m, member::score) = score;
					field<int>(m, member::deaths) = deaths;
					changed = true;
				}
			}

			if (changed)
			{
				mark_party_dirty();
			}
		}

		void update()
		{
			std::lock_guard _(mutex);

			// Mientras se carga y se juega la partida los bots siguen en la sala (con su nombre, rango y puntuación).
			// En la partida el party deja de parecer la sala pública, así que se mira si la partida viene de la sala
			// (prepare_match_bots) y, al acabar, se espera a volver a ella
			if (match_from_lobby)
			{
				const auto now = game::Sys_Milliseconds();
				if (is_in_match())
				{
					was_in_match = true;
					match_wait_start = now;
					return;
				}

				if (!public_lobby::is_public_lobby())
				{
					if (!match_wait_start)
					{
						match_wait_start = now;
					}

					// Cargando la partida o volviendo de ella: hasta 60 s antes de dar la sala por abandonada
					if (now - match_wait_start < 60000)
					{
						return;
					}

					match_from_lobby = false;
				}
				else
				{
					match_wait_start = 0;
					if (was_in_match)
					{
						match_from_lobby = false;
					}
				}
			}

			if (!public_lobby::is_public_lobby())
			{
				match_stats.clear();
				if (!fake_xuids.empty())
				{
					remove_all_fake_members();
				}

				first_wave_done = false;
				was_in_match = false;
				return;
			}

			if (was_in_match)
			{
				was_in_match = false;
				match_names.clear();
				schedule_next_join();
			}

			// Los bots siguen conectados para el juego
			const auto now = game::Sys_Milliseconds();
			for (auto* m : get_fake_members())
			{
				field<int>(m, member::last_packet) = now;
			}

			int friendly{}, enemy{};
			const auto target = get_target_bots(friendly, enemy);
			auto members = get_fake_members();

			// Sobran bots (se han bajado en Configurar partida): se van los últimos
			while (static_cast<int>(members.size()) > target)
			{
				remove_fake_member(members.back());
				members.pop_back();
			}

			// Faltan: la primera tanda entra casi seguida y el resto de uno en uno
			if (static_cast<int>(members.size()) < target && now >= next_join_time)
			{
				add_fake_member();
				if (static_cast<int>(get_fake_members().size()) >= target * 2 / 3)
				{
					first_wave_done = true;
				}

				schedule_next_join();
			}

			assign_teams(friendly);
			apply_match_stats();
		}
	}

	std::optional<std::string> take_match_bot_name()
	{
		std::lock_guard _(mutex);

		if (picking_lobby_name || match_names.empty())
		{
			return {};
		}

		auto name = match_names.front();
		match_names.pop_front();
		return name;
	}

	void prepare_match_bots()
	{
		std::lock_guard _(mutex);

		match_names.clear();
		match_stats.clear();
		match_from_lobby = true;
		match_wait_start = 0;
		for (auto* m : get_fake_members())
		{
			match_names.push_back(get_member_name(m));
		}

		write_log("[lobby_bots] match starts with %zu lobby bots\n", match_names.size());
	}

	class component final : public component_interface
	{
	public:
		void post_unpack() override
		{
			if (!game::environment::is_mp())
			{
				return;
			}

			command::add("lobbybots_teambased", [](const command::params& params)
			{
				if (params.size() >= 2)
				{
					team_based_mode = std::atoi(params.get(1)) != 0;
				}

				if (params.size() >= 4)
				{
					menu_friendly_bots = std::max(std::atoi(params.get(2)), 0);
					menu_enemy_bots = std::max(std::atoi(params.get(3)), 0);
				}
			});

			// lobbybotsetstats(name, score, deaths): puntuación de un bot de la sala al acabar la partida
			gsc::function::add("lobbybotsetstats", [](const gsc::function_args& args)
			{
				std::lock_guard _(mutex);
				const auto name = args[0].as<std::string>();
				match_stats[name] = {args[1].as<int>(), args[2].as<int>()};
				write_log("[lobby_bots] %s: score %d, deaths %d\n", name.data(), args[1].as<int>(), args[2].as<int>());
				return true;
			});
			scheduler::loop(update, scheduler::pipeline::main, 100ms);
		}
	};
}

REGISTER_COMPONENT(lobby_bots::component)
