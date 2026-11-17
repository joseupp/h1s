local function f0_local0 ( f1_arg0, f1_arg1, f1_arg2, f1_arg3 )
	local f1_local0 = Game.GetOmnvar( "ui_player_xp_rank" )
	if f1_local0 ~= nil then
		LUI.ExperienceProgressBar.UpdatePlayerRank( f1_arg2, {
			value = f1_local0
		} )
	end
	local f1_local1 = Game.GetOmnvar( "ui_player_xp_pct" )
	if f1_local1 ~= nil then
		LUI.ExperienceProgressBar.UpdatePlayerXP( f1_arg3, {
			value = f1_local1,
			initialUpdate = true
		} )
	end
end

local GetPrestigeLevel = function()

    local controller = Engine.GetFirstActiveController()

    local prestigeLevel = Lobby.GetPlayerPrestigeLevel( controller )

    if not prestigeLevel then
        prestigeLevel = AAR.GetPrestigeLevel( controller )
    end

    return prestigeLevel or 0

end

local BarColor = function()

    local prestigeLevel = GetPrestigeLevel()

    if prestigeLevel == 1 then
        return { r = 1, g = 1, b = 0 }       -- Amarillo
    elseif prestigeLevel == 2 then
        return { r = 1, g = 0.5, b = 0 }     -- Naranja
    elseif prestigeLevel == 3 then
        return { r = 1, g = 0, b = 0 }       -- Rojo
    elseif prestigeLevel == 4 then
        return { r = 1, g = 0, b = 1 }       -- Magenta
    elseif prestigeLevel == 5 then
        return { r = 0.6, g = 0, b = 1 }     -- Violeta
    elseif prestigeLevel == 6 then
        return { r = 0, g = 0, b = 1 }       -- Azul
    elseif prestigeLevel == 7 then
        return { r = 0, g = 0.5, b = 1 }     -- Azul claro
    elseif prestigeLevel == 8 then
        return { r = 0, g = 1, b = 1 }       -- Cian
    elseif prestigeLevel == 9 then
        return { r = 0, g = 1, b = 0.5 }     -- Turquesa
    elseif prestigeLevel == 10 then
        return { r = 0, g = 1, b = 0 }       -- Verde
    elseif prestigeLevel == 11 then
        return { r = 0.5, g = 1, b = 0 }     -- Verde lima
    elseif prestigeLevel == 12 then
        return { r = 1, g = 1, b = 0.5 }     -- Amarillo claro
    elseif prestigeLevel == 13 then
        return { r = 1, g = 0.75, b = 0.3 }   -- Dorado
    elseif prestigeLevel == 14 then
        return { r = 1, g = 0.5, b = 0.25 } -- Naranja claro
    elseif prestigeLevel == 15 then
        return { r = 1, g = 0.25, b = 0.25 } -- Rojo claro
    elseif prestigeLevel == 16 then
        return { r = 1, g = 0.25, b = 0.75 } -- Rosa
    elseif prestigeLevel == 17 then
        return { r = 0.75, g = 0.25, b = 1 } -- Violeta claro
    elseif prestigeLevel == 18 then
        return { r = 0.25, g = 0.5, b = 1 } -- Azul cielo
    elseif prestigeLevel == 19 then
        return { r = 0.25, g = 1, b = 0.75 } -- Verde agua
    elseif prestigeLevel == 20 then
        return { r = 1, g = 0.84, b = 0 }   -- Dorado
    else
        return { r = 1, g = 1, b = 1 }       -- Sin prestigio
    end
end

local BarMaterial = function()

    local prestigeLevel = GetPrestigeLevel()

    if prestigeLevel >= 1 then
        return RegisterMaterial( "white" ) --h1_ui_progressbar_green
    end

    return RegisterMaterial( "h1_ui_experiencebar_fill" )

end

local BarAlpha = function()

    local prestigeLevel = GetPrestigeLevel()

    if prestigeLevel == 0 then
        return 0.4
    else
        return 0.4
    end

end

