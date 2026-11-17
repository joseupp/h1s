-- Sala pública: la partida solo empieza con el botón "Iniciar partida" (lobby_partygo, public_lobby.cpp).
-- Se rehace menu_xboxlive_lobby (como combat_training/publicmenu.lua) para añadir el botón al crear el menú.
if game:issingleplayer() or not Engine.InFrontend() or not LUI.mp_menus then
    require("endgamemenu")
    return
end

-- Textos del menú con cadenas del propio juego (cambian con el idioma): el cliente es para jugar sin conexión, así que
-- "Jugar en línea" pasa a "Jugar" (botón del menú multijugador), el título de su menú a "Partida local" (también el
-- título pequeño de la sala) y "Buscar partida" a "Instrucción"
local localize_aliases = {
    ["@PLATFORM_PLAY_ONLINE"] = "@PLATFORM_PLAY_ONLINE_CAPS",
    ["@PLATFORM_UI_HEADER_PLAY_MP_CAPS"] = "@LUA_MENU_LOCAL_PLAY_CAPS",
    ["@PLATFORM_FIND_GAME"] = "@LUA_MENU_BOOTCAMP",
    -- Ventana de Demonware "Conectando con los servicios en línea" (commonpopups) → "Cargando..."
    ["@XBOXLIVE_POPUP_CONNECTION"] = "@MENU_LOADING_DOTS",
    ["@PLATFORM_POPUP_CONNECTION"] = "@MENU_LOADING_DOTS",
    ["@MENU_POPUP_CONNECTION"] = "@MENU_LOADING_DOTS",
    ["XBOXLIVE_POPUP_CONNECTION"] = "@MENU_LOADING_DOTS",
    ["PLATFORM_POPUP_CONNECTION"] = "@MENU_LOADING_DOTS",
    ["MENU_POPUP_CONNECTION"] = "@MENU_LOADING_DOTS"
}

-- Solo en la sala pública: el título pequeño de Configurar partida ("Partida privada") pasa a "Partida local"
local public_lobby_localize_aliases = {
    ["@LUA_MENU_PRIVATE_MATCH_CAPS"] = "@LUA_MENU_LOCAL_PLAY_CAPS"
}

local original_localize = Engine.Localize
Engine.Localize = function(text, ...)
    if select("#", ...) == 0 and type(text) == "string" then
        if localize_aliases[text] then
            return original_localize(localize_aliases[text])
        end

        if public_lobby_localize_aliases[text] and not Engine.GetDvarBool("xblive_privatematch") and
            not Engine.GetSystemLink() then
            return original_localize(public_lobby_localize_aliases[text])
        end
    end

    return original_localize(text, ...)
end

local MPLobbyPublic = LUI.mp_menus.MPLobbyPublic
local MPLobbyOnline = LUI.mp_menus.MPLobbyOnline

local function in_public_lobby()
    return not Engine.GetDvarBool("xblive_privatematch") and not Engine.GetSystemLink()
end

local function gametype_name(gametype)
    return Engine.Localize(Engine.TableLookup(GameTypesTable.File, GameTypesTable.Cols.Ref, gametype,
        GameTypesTable.Cols.Name) or "")
end

-- La sala pública admite 18 jugadores como la privada (party_maxPrivatePartyPlayers): en Configurar partida se pueden
-- poner hasta 17 bots. Por defecto se llena como una sala pública de 12.
local lobby_max_players = 18
local public_max_players = 12
local public_ffa_max_players = 8

local original_get_max_bot_limit = GetMaxBotLimit
GetMaxBotLimit = function(...)
    if not original_get_max_bot_limit or (in_public_lobby() and Engine.InLobby()) then
        return lobby_max_players - 1
    end

    return original_get_max_bot_limit(...)
end

-- Buscar partida entra directamente en la sala pública, sin elegir playlist (como el menú anterior): el modo, el
-- mapa y las opciones se eligen en Configurar partida
local reset_map_vote
local set_map_chosen

local function on_public_match(element, event)
    if Engine.GetOnlineGame() then
        -- Sala nueva: vuelve la votación de mapa hasta que se elija uno en Configurar partida
        set_map_chosen(false)
        reset_map_vote()
        Engine.Exec("xcheckezpatch")
        Engine.ExecNow("xblive_privatematch 0")
        LUI.FlowManager.RequestAddMenu(element, "menu_xboxlive_lobby", true, event.controller, false, {})
        Engine.Exec(MPConfig.default_xboxlive, event.controller)
        Engine.Exec("xstartlobby")
    end
