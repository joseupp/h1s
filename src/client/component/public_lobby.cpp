#include <std_include.hpp>
#include "loader/component_loader.hpp"

#include "command.hpp"
#include "console.hpp"
#include "lobby_bots.hpp"
#include "public_lobby.hpp"
#include "scheduler.hpp"

#include "game/game.hpp"

#include <utils/hook.hpp>

// Partida pública sin conexión.
//
// En H1 la búsqueda de partida la lleva un script de LUI que consulta Matchmaking.* (tabla 0x1408F3720). El juego
// ya nos hace anfitrión de la sala nada más entrar (party 0x1439228B0, +0x30BC), pero el script no la abre a la
// partida si el ancho de banda medido no basta para alojar una partida ("Cannot host server - insufficient
// bandwidth"): Matchmaking.IsBandwidthSufficient (0x140294B10) compara la subida medida (0x1405BBBE0) con la que
// pide la playlist, y sin Demonware la medida es 0. Se responde que sí.
// Se cambia el puntero de la tabla de LUI, no el código: Arxan comprueba el código.
//
// Con eso el script pasa a STARTING, pero la cuenta atrás la pone el anfitrión de la sala (0x1403528E0, estado
// +0x30EC & 0x7C == 4 -> +0x30A4 = fin de la cuenta atrás). Como en IW7, solo empieza si la sala la ha creado el
// emparejamiento de Steam (0x1401B4930: modo online y byte +0x30B8, llamada 0x1403529A9). Se da por buena, solo para
// el party de la sala pública (el privado también pasa por aquí).
// Antes de la cuenta atrás, 0x140356C60 (llamada 0x140352A33) desvía a anunciar / unir la sala de Steam
// (0x14035F000) si +0x3074 está puesto: en la sala pública sin conexión no se hace.
// Y sin conexión 0x1401AF9C0 (llamada 0x140352984: ¿podemos alojar party_maxplayers jugadores?, 0x1401A3140)
// responde que no y el anfitrión no pone la cuenta atrás (0x140352A91). Se responde que sí.
//
// Antes de todo eso, el anfitrión (0x140353370, party en rbx) sale si no hay sala de Steam: 0x1401D73E0 (ocupada,
// llamada 0x1403533C8), 0x1401D74A0 (sala válida, llamada 0x1403533D5) y 0x1401D7100 (id de la sala de Steam,
// llamada 0x1403533E2, tiene que coincidir con party + 0x30B0). Para la sala pública se responde como si la hubiera.
//
// La partida de la sala pública solo empieza con el botón "Iniciar partida" (lobby_partygo, ui_scripts/public_lobby),
// sin depender de party_minplayers: en la sala pública party_minplayers vale 1 tras pulsarlo y, antes, uno más que
// los miembros de la sala (llamadas a Dvar_GetInt 0x140183490 con party_minplayers: anfitrión, Matchmaking.* y textos
// de la sala). lobby_cancelstartserver lo anula y para la cuenta atrás.

namespace public_lobby
{
	namespace
	{
		// lua_State: +0x48 tope; cada valor ocupa 0x10 (+0x0 tipo, 1 = booleano; +0x8 valor)
		int push_true(std::uint8_t* state)
		{
			auto*& top = *reinterpret_cast<std::uint8_t**>(state + 0x48);
			*reinterpret_cast<std::uint32_t*>(top) = 1;
			*reinterpret_cast<std::uint32_t*>(top + 8) = 1;
			top += 0x10;
			return 1;
		}

		std::uint8_t* lobby_party()
		{
			return reinterpret_cast<std::uint8_t*>(0x39228B0_b);
		}

		std::atomic_bool game_start_requested{false};

		bool get_dvar_bool(const size_t dvar_ptr)
		{
			const auto* dvar = *reinterpret_cast<game::dvar_t**>(dvar_ptr);
			return dvar && utils::hook::invoke<bool>(0x183340_b, dvar); // Dvar_GetBool
		}

		int get_member_count(std::uint8_t* party)
		{
			return utils::hook::invoke<int>(0x34B790_b, party);
		}

		int party_minplayers_stub(game::dvar_t* dvar)
		{
			const auto value = utils::hook::invoke<int>(0x183490_b, dvar); // Dvar_GetInt
			if (!is_public_lobby())
			{
				return value;
			}

			if (game_start_requested)
			{
				return 1;
			}

			return std::max(value, get_member_count(lobby_party()) + 1);
		}

