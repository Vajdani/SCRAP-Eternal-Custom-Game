PUBot = class()

function PUBot:server_onCreate()
	self.sv = {}
	self.sv.data = {
		player = nil,
		selectedRune = nil,
		runeData = {}
	}
	self.network:setClientData( self.sv.data )
end

function PUBot:sv_save()
	--sm.event.sendToPlayer( self.sv.data.player, "sv_save" )
	self.network:setClientData( self.sv.data )
end

function PUBot:sv_reset()
	self.sv.data = {
		player = nil,
		selectedRune = nil,
		runeData = {}
	}
	self.network:setClientData( self.sv.data )
end

function PUBot:sv_setData( data )
	self.sv.data = data
	self:sv_save()
end

function PUBot:sv_onInteract( char )
	self.sv.data.player = char:getPlayer()
	self.sv.data.runeData = self.sv.data.player:getPublicData().data.suitData.runes
	self.network:setClientData( self.sv.data )
end

function PUBot:sv_equipRune( args )
	self.sv.data = args.data
	sm.event.sendToPlayer( self.sv.data.player, "sv_changeRune", { button = args.button, selected = self.sv.data.selectedRune, int = self.interactable } )
	self.network:setClientData( self.sv.data )
end

function PUBot:sv_updateEquippedRunes( runes )
	self.network:sendToClients("cl_updateEquippedRunes", runes)
end


function PUBot:client_onCreate()
    self.cl = {}
	self.cl.data = {
		player = nil,
		selectedRune = nil,
		runeData = {}
	}

	self.cl.gui = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/PlayerUpgradesBot/PUBot.layout" )
	self.cl.gui:setOnCloseCallback( "cl_reset" )

	for i = 1, 9 do
		self.cl.gui:setButtonCallback( "rune"..tostring(i), "cl_runeSelect" )
	end

	for i = 1, 3 do
		self.cl.gui:setButtonCallback( "equippedrune"..tostring(i), "cl_equipRune" )
	end
end

function PUBot:cl_reset()
	self.network:sendToServer("sv_reset")
end

function PUBot:client_onClientDataUpdate( data, channel )
	self.cl.data = data
end

function PUBot:cl_runeSelect( button )
	local rune = tonumber(button:sub(-1))

	self.cl.gui:setButtonState( "rune"..tostring(self.cl.data.selectedRune), false )
	self.cl.data.selectedRune = nil

	if self.cl.data.selectedRune == rune then
		return
	end

	self.cl.data.selectedRune = rune
	self.network:sendToServer("sv_setData", self.cl.data)
end

function PUBot:cl_equipRune( button )
	if self.cl.data.selectedRune == nil then return end
	self.network:sendToServer("sv_equipRune", { button = button, data = self.cl.data })

	self.cl.gui:setButtonState( "rune"..tostring(self.cl.data.selectedRune), false )
	self.cl.data.selectedRune = nil
end

function PUBot:client_canInteract()
	return self.cl.data.player == nil
end

function PUBot:client_onInteract( char, lookAt )
	if lookAt then
		self.network:sendToServer("sv_onInteract", char)

		self.cl.gui:open()
	end
end

function PUBot:client_onUpdate()
	if not sm.exists(self.cl.gui) or self.cl.data.player == nil then return end

	if self.cl.gui:isActive() then
		for v, k in pairs(gui_runes) do
			self.cl.gui:setImage( "rune"..tostring(v).."ico", k.icon)
		end

		if self.cl.data.selectedRune ~= nil then
			self.cl.gui:setButtonState( "rune"..tostring(self.cl.data.selectedRune), true )
			self.cl.gui:setText( "descBox", gui_runes[self.cl.data.selectedRune].desc)
		end

		for i = 1, 3 do
			local equippedRune = self.cl.data.runeData.equipped[i]
			local widget = "equippedrune"..tostring(i).."ico"
			if equippedRune ~= nil then
				local rune = getGui_RunesIndexByRuneName(equippedRune.name)
				if rune ~= nil then
					self.cl.gui:setImage( widget, rune.icon)
				end
			end

			self.cl.gui:setVisible( widget, equippedRune ~= nil )
		end
	end
end

function PUBot:cl_updateEquippedRunes( runes )
	self.cl.data.runeData = runes
end