end

if MPLobbyOnline then
    rawset(MPLobbyOnline, "OnPublicMatch", on_public_match)
end

-- En la sala pública el modo que se muestra es el de Configurar partida (ui_gametype), no el de la playlist
local original_gametype_name = Lobby.GameTypeNameAbbreviated
Lobby.GameTypeNameAbbreviated = function(...)
    if in_public_lobby() then
        return gametype_name(Engine.GetDvarString("ui_gametype"))
    end

    return original_gametype_name(...)
end

-- Iconos de bonificación (2x XP, 4x XP, XP de grupo, créditos) junto al título, como en combat_training/publicmenu.lua
LUI.MPLobbyPublic.bonusIconSize = 45

local function in_party()
    return Lobby.IsInPrivateParty() and not Lobby.IsAloneInPrivateParty()
end

local function add_bonus_icons(list, scales, party)
    local state = CoD.CreateState(0, 0, nil, nil, CoD.AnchorTypes.TopLeft)
    state.height = LUI.MPLobbyPublic.bonusIconSize
    state.width = LUI.MPLobbyPublic.bonusIconSize

    if scales.xpScale == 4 and GameX.IsRankedMatch() == true then
        state.material = RegisterMaterial("ui_reward_small_quad_xp")
        list:addElement(LUI.UIImage.new(state))
    elseif scales.xpScale == 2 then
        state.material = RegisterMaterial("ui_reward_small_double_xp")
        list:addElement(LUI.UIImage.new(state))
    elseif party and scales.xpPartyScale == 2 then
        state.material = RegisterMaterial("ui_reward_small_double_party_xp")
        list:addElement(LUI.UIImage.new(state))
    end

    if scales.depotCreditScale == 2 then
        state.material = RegisterMaterial("depot_currency_credit_2x")
        list:addElement(LUI.UIImage.new(state))
    end
end

local function update_bonus_icons(menu)
    local list = menu.bonusIconList
    local scales = menu.bonusScales
    local xp = Engine.GetDvarInt("scr_xpscale")
    local xp_party = Engine.GetDvarInt("scr_xpscalewithparty")
    local credits = Engine.GetDvarInt("scr_depotcreditscale")
    local party = in_party()

    if scales.xpScale ~= xp or scales.xpPartyScale ~= xp_party or scales.depotCreditScale ~= credits or
        list.inParty ~= party then
        scales.xpScale = xp
        scales.xpPartyScale = xp_party
        scales.depotCreditScale = credits
        list.inParty = party
        list:closeChildren()
        add_bonus_icons(list, scales, party)
    end
end

local function create_bonus_icons(menu, title_width)
    local state = CoD.CreateState(title_width + 25, 17, nil, nil, CoD.AnchorTypes.TopLeft)
    state.width = 120
    state.height = LUI.MPLobbyPublic.bonusIconSize

    local list = LUI.UIHorizontalList.new(state)
    menu:addElement(list)
    menu.bonusIconList = list
    list.inParty = in_party()
    add_bonus_icons(list, menu.bonusScales, list.inParty)

    menu:registerEventHandler("updatePartyBonusIcons", function(element, event)
        update_bonus_icons(menu)
    end)

    local timer = LUI.UITimer.new(1000, "updatePartyBonusIcons")
    timer.id = "MPLobbyPublic_party_bonus_icon_update_timer"
    menu.bonusIconUpdateTimer = timer
    menu:addElement(timer)
end

-- Votación de mapa como en la pública original (mapa A, mapa B y aleatorio), mientras no se elija un mapa en Configurar
-- partida (map_selection_new.lua pone lobby_map_chosen; vuelve a 0 al entrar en la sala). Los mapas rotan: los de
-- las últimas partidas (lobby_map_history) no salen. Los bots de la sala también votan. La votación se cierra al
-- pulsar Iniciar partida y el mapa ganador pasa a ui_mapname.
local vote_maps = {
    "mp_convoy", "mp_backlot", "mp_bloc", "mp_bog", "mp_bog_summer", "mp_broadcast", "mp_carentan", "mp_countdown",
    "mp_crash", "mp_crash_snow", "mp_creek", "mp_crossfire", "mp_citystreets", "mp_farm", "mp_farm_spring",
    "mp_killhouse", "mp_overgrown", "mp_pipeline", "mp_shipment", "mp_showdown", "mp_strike", "mp_vacant",
    "mp_cargoship"
}
local vote_history_size = 4