		void stop_countdown()
		{
			auto* party = lobby_party();
			auto& state = *reinterpret_cast<int*>(party + 0x30EC);
			if ((state & 0x7C) != 4)
			{
				state = (state & 0xFFFFFF87) | 4; // como 0x140352B98: vuelta a "esperando jugadores"
				*reinterpret_cast<int*>(party + 0x30A4) = 0;
				utils::hook::invoke<void>(0x3536B0_b, party); // aviso de cambio del party
			}
		}

		int party_can_host_stub(std::uint8_t* party, const int max_players)
		{
			if (party == lobby_party())
			{
				return 1;
			}

			return utils::hook::invoke<int>(0x1AF9C0_b, party, max_players);
		}

		int party_created_by_matchmaking_stub(std::uint8_t* party)
		{
			if (party == lobby_party())
			{
				return 1;
			}

			return utils::hook::invoke<int>(0x1B4930_b, party);
		}

		int party_should_advertise_stub(std::uint8_t* party, const int local)
		{
			if (party == lobby_party())
			{
				return 0;
			}

			return utils::hook::invoke<int>(0x356C60_b, party, local);
		}

		// Stubs en ensamblador: el party está en rbx en las tres llamadas
		void steam_lobby_busy_stub(utils::hook::assembler& a)
		{
			const auto original = a.newLabel();
			a.mov(rax, 0x39228B0_b);
			a.cmp(rbx, rax);
			a.jne(original);
			a.xor_(eax, eax);
			a.ret();
			a.bind(original);
			a.jmp(0x1D73E0_b);
		}

		void steam_lobby_valid_stub(utils::hook::assembler& a)
		{
			const auto original = a.newLabel();
			a.mov(rax, 0x39228B0_b);
			a.cmp(rbx, rax);
			a.jne(original);
			a.mov(eax, 1);
			a.ret();
			a.bind(original);
			a.jmp(0x1D74A0_b);
		}

		void steam_lobby_id_stub(utils::hook::assembler& a)
		{
			const auto original = a.newLabel();
			a.mov(rax, 0x39228B0_b);
			a.cmp(rbx, rax);
			a.jne(original);
			a.mov(rax, qword_ptr(rbx, 0x30B0));
			a.ret();
			a.bind(original);
			a.jmp(0x1D7100_b);
		}

		// GameStateInfo_GetInstance (0x1406FA790): el juego tiene dos juegos de reglas, el de la partida privada
		// (0x1406FA920 con 0) y el de la pública (con 1, el de la playlist). Solo usa el privado con
		// xblive_privatematch y el party de la sala como anfitrión (0x140349920). La sala pública usa también el
		// privado: así funcionan Configurar partida (mapa, modo, opciones y bots) y se aplica en la partida.
		void* game_state_info_get_instance_stub()
		{
			return utils::hook::invoke<void*>(0x6FA920_b, 0, 0);
		}

		// 0x1406FA8B0: índice de esas reglas (0 privada, 1 pública). MatchRules.SetData no cambia nada si no es 0, y
		// con 1 el party de la sala reinicia las reglas públicas (0x1406FAA20). Siempre las privadas, como arriba.
		int game_state_info_get_index_stub()
		{
			return 0;
		}

		// 0x1402C1110: ¿se pueden configurar bots? Solo en partida privada, sin conexión o en red local; en la sala
		// pública (en línea, sin red local) responde que no y Lobby.SetBotsTeamLimit / SetBotsDifficulty /
		// SetBotsConnectType no hacen nada. También lo usan usebots, cyclebotsdifficulty y la conexión de los bots.
		int bots_allowed_stub()
		{
			return 1;
		}

		int is_bandwidth_sufficient_stub(std::uint8_t* state)
		{
			return push_true(state);
		}
	}

	bool is_public_lobby()
	{
		const auto* party = lobby_party();
		// En el menú está cargada la sala virtual (Com_InFrontend da 0) y systemlink vale 1 en h1s sin conexión
		return (game::VirtualLobby_Loaded() || !game::CL_IsCgameInitialized()) &&
			*reinterpret_cast<const int*>(party + 0x30C4) && // en la sala
			*reinterpret_cast<const int*>(party + 0x30BC) && // somos el anfitrión
			*reinterpret_cast<const int*>(party + 0x30C0) && // party activo
			!get_dvar_bool(0xC9DC4F0_b); // xblive_privatematch
	}

