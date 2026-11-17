if Engine.InFrontend() then
    -- Disable CP
    Engine.SetDvarInt("ui_enable_cp", 0)

    -- Disable CP store
    Engine.SetDvarInt("ui_show_store", 0)

    -- Remove CoD account button
    if Engine.IsMultiplayer() and CoD.IsCoDAccountRegistrationAvailableInMyRegion() then
        LUI.removemenubutton("pc_controls", 4)
    end
end

-- Sin ventana de "Cambiando de host" al salir en mitad de una partida (no hay migración de host)
LUI.MenuBuilder.m_types_build["host_migration_main"] = function()
    local element = LUI.UIElement.new()
    element.id = "host_migration_id"
    element:registerEventHandler("hide_host_migration", function(menu)
        LUI.FlowManager.RequestLeaveMenu(menu)
    end)
    return element
end

-- Remove social button
LUI.MenuBuilder.m_definitions["online_friends_widget"] = function()
    return {
        type = "UIElement"
    }
end
