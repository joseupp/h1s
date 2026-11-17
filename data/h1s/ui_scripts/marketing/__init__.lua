-- Panel "Destacado" (LUI.MarketingPanel): en PC el juego lo crea como un elemento que solo responde al ratón, así que
-- con el mando no se podía seleccionar. Se hace seleccionable y, al llegar a él con el mando, se resalta como en consola
-- (izquierda/derecha cambian de mensaje, aceptar lo abre y arriba/abajo vuelven a los botones).
-- Las funciones de foco del panel (OnPanelFocus...) son internas de su módulo: se rehacen aquí.
if game:issingleplayer() or not Engine.InFrontend() or not LUI.MarketingPanel then
    return
end

local animation_time = 75

local function set_panel_focus(panel, focused)
    local state = focused and "focused" or "unfocused"
    panel.isFocused = focused

    if panel.autoScrollTimer then
        if focused then
            LUI.UITimer.Stop(panel.autoScrollTimer)
        else
            LUI.UITimer.Reset(panel.autoScrollTimer)
        end
    end

    local container = panel.panel
    if not container then
        return
    end

    if container.highlight then
        container.highlight:animateToState(state, animation_time)
    end

    if panel.numButtons and panel.numButtons > 1 then
        if container.arrowLeft then
            container.arrowLeft:animateToState(state, animation_time)
        end

        if container.arrowRight then
            container.arrowRight:animateToState(state, animation_time)
        end
    end
end

local original_new = LUI.MarketingPanel.new

LUI.MarketingPanel.new = function(...)
    local panel = original_new(...)
    if not Engine.IsPC() or not panel or not panel.panelData then
        return panel
    end

    panel:makeFocusable()

    panel:registerEventHandler("gain_focus", function(element, event)
        if LUI.UIElement.gainFocus then
            LUI.UIElement.gainFocus(element, event)
        end

        set_panel_focus(element, true)
    end)

    panel:registerEventHandler("lose_focus", function(element, event)
        if LUI.UIElement.loseFocus then
            LUI.UIElement.loseFocus(element, event)
        end

        if element.isFocused then
            set_panel_focus(element, false)
        end
    end)

    return panel
end