local BarFillState = function()

    local prestigeLevel = GetPrestigeLevel()

    if prestigeLevel == 0 then
        return CoD.CreateState( -20, -6, 20, 6, CoD.AnchorTypes.All )
    else
        return CoD.CreateState( -20, 3, 20, -3, CoD.AnchorTypes.All )
    end

end

LUI.MenuBuilder.m_types_build["experienceBar"] = function()
    local state = CoD.CreateState( -18, nil, 26, 25, CoD.AnchorTypes.BottomLeftRight )
	state.height = LUI.ExperienceProgressBar.ContainerHeight
	local root = LUI.UIElement.new( state )
    root:setClass( LUI.ExperienceProgressBar )
    root.id = "experienceBar_root"

    if not HUD.CanShowXPBar() then
        return root
    end

	local f7_local2 = CoD.CreateState( LUI.ExperienceProgressBar.Padding, nil, -LUI.ExperienceProgressBar.Padding, nil, CoD.AnchorTypes.LeftRight )
	f7_local2.height = LUI.ExperienceProgressBar.Height
	local f7_local3 = LUI.UIElement.new( f7_local2 )
	root:addElement( f7_local3 )

	-- local background = CoD.CreateState( -970, -12, 12, 0, CoD.AnchorTypes.All )
	-- background.material = RegisterMaterial( "h1_hud_box_blur" )
	-- --background.color = CoD.HudStandards.overlayTint
	-- background.alpha = CoD.HudStandards.blurAlpha
	-- f7_local3:addElement( LUI.UIImage.new( background ) )

	-- local background = CoD.CreateState( -970, -12, 12, 0, CoD.AnchorTypes.All )
	-- background.material = RegisterMaterial( "h1_hud_box_blur" )
	-- --background.color = CoD.HudStandards.overlayTint
	-- background.alpha = CoD.HudStandards.blurAlpha
	-- f7_local3:addElement( LUI.UIImage.new( background ) )

	local background = CoD.CreateState( -1005, -14, 20, 0, CoD.AnchorTypes.All )
	background.material = RegisterMaterial( "h1_hud_box_blur" )
	--background.color = BarColor()--CoD.HudStandards.overlayTint
	background.alpha = CoD.HudStandards.blurAlpha
	f7_local3:addElement( LUI.UIImage.new( background ) )

	local background = CoD.CreateState( -9, 0, 1005, 20, CoD.AnchorTypes.All )
	background.material = RegisterMaterial( "h1_hud_box_blur" )
	--background.color = BarColor()--CoD.HudStandards.overlayTint
	background.alpha = CoD.HudStandards.blurAlpha
	background.zRot = 180
	f7_local3:addElement( LUI.UIImage.new( background ) )	

	local backgroun2 = CoD.CreateState( 0, 0, 5, 0, CoD.AnchorTypes.All )
	backgroun2.material = RegisterMaterial( "black" )
	backgroun2.alpha = 0.02
	f7_local3:addElement( LUI.UIImage.new( backgroun2 ) )
    
	local f7_local5 = CoD.CreateState( LUI.ExperienceProgressBar.Padding, nil, -LUI.ExperienceProgressBar.Padding, nil, CoD.AnchorTypes.LeftRight )
	f7_local5.height = LUI.ExperienceProgressBar.Height
	local f7_local6 = LUI.UIElement.new( f7_local5 )
	f7_local3:addElement( f7_local6 )

	local f7_local7 = CoD.CreateState( 1, 0, nil, nil, CoD.AnchorTypes.TopBottomLeft )
	f7_local7.width = 0
	f7_local6:registerAnimationState( "reset", f7_local7 )

    local f7_local8 = CoD.CreateState( -2, -9, nil, nil, CoD.AnchorTypes.Right )
	f7_local8.width = 4
	f7_local8.height = 4
	f7_local8.material = RegisterMaterial( "h1_deco_indicator_arrow" )
	f7_local6:addElement( LUI.UIImage.new( f7_local8 ) )	

	local leftFlareState = CoD.CreateState( nil, nil, nil, nil, CoD.AnchorTypes.Right )
	leftFlareState.width = 0
	leftFlareState.height = 0
	leftFlareState.material = RegisterMaterial( "h1_ui_xp_progress_flare_l" )
	local leftFlare = LUI.UIImage.new( leftFlareState )
	leftFlare:registerAnimationState( "big", {
		rightAnchor = true,
		left = -34,
		right = -5,
		height = 43
	} )
	local rightFlareState = CoD.CreateState( nil, nil, nil, nil, CoD.AnchorTypes.Right )
	rightFlareState.width = 0
	rightFlareState.height = 0
	rightFlareState.material = RegisterMaterial( "h1_ui_xp_progress_flare_r" )
	local rightFlare = LUI.UIImage.new( rightFlareState )
	rightFlare:registerAnimationState( "big", {
		rightAnchor = true,
		right = 7,
		left = -5,
		height = 43
	} )
	local f7_local13 = LUI.UIElement.new( CoD.CreateState( 0, 0, 0, 0, CoD.AnchorTypes.All ) )
	f7_local6.flareLeft = leftFlare
	f7_local6.flareRight = rightFlare
	f7_local13:setUseStencil( true )
	f7_local6:registerOmnvarHandler( "ui_player_xp_pct", LUI.ExperienceProgressBar.UpdatePlayerXP )
	f7_local6.lastEventValue = 0
	f7_local6.lastWidthValue = 0
	f7_local6:addElement( f7_local13 )
	f7_local6:addElement( rightFlare )
	f7_local6:addElement( leftFlare )

	local barFillState = BarFillState()--CoD.CreateState( -20, 2, 20, -2, CoD.AnchorTypes.All ) --CoD.CreateState( -20, -6, 20, 6, CoD.AnchorTypes.All )
	barFillState.material = BarMaterial()--RegisterMaterial( "white" ) --RegisterMaterial( "h1_ui_experiencebar_fill" )
	local barFill = LUI.UIImage.new( barFillState )
    barFill:setup3SliceRatio( 0.01, 1 )
	f7_local6.bar = barFill
	f7_local13:addElement( barFill )

	local f7_local16 = BarFillState()--CoD.CreateState( -20, 2, 20, -2, CoD.AnchorTypes.All )
	barFill:registerAnimationState( "position", f7_local16 )
	f7_local16.alpha = 1
	f7_local16.color = BarColor()
	barFill:registerAnimationState( "full", f7_local16 )
	f7_local16.alpha = BarAlpha()
	f7_local16.color = BarColor()
	barFill:registerAnimationState( "half", f7_local16 )

	local leftRankState = CoD.CreateState( 9, 5, nil, -10, CoD.AnchorTypes.TopBottomLeft )
	leftRankState.width = LUI.ExperienceProgressBar.ContainerHeight - 16
	leftRankState.material = RegisterMaterial( "black" )
	local leftRank = LUI.UIImage.new( leftRankState )
	root:addElement( leftRank )
	root.leftRank = leftRank
	
	local leftRankTextState = CoD.CreateState( 27, -4.5, nil, nil, CoD.AnchorTypes.Left )
	leftRankTextState.width = 40
	leftRankTextState.height = CoD.TextSettings.TitleFontVeryTiny.Height
	leftRankTextState.font = CoD.TextSettings.TitleFontVeryTiny.Font
	local leftRankText = LUI.UIText.new( leftRankTextState )
	root:addElement( leftRankText )
	root.leftRankText = leftRankText
	
	local rightRankState = CoD.CreateState( nil, 5, -15, -10, CoD.AnchorTypes.TopBottomRight )
	rightRankState.width = LUI.ExperienceProgressBar.ContainerHeight - 16
	rightRankState.material = RegisterMaterial( "black" )
	local rightRank = LUI.UIImage.new( rightRankState )
	rightRank:registerAnimationState( "default", rightRankState )
	rightRank:registerAnimationState( "hidden", {alpha = 0} )
	root:addElement( rightRank )
	root.rightRank = rightRank
	
	root:registerOmnvarHandler( "ui_player_xp_rank", LUI.ExperienceProgressBar.UpdatePlayerRank )
	root:addElement( LUI.UITimer.new( 0, "firstFrameUpdate", nil, true ) )
	root:registerEventHandler( "firstFrameUpdate", function ( element, event )
		f0_local0( element, event, root, f7_local6 )
	end )

	return root
end