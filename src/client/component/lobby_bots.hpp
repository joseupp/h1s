#pragma once

namespace lobby_bots
{
	// Nombre del siguiente bot de la sala para un bot de la partida (bots.cpp)
	std::optional<std::string> take_match_bot_name();

	// Al iniciar la partida (lobby_partygo): los bots de la partida toman los nombres de los bots de la sala
	void prepare_match_bots();
}