local vote = nil
local vote_random_seeded = false

local function get_dvar_string(name)
    local ok, value = pcall(Engine.GetDvarString, name)
    if ok and value then
        return value
    end

    return ""
end

-- Mapa elegido: en Lua y en lobby_map_chosen (por si se recargan los scripts al volver de la partida)
local map_chosen = nil

set_map_chosen = function(chosen)
    map_chosen = chosen
    Engine.ExecNow("set lobby_map_chosen " .. (chosen and "1" or "0"))
end

local function is_map_chosen()
    if map_chosen ~= nil then
        return map_chosen
    end

    local ok, value = pcall(Engine.GetDvarInt, "lobby_map_chosen")
    return ok and value == 1
end

-- Mapa elegido en Configurar partida: cualquier menú de mapas pone ui_mapname (también si se elige el mismo que ya
-- había, por eso no basta con mirar si cambia). La votación lo pone con setting_vote_map.
local setting_vote_map = false
local original_set_dvar_string = Engine.SetDvarString
Engine.SetDvarString = function(name, value, ...)
    if name == "ui_mapname" and not setting_vote_map and vote and in_public_lobby() then
        set_map_chosen(true)
    end

    return original_set_dvar_string(name, value, ...)
end

-- Por si algún menú cambia ui_mapname sin Engine.SetDvarString: distinto del último que conoce la votación
local function check_map_chosen()
    if not vote or is_map_chosen() then
        return
    end

    local map = get_dvar_string("ui_mapname")
    if vote.known_map == nil then
        vote.known_map = map
    elseif map ~= "" and map ~= vote.known_map then
        set_map_chosen(true)
    end
end

