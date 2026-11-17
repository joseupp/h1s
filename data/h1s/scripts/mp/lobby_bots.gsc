// Bots de la sala pública (lobby_bots.cpp): al acabar la partida se manda la puntuación y las muertes de cada bot para
// que la lista de la sala muestre las mismas que el marcador.

init()
{
	if ( getdvarint( "virtualLobbyActive" ) == 1 )
		return;

	// Sala pública: el relleno de bots del juego (bot_connect_monitor) usaba max(party_maxplayers,
	// party_maxPrivatePartyPlayers = 18) y llenaba la partida hasta 18 ignorando los bots de la sala
	replacefunc( maps\mp\bots\_bots_util::bot_get_client_limit, ::bot_get_client_limit_stub );

	// Sala pública: el juego ignora el cambio de equipo del menú de partida en las partidas de matchmaking
	// (watchforteamchange descarta "team_select" si matchmakinggame() y no force_ranking)
	if ( getdvarint( "xblive_privatematch" ) == 0 )
		replacefunc( maps\mp\gametypes\_menus::watchforteamchange, ::watchforteamchange_stub );

	level thread send_stats_on_end();
	level thread keep_max_players();
}

// Partida lanzada desde la sala pública: el máximo de bots sale de party_maxplayers (bot_get_client_limit), que la
// playlist deja en 12 (6 vs 6). Se mantiene el de la sala (bots + 1).
keep_max_players()
{
	level endon( "game_ended" );

	if ( getdvarint( "xblive_privatematch" ) != 0 )
		return;

	max_players = getdvarint( "lobby_maxplayers", 0 );
	if ( max_players <= 0 )
		return;

	for ( ;; )
	{
		if ( getdvarint( "party_maxplayers" ) != max_players )
			setdvar( "party_maxplayers", max_players );

		wait 0.05;
	}
}

bot_get_client_limit_stub()
{
	limit = getdvarint( "party_maxplayers", 0 );
	lobby_max = getdvarint( "lobby_maxplayers", 0 );

	if ( getdvarint( "xblive_privatematch" ) == 0 && lobby_max > 0 )
		limit = lobby_max;
	else
		limit = max( limit, getdvarint( "party_maxPrivatePartyPlayers", 0 ) );

	if ( limit > level.maxclients )
		return level.maxclients;

	return int( limit );
}

// watchforteamchange original (gametypes\_menus.gsc) sin la comprobación de matchmaking
watchforteamchange_stub()
{
	self endon( "disconnect" );
	level endon( "game_ended" );

	for ( ;; )
	{
		self waittill( "luinotifyserver", var_0, var_1 );

		if ( var_0 != "team_select" )
			continue;

		if ( var_1 != 3 && !maps\mp\gametypes\_menus::teamchangeisfactionchange() && maps\mp\_utility::allowclasschoice() )
			self thread maps\mp\gametypes\_menus::showloadoutmenu();

		if ( var_1 == 3 )
		{
			self setclientomnvar( "ui_options_menu", 0 );
			self setclientomnvar( "ui_spectator_selected", 1 );
			self setclientomnvar( "ui_loadout_selected", -1 );
			self.spectating_actively = 1;

			if ( maps\mp\gametypes\_menus::teamchangeisfactionchange() && isdefined( self.addtoteam ) )
				self.addtoteam = undefined;
		}
		else
		{
			self setclientomnvar( "ui_spectator_selected", -1 );
			self.spectating_actively = 0;

			if ( maps\mp\gametypes\_menus::teamchangeisfactionchange() || !maps\mp\_utility::allowclasschoice() )
				self thread maps\mp\gametypes\_playerlogic::setuioptionsmenu( -1 );
		}

		if ( var_1 == 0 )
			var_1 = "axis";
		else if ( var_1 == 1 )
			var_1 = "allies";
		else if ( var_1 == 2 )
			var_1 = "random";
		else
			var_1 = "spectator";

		if ( isdefined( self.pers["team"] ) && var_1 == self.pers["team"] )
		{
			if ( maps\mp\gametypes\_menus::teamchangeisfactionchange() && isdefined( self.addtoteam ) )
				self.addtoteam = undefined;

			self notify( "selected_same_team" );
			continue;
		}

		if ( getdvarint( "scr_lua_splashes" ) )
			self luinotifyevent( &"clear_notification_queue", 0 );

		self setclientomnvar( "ui_loadout_selected", -1 );

		if ( var_1 == "axis" || var_1 == "allies" )
		{
			self thread maps\mp\gametypes\_menus::setteam( var_1 );
			continue;
		}

		if ( var_1 == "random" )
		{
			self thread [[ level.autoassign ]]();
			continue;
		}

		self thread maps\mp\gametypes\_menus::setspectator();
	}
}

send_stats_on_end()
{
	level waittill( "game_ended" );

	foreach ( player in level.players )
	{
		if ( !isbot( player ) )
			continue;

		score = 0;
		if ( isdefined( player.score ) )
			score = player.score;

		deaths = 0;
		if ( isdefined( player.deaths ) )
			deaths = player.deaths;

		lobbybotsetstats( player.name, score, deaths );
	}
}