	bool is_public_lobby_party()
	{
		const auto* party = lobby_party();
		return *reinterpret_cast<const int*>(party + 0x30C4) && // en la sala
			*reinterpret_cast<const int*>(party + 0x30BC) && // somos el anfitrión
			*reinterpret_cast<const int*>(party + 0x30C0) && // party activo
			!get_dvar_bool(0xC9DC4F0_b); // xblive_privatematch
	}

	bool is_game_start_requested()
	{
		return game_start_requested;
	}

	namespace
	{
		int party_max_players_stub(void* /*session*/)
		{
			return 18;
		}

		int ui_maxclients_get_stub(void* /*dvar*/)
		{
			return 18;
		}
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

			utils::hook::set<void*>(0x8F3B00_b + 8, is_bandwidth_sufficient_stub); // Matchmaking.IsBandwidthSufficient

			utils::hook::jump(0x6FA790_b, game_state_info_get_instance_stub); // GameStateInfo_GetInstance
			utils::hook::jump(0x6FA8B0_b, game_state_info_get_index_stub);
			utils::hook::jump(0x2C1110_b, bots_allowed_stub);

			// Clientes del servidor (svs_numclients) siempre 18 como en la partida privada: en la pública salían de
			// sv_maxclients, que la playlist deja en 12 y limitaba los bots de la partida a 6 vs 6
			utils::hook::nop(0x554D6C_b, 2);

			// sv_maxclients/ui_maxclients salían del máximo de la playlist (12) y la partida (level.maxclients) también
			// limitaba a 12: siempre 18, el número de bots lo marca party_maxplayers (bots + 1)
			utils::hook::call(0x356DEB_b, party_max_players_stub);  // al crear la sala
			utils::hook::call(0x13C9D4_b, ui_maxclients_get_stub);  // al cargar el mapa: sv_maxclients = ui_maxclients

			utils::hook::call(0x3533C8_b, utils::hook::assemble(steam_lobby_busy_stub));
			utils::hook::call(0x3533D5_b, utils::hook::assemble(steam_lobby_valid_stub));
			utils::hook::call(0x3533E2_b, utils::hook::assemble(steam_lobby_id_stub));

			utils::hook::call(0x352984_b, party_can_host_stub);

			// Dvar_GetInt(party_minplayers)
			for (const auto address : {0x1B1460_b, 0x28D280_b, 0x28D51A_b, 0x352839_b, 0x3529C2_b, 0x3544C4_b, 0x35454B_b})
			{
				utils::hook::call(address, party_minplayers_stub);
			}

			command::add("lobby_partygo", []
			{
				if (is_public_lobby())
				{
					game_start_requested = true;
					lobby_bots::prepare_match_bots();
					return;
				}

				console::warn("lobby_partygo: not in the public lobby\n");
			});

			command::add("lobby_cancelstartserver", []
			{
				if (!game_start_requested)
				{
					return;
				}

				game_start_requested = false;
				if (is_public_lobby())
				{
					stop_countdown();
				}
			});

			// Fuera de la sala pública (se ha salido, o ha empezado la partida) el botón se olvida
			scheduler::loop([]
			{
				if (game_start_requested && !is_public_lobby())
				{
					game_start_requested = false;
				}

				if (!is_public_lobby())
				{
					return;
				}

				// Sin entreacto, como "Intermedio: desactivado" en la partida privada: Lobby.UseIntermissionTimer
				// (0x14028C420) solo funciona en partida privada y pone +0x1C de las reglas de partida a 0
				auto* rules = utils::hook::invoke<std::uint8_t*>(0x6FA920_b, 0, 0);
				if (rules)
				{
					*reinterpret_cast<int*>(rules + 0x1C) = 0;
				}

				// Al volver de una partida la sala empieza el entreacto y al acabar lanza la partida: sin pulsar
				// Iniciar partida, cualquier cuenta atrás vuelve a "esperando jugadores", como
				// Lobby.StopIntermissionTimer (0x14028C4E0, también solo en partida privada)
				const auto state = *reinterpret_cast<int*>(lobby_party() + 0x30EC) & 0x7C;
				if (!game_start_requested && state != 0 && state != 4)
				{
					stop_countdown();
				}
			}, scheduler::pipeline::main, 500ms);
			utils::hook::call(0x3529A9_b, party_created_by_matchmaking_stub);
			utils::hook::call(0x352A33_b, party_should_advertise_stub);
		}
	};
}

REGISTER_COMPONENT(public_lobby::component)
