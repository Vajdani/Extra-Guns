Installer = class()

function Installer:client_canInteract()
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Use" ), "Install handheld gun" )
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Tinker" ), "Uninstall handheld gun" )

    return true
end

function Installer:client_onInteract()
    local data = sm.json.open( "$CONTENT_d9e6682a-1885-44b2-9cda-11bf5fec9dac/json/new_spudguns.json" )
    sm.json.save( data, "$SURVIVAL_DATA/Tools/ToolSets/spudguns.json" )

    --local iconmap = sm.json.open( "$CONTENT_d9e6682a-1885-44b2-9cda-11bf5fec9dac/json/new_iconmap.xml" )
    --sm.json.save( "$CONTENT_d9e6682a-1885-44b2-9cda-11bf5fec9dac/json/new_iconmap.xml", "$SURVIVAL_DATA/Gui/IconMapSurvival.xml" )

    local descriptions = sm.json.open( "$CONTENT_d9e6682a-1885-44b2-9cda-11bf5fec9dac/json/new_descriptions.json" )
    sm.json.save( descriptions, "$SURVIVAL_DATA/Gui/Language/English/inventoryDescriptions.json" )

    self.network:sendToServer("sv_displayMsg", "Handheld gun #ff9d00installed")
end

function Installer:client_onTinker()
    local data = sm.json.open( "$CONTENT_d9e6682a-1885-44b2-9cda-11bf5fec9dac/json/default_spudguns.json" )
    sm.json.save( data, "$SURVIVAL_DATA/Tools/ToolSets/spudguns.json" )

    --local iconmap = sm.json.open( "$CONTENT_d9e6682a-1885-44b2-9cda-11bf5fec9dac/json/default_iconmap.xml" )
    --sm.json.save( iconmap, "$SURVIVAL_DATA/Gui/IconMapSurvival.xml" )

    local descriptions = sm.json.open( "$CONTENT_d9e6682a-1885-44b2-9cda-11bf5fec9dac/json/default_descriptions.json" )
    sm.json.save( descriptions, "$SURVIVAL_DATA/Gui/Language/English/inventoryDescriptions.json" )

    self.network:sendToServer("sv_displayMsg", "Handheld gun #ff9d00uninstalled")
end

function Installer:sv_displayMsg( msg )
    self.network:sendToClients("cl_displayMsg", msg)
end

function Installer:cl_displayMsg( msg )
    sm.gui.displayAlertText(msg.."#ffffff! Rejoin the world for it to take effect!", 2.5)
end