local function get_map_history()
    local history = {}
    for map in string.gmatch(get_dvar_string("lobby_map_history"), "[^,]+") do
        history[#history + 1] = map
    end

    return history
end

local function add_map_history(map)
    local history = get_map_history()
    table.insert(history, 1, map)
    while #history > vote_history_size do
        table.remove(history)
    end

    Engine.ExecNow("set lobby_map_history " .. table.concat(history, ","))
end

local function has_map(map)
    if game and game.zoneexists then
        local ok, exists = pcall(game.zoneexists, game, map)
        if ok and exists == false then
            return false
        end
    end

    if Engine.ControllerHasMap then
        local ok, owned = pcall(Engine.ControllerHasMap, Engine.GetFirstActiveController(), map)
        if ok and owned == false then
            return false
        end
    end

    return true
end

-- Mapas que pueden salir: los que no se han jugado hace poco (si no quedan bastantes, todos)
local function get_vote_pool(exclude)
    local recent = {}
    for _, map in ipairs(get_map_history()) do
        recent[map] = true
    end

    local pool = {}
    local all = {}
    for _, map in ipairs(vote_maps) do
        if has_map(map) and map ~= exclude then
            all[#all + 1] = map
            if not recent[map] then
                pool[#pool + 1] = map
            end
        end
    end

    if #pool < 2 then
        return all
    end

    return pool
end

local function get_vote_map_data(map)
    return {
        name = Engine.Localize("@MPUI_" .. string.upper(string.sub(map, 4))),
        image = "loadscreen_" .. map .. "_vote",
        gameMode = Lobby.GameTypeNameAbbreviated()
    }
end

reset_map_vote = function()
    vote = nil
end

local function ensure_map_vote()
    if vote then
        return vote
    end

    if not vote_random_seeded and Engine.GetMilliseconds then
        vote_random_seeded = true
        math.randomseed(Engine.GetMilliseconds())
    end

    local pool = get_vote_pool()
    if #pool == 0 then
        pool = { "mp_crossfire" }
    end

    local first = table.remove(pool, math.random(#pool))
    local second = #pool > 0 and pool[math.random(#pool)] or first

    vote = {
        maps = { first, second },
        player_vote = nil,
        bot_votes = {},
        next_bot_tick = math.random(2, 6),
        tick = 0,
        passed = false,
        winner = nil
    }
    return vote
end

local function get_vote_count(index)
    local count = 0
    if vote then
        if vote.player_vote == index then
            count = count + 1
        end

        for _, choice in ipairs(vote.bot_votes) do
            if choice == index then
                count = count + 1
            end
        end
    end

    return count
end

local function get_lobby_bot_count()
    local ok, count = pcall(Lobby.GetCurrentMemberCount, Lobby.MemberListStates.Lobby)
    if ok and count then
        return math.max(count - 1, 0)
    end

    return 0
end

-- Los bots votan poco a poco (cada 1-4 s), más a los mapas que a aleatorio; si se van bots, se quitan sus votos
local function update_bot_votes()
    if not vote or vote.passed then
        return
    end

    local bots = get_lobby_bot_count()
    while #vote.bot_votes > bots do
        table.remove(vote.bot_votes)
    end

    vote.tick = vote.tick + 1
    if #vote.bot_votes < bots and vote.tick >= vote.next_bot_tick then
        local roll = math.random(100)
        local choice = roll <= 42 and 1 or roll <= 84 and 2 or 3
        vote.bot_votes[#vote.bot_votes + 1] = choice
        vote.next_bot_tick = vote.tick + math.random(2, 8)
    end
end

-- Cierra la votación: gana el más votado (empate al azar); aleatorio elige un mapa al azar
local function resolve_map_vote()
    if is_map_chosen() or not vote or vote.passed then
        return
    end

    local best = -1
    local winners = {}
    for index = 1, 3 do
        local count = get_vote_count(index)
        if count > best then
            best = count
            winners = { index }
        elseif count == best then
            winners[#winners + 1] = index
        end
    end

    local winner = winners[math.random(#winners)]
    local map
    if winner == 3 then
        local pool = get_vote_pool()
        map = #pool > 0 and pool[math.random(#pool)] or vote.maps[1]
    else
        map = vote.maps[winner]
    end

    vote.passed = true
    vote.winner = map
    vote.known_map = map
    add_map_history(map)
    setting_vote_map = true
    Engine.SetDvarString("ui_mapname", map)
    setting_vote_map = false
    Engine.ExecNow("xupdatepartystate")
end

local vote_overrides_installed = false

local function install_vote_overrides()
    if vote_overrides_installed or not LUI.MPLobbyMapVote then
        return
    end

    vote_overrides_installed = true

    local original_map_provider = LUI.MPLobbyMapVote.MapVoteDataProvider
    LUI.MPLobbyMapVote.MapVoteDataProvider = function(info, ...)
        if not in_public_lobby() or not vote then
            return original_map_provider(info, ...)
        end

        local index = info.voteIndex
        local data = get_vote_map_data(vote.passed and vote.winner or vote.maps[index])
        data.votes = get_vote_count(index)
        return data
    end

    local original_random_provider = LUI.MPLobbyMapVote.RandomMapDataProvider
    LUI.MPLobbyMapVote.RandomMapDataProvider = function(info, ...)
        if not in_public_lobby() or not vote then
            return original_random_provider(info, ...)
        end

        -- Votación cerrada: si no coincide con A o B, el panel enseña este botón; con el mapa elegido
        if vote.passed then
            local data = get_vote_map_data(vote.winner)
            data.votes = get_vote_count(info.voteIndex)
            return data
        end

        local data = original_random_provider(info, ...)
        data.votes = get_vote_count(info.voteIndex)
        return data
    end

    local original_vote_for_map = LUI.MPLobbyMapVote.VoteForMap
    LUI.MPLobbyMapVote.VoteForMap = function(button, event, ...)
        if not in_public_lobby() or not vote then
            return original_vote_for_map(button, event, ...)
        end

        if not vote.passed then
            vote.player_vote = button.index
            Engine.PlaySound(CoD.SFX.MouseClick)
        end

        button.mapWidget:Refresh()
    end

    -- En la pública la votación acaba al pulsar Iniciar partida (el original también la daba por acabada con los
    -- equipos visibles)
    local original_voting_finished = IsVotingFinished
    IsVotingFinished = function(...)
        if in_public_lobby() and vote then
            return vote.passed
        end

        return original_voting_finished(...)
    end
end

-- Panel del mapa elegido (como en la partida privada)
local function add_map_widget(menu, constructor)
    local display = constructor()
    display.parentList = menu.list
    menu.list:addElement(display)
    display:Refresh()
    menu.mapDisplay = display
end

local function add_chosen_map_display(menu)
    add_map_widget(menu, LUI.MPLobbyMap.new)
end

-- Panel del mapa un hueco de botón más arriba que en la pública original (la sala tiene dos botones más: Iniciar
-- partida y Configurar partida). AddMapDisplay pone 17 de separación
local function add_map_display(menu, constructor)
    local shift = GenericButtonSettings.Styles.FlatButton.height + (H1MenuDims and H1MenuDims.spacing or 0)
    menu:AddSpacing(17 - shift)
    add_map_widget(menu, constructor)
end

-- Se cancela el inicio de la partida sin mapa elegido: votación nueva con otros mapas (el ganador no se ha jugado,
-- sale de las últimas partidas)
local function restart_map_vote(menu)
    if not menu.map_display_is_vote or is_map_chosen() or not menu.mapDisplay then
        return
    end

    if vote and vote.passed and vote.winner then
        local history = get_map_history()
        if history[1] == vote.winner then
            table.remove(history, 1)
            Engine.ExecNow("set lobby_map_history " .. table.concat(history, ","))
        end
    end

    reset_map_vote()
    ensure_map_vote()
    menu.mapDisplay:close()
    add_map_widget(menu, LUI.MPLobbyMapVote.new)
end

-- Con la votación en pantalla se elige un mapa en Configurar partida: se cambia al panel del mapa elegido
local function update_map_display(menu)
    if menu.map_display_is_vote and is_map_chosen() and menu.mapDisplay then
        menu.map_display_is_vote = false
        menu.mapDisplay:close()
        add_chosen_map_display(menu)
    end
end

-- Panel del mapa: votación o, con un mapa elegido, el de la partida privada, con el modo en el título en vez de la
-- playlist y los iconos de bonificación
LUI.MPLobbyPublic.CheckAddMapAndMarketingPanels = function(menu, open_summary)
    if menu.addedDeferredContent then
        return true
    end

    if Lobby.GetPartyStatus() == "" then
        return false
    end

    install_vote_overrides()
    if is_map_chosen() or not LUI.MPLobbyMapVote then
        add_map_display(menu, LUI.MPLobbyMap.new)
    else
        -- Votación ya cerrada (se vuelve de una partida): mapas nuevos
        if vote and vote.passed then
            reset_map_vote()
        end

        ensure_map_vote()
        add_map_display(menu, LUI.MPLobbyMapVote.new)
        menu.map_display_is_vote = true
    end

    local title = Engine.ToUpperCase(gametype_name(Engine.GetDvarString("ui_gametype")))
    menu:dispatchEventToChildren({
        name = "update_header_text",
        string = title,
        dispatchChildren = true
    })
    if menu.wholeTitle ~= nil and menu.wholeTitle.dotElement ~= nil then
        menu.wholeTitle.dotElement:close()
        LUI.MenuTemplate.AddDotElement(menu.wholeTitle, title, 0, 0)
    end

    local left, top, right, bottom = LUI.MenuTemplate.GetTitleDimensions(title)
    create_bonus_icons(menu, right)

    if menu.mapTimer ~= nil then
        LUI.UITimer.Stop(menu.mapTimer)
        menu:removeElement(menu.mapTimer)
        menu.mapTimer = nil
    end

    menu.addedDeferredContent = true
    return true
end

-- La sala pública usa las reglas de la partida privada (public_lobby.cpp): se activan y el modo elegido en
-- Configurar partida (MatchRules gametype) pasa a ui_gametype, que es el que usan la sala y el inicio de la partida
local function apply_match_rules()
    if not MatchRules.IsUsingMatchRulesData() then
        MatchRules.SetUsingMatchRulesData(1)
    end

    local gametype = MatchRules.GetData("gametype")
    if gametype and gametype ~= "" and Engine.GetDvarString("ui_gametype") ~= gametype then
        Engine.SetDvarString("ui_gametype", gametype)
        Engine.ExecNow("xupdatepartystate")
    end
end

local set_default_bots
local update_ffa_bots

local function refresh_lobby(menu)
    apply_match_rules()

    if menu.addedDeferredContent then
        check_map_chosen()
        update_map_display(menu)
        if menu.map_display_is_vote then
            update_bot_votes()
        end
    end

    -- Huecos de la sala: los jugadores que hay (tú y los bots de Configurar partida), sin huecos libres "Buscando..."
    local bots
    local team_based = BotIsTeamBased(Engine.GetDvarString("ui_gametype"))
    if team_based and team_based == 1 then
        bots = Lobby.GetBotsTeamLimit(Lobby.BotTeams.Friendly) + Lobby.GetBotsTeamLimit(Lobby.BotTeams.Enemy)
    else
        bots = Lobby.GetBotsTeamLimit(Lobby.BotTeams.FFA)
    end

    -- Los bots de la sala (lobby_bots.cpp) necesitan saber si el modo es por equipos y cuántos bots hay: en los modos
    -- sin equipos el C++ no lee bien los bots de todos contra todos
    local is_team_based = team_based and team_based == 1
    local friendly_bots = is_team_based and Lobby.GetBotsTeamLimit(Lobby.BotTeams.Friendly) or 0
    local enemy_bots = is_team_based and Lobby.GetBotsTeamLimit(Lobby.BotTeams.Enemy) or bots
    local bots_setup = (is_team_based and "1" or "0") .. " " .. friendly_bots .. " " .. enemy_bots
    if menu.sent_bots_setup ~= bots_setup then
        menu.sent_bots_setup = bots_setup
        Engine.Exec("lobbybots_teambased " .. bots_setup)
    end

    local max_players = math.min(math.max(bots + 1, 2), lobby_max_players)
    if Engine.GetDvarInt("party_maxplayers") ~= max_players then
        Engine.SetDvarInt("party_maxplayers", max_players)
    end

    -- Los bots solo se pueden configurar siendo ya el anfitrión de la sala, que no lo somos al crear el menú.
    -- Al pasar de un modo con equipos a uno sin ellos (o al revés) se ponen los bots por defecto de ese tipo de modo
    if Lobby.IsGameHost() then
        if not menu.default_bots_done then
            menu.default_bots_done = true
            menu.default_bots_team_based = is_team_based
            set_default_bots()
        elseif menu.default_bots_team_based ~= is_team_based then
            menu.default_bots_team_based = is_team_based
            set_default_bots(true)
        end

        update_ffa_bots(menu, is_team_based)
    end

    -- Título de la sala y panel del mapa con el modo y el mapa elegidos
    local gametype = Engine.GetDvarString("ui_gametype")
    if menu.shown_gametype ~= gametype or menu.shown_map ~= Engine.GetDvarString("ui_mapname") then
        menu.shown_gametype = gametype
        menu.shown_map = Engine.GetDvarString("ui_mapname")
        menu:dispatchEventToChildren({
            name = "update_header_text",
            string = Engine.ToUpperCase(gametype_name(gametype)),
            dispatchChildren = true
        })
    end
end

local start_requested = false

-- Bots de los modos sin equipos: el juego no los guarda bien (al volver a la sala salían los de los modos con equipos),
-- así que se guardan en lobby_ffa_bots (bots + 1; 0 = sin elegir) y se ponen al entrar en la sala o en un modo sin
-- equipos. Por defecto, 7 (8 jugadores)
local saved_ffa_bots = nil

local function save_ffa_bots(bots)
    saved_ffa_bots = bots
    Engine.Exec("set lobby_ffa_bots " .. (bots + 1))
end

local function get_saved_ffa_bots()
    if saved_ffa_bots then
        return saved_ffa_bots
    end

    local ok, value = pcall(Engine.GetDvarInt, "lobby_ffa_bots")
    if ok and value and value > 0 then
        return value - 1
    end

    return public_ffa_max_players - 1
end

update_ffa_bots = function(menu, is_team_based)
    if is_team_based then
        menu.ffa_bots_checked = false
        return
    end

    local ffa = Lobby.GetBotsTeamLimit(Lobby.BotTeams.FFA)
    if not menu.ffa_bots_checked then
        menu.ffa_bots_checked = true
        menu.ffa_bots_seen = get_saved_ffa_bots()
        if ffa ~= menu.ffa_bots_seen then
            Lobby.SetBotsTeamLimit(Lobby.BotTeams.FFA, menu.ffa_bots_seen)
        end
    elseif ffa ~= menu.ffa_bots_seen then
        -- Cambiados en Configurar partida
        menu.ffa_bots_seen = ffa
        save_ffa_bots(ffa)
    end
end

-- Configurar partida cambia los bots con el menú de la sala debajo (sin refrescarlo): se guardan al cambiarlos
local original_set_bots_team_limit = Lobby.SetBotsTeamLimit
Lobby.SetBotsTeamLimit = function(team, bots, ...)
    -- En Configurar partida Engine.InLobby() no vale: basta con estar en la pública
    if team == Lobby.BotTeams.FFA and in_public_lobby() then
        save_ffa_bots(bots)
    end

    return original_set_bots_team_limit(team, bots, ...)
end


-- Bots por defecto: si al entrar en la sala no hay bots configurados (al salir de la sala el juego los pone a 0) se
-- llena la sala con dificultad variada; lo que se cambie en Configurar partida se mantiene entre partidas
set_default_bots = function(force)
    -- Por defecto como una sala pública de 12 jugadores: 11 bots (5 con el host y 6 en el otro equipo); sin equipos,
    -- de 8 jugadores: 7 bots. Si no hay bots, o hay más de los que caben en la sala, se ponen los de por defecto
    local friendly = Lobby.GetBotsTeamLimit(Lobby.BotTeams.Friendly)
    local enemy = Lobby.GetBotsTeamLimit(Lobby.BotTeams.Enemy)
    local ffa = Lobby.GetBotsTeamLimit(Lobby.BotTeams.FFA)
    local none = friendly == 0 and enemy == 0 and ffa == 0
    if not force and not none and friendly + enemy < lobby_max_players and ffa < lobby_max_players then
        return
    end

    local total = public_max_players - 1

    -- Todos contra todos (FFA) pone el mismo número en aliados y enemigos (Lobby.SetBotsTeamLimit, 0x14028CBF9):
    -- solo se usa en los modos sin equipos
    local team_based = BotIsTeamBased(Engine.GetDvarString("ui_gametype"))
    if team_based and team_based == 1 then
        local half = math.floor(total / 2)
        Lobby.SetBotsTeamLimit(Lobby.BotTeams.Friendly, half)
        Lobby.SetBotsTeamLimit(Lobby.BotTeams.Enemy, total - half)
    else
        Lobby.SetBotsTeamLimit(Lobby.BotTeams.FFA, get_saved_ffa_bots())
    end
    Lobby.SetBotsDifficulty(Lobby.BotTeams.Friendly, Lobby.BotDifficulties.Mixed)
    Lobby.SetBotsDifficulty(Lobby.BotTeams.Enemy, Lobby.BotDifficulties.Mixed)
    Lobby.SetBotsDifficulty(Lobby.BotTeams.FFA, Lobby.BotDifficulties.Mixed)
end

-- Sin el tiempo de entreacto al volver de una partida (como Intermedio desactivado en la partida privada)
local function disable_intermission()
    if Lobby.UseIntermissionTimer then
        Lobby.UseIntermissionTimer(false)
    end

    if Lobby.StopIntermissionTimer then
        Lobby.StopIntermissionTimer()
    end
end

-- Como OnStartGame de la partida privada: con bots configurados se conectan al empezar (bot_SystemStatus 2)
local function start_game()
    resolve_map_vote()

    if Lobby.GetBotsTeamLimit(Lobby.BotTeams.Friendly) > 0 or Lobby.GetBotsTeamLimit(Lobby.BotTeams.Enemy) > 0 or
        Lobby.GetBotsTeamLimit(Lobby.BotTeams.FFA) > 0 then
        Lobby.SetBotsConnectType(2)
    else
        Lobby.SetBotsConnectType(0)
    end

    -- Jugadores de la partida como en la privada (18): la partida pública usa los de la playlist (12) y el juego
    -- reparte los bots hasta la mitad por equipo (bot_get_team_limit, maps/mp/bots/_bots_util.gsc)
    Engine.SetDvarInt("sv_maxclients", lobby_max_players)

    -- Al cargar la partida la playlist vuelve a poner party_maxplayers (12): lobby_bots.gsc lo restaura con este valor
    Engine.Exec("set lobby_maxplayers " .. Engine.GetDvarInt("party_maxplayers"))

    -- Cuenta atrás como en la partida privada e iw7s: 8 s en total, de los que se ven 5
    Engine.SetDvarInt("pt_pregameStartTimerLength", 3)
    Engine.SetDvarInt("pt_gameStartTimerLength", 5)

    apply_match_rules()
    Engine.Exec("lobby_partygo")
    start_requested = true
end

-- Mensaje de estado de la sala: hasta pulsar Iniciar partida, el de la partida privada ("Listo para jugar") en vez de
-- "Esperando a 1 jugador más" (la sala espera a un jugador más para no empezar sola, public_lobby.cpp)
local original_party_status = Lobby.GetPartyStatus
Lobby.GetPartyStatus = function(...)
    local status = original_party_status(...)
    if status ~= "" and not start_requested and in_public_lobby() and Engine.InLobby() and Lobby.IsGameHost() then
        return Engine.Localize("@MENU_READY_TO_START_GAME")
    end

    return status
end

-- Atrás: con la cuenta atrás pedida (Iniciar partida) se detiene; si no, sale el aviso de abandonar la sala y se vuelve al menú multijugador
-- sin pasar por la lista de playlists
local function handle_back(menu, element, event)
    if start_requested then
        start_requested = false
        Engine.Exec("lobby_cancelstartserver")
        restart_map_vote(menu)
        return
    end

    -- HandleBack se llama como método con (elemento, evento): el mando sale del evento o del primero activo
    local controller = (event and event.controller) or (element and element.controller) or
        Engine.GetFirstActiveController()
    -- Aviso de abandonar la sala del juego: al aceptar sale de la sala (exit_public_lobby) al menú multijugador
    PromptToLeaveLobby(menu, { controller = controller }, function()
        LUI.FlowManager.RequestLeaveMenuByName("menu_xboxlive_lobby")
    end)
end

-- Al volver de una partida la pila de menús es la del menú multijugador, sin la lista de playlists
LUI.FlowManager.RegisterMenuStack("menu_xboxlive_lobby", function()
    return {
        "mp_main_menu",
        "menu_xboxlive"
    }
end)

-- Configurar partida: el mismo menú que en la partida privada (mapa, modo, opciones y bots)
local function game_setup(element, event)
    LUI.FlowManager.RequestAddMenu(element, "gamesetup_menu_main", true, event.controller, false)
end

local function menu_xboxlive_lobby(controller, args)
    args = args or {}

    local open_summary = Engine.GetDvarBool("ui_opensummary") == true
    local menu = LUI.MPLobbyBase.new(controller, {
        menu_title = " ",
        has_match_summary = true
    }, true)

    menu:setClass(LUI.MPLobbyPublic)
    menu:SetBreadCrumb(Engine.ToUpperCase(Engine.Localize("@PLATFORM_UI_HEADER_PLAY_MP_CAPS")))

    menu.bonusScales = {}
    if args.category and args.index then
        menu.bonusScales.xpScale = Playlist.GetPlaylistXpScale(args.category, args.index)
        menu.bonusScales.xpPartyScale = Playlist.GetPlaylistXpScaleWithParty(args.category, args.index)
        menu.bonusScales.depotCreditScale = Playlist.GetPlaylistDepotCreditScale(args.category, args.index)
    else
        menu.bonusScales.xpScale = Engine.GetDvarInt("scr_xpscale")
        menu.bonusScales.xpPartyScale = Engine.GetDvarInt("scr_xpscalewithparty")
        menu.bonusScales.depotCreditScale = Engine.GetDvarInt("scr_depotcreditscale")
    end

    if Engine.IsCoreMode() then
        menu:AddButton("@LUA_MENU_START_GAME", start_game, false)
        menu:AddButton("@LUA_MENU_GAME_SETUP", game_setup, false)
        menu:AddCACButton()
        menu:AddBarracksButton()
        menu:AddPersonalizationButton()
        menu:AddDepotButton()
    end

    menu:AddOptionsButton()
    menu:AddMenuDescription(0)

    if not menu:CheckAddMapAndMarketingPanels(open_summary) then
        menu:registerEventHandler("CheckAddMapAndMarketingPanels", function(element, event)
            LUI.MPLobbyPublic.CheckAddMapAndMarketingPanels(element, open_summary)
        end)

        local timer = LUI.UITimer.new(100, "CheckAddMapAndMarketingPanels")
        timer.id = "MPLobbyPublic_add_map_timer"
        menu.mapTimer = timer
        menu:addElement(timer)
    end

    if MPLobbyPublic and MPLobbyPublic.OnLeaveLobby then
        menu:registerEventHandler("exit_public_lobby", MPLobbyPublic.OnLeaveLobby)
    end

    start_requested = false
    menu.HandleBack = handle_back
    disable_intermission()

    refresh_lobby(menu)
    menu:registerEventHandler("apply_match_rules", refresh_lobby)
    local rules_timer = LUI.UITimer.new(500, "apply_match_rules")
    rules_timer.id = "public_lobby_rules_timer"
    menu:addElement(rules_timer)

    menu:registerEventHandler("player_joined", Cac.PlayerJoinedEvent)
    menu:registerEventHandler("loadout_request", Cac.PlayerJoinedEvent)
    Lobby.EnteredLobby()
    menu:AddCurrencyInfoPanel()
    return menu
end

LUI.MenuBuilder.m_types_build["menu_xboxlive_lobby"] = menu_xboxlive_lobby
