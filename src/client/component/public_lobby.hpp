#pragma once

namespace public_lobby
{
	// Estamos en la sala pública como anfitrión (menú, sin partida privada ni red local)
	bool is_public_lobby();

	// El party de la sala pública sigue abierto con nosotros como anfitrión (también mientras se juega la partida)
	bool is_public_lobby_party();

	// Se ha pulsado "Iniciar partida" en la sala pública
	bool is_game_start_requested();
}
