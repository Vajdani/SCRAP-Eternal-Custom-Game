ModBot = class()

local vidTest = {
	"$CONTENT_DATA/Gui/ModBot/no mouth.png",
	"$CONTENT_DATA/Gui/ModBot/pensive.png",
	"$CONTENT_DATA/Gui/ModBot/weary.png"
}

local displayListLength = 4
local canMod = "$GAME_DATA/Gui/Resolutions/3840x2160/ChallengeMode/IconChallengeCompleted.png"
local cantMod = "$GAME_DATA/Gui/Resolutions/3840x2160/ChallengeMode/IconChallengeLocked.png"

function ModBot:server_onCreate()
	self.sv = {
		cycleIndex = 1,
		player = nil,
		playerInv = nil,
		data = nil,
		currentWeapon = nil,
		currentMod = 1,
	}
end

function ModBot:sv_save()
	sm.event.sendToPlayer( self.sv.player, "sv_save" )
end

function ModBot:client_onCreate()
	self.cl = {
		frameCount = 0,
		vidIndex = 0,
		data = {},
		gui = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/ModBot/ModBot.layout" )
	}
	self.cl.gui:setOnCloseCallback( "cl_reset" )

	self.cl.gui:setButtonCallback( "wpnBtn1", "cl_weaponSwitch" )
	self.cl.gui:setButtonCallback( "wpnBtn2", "cl_weaponSwitch" )
	self.cl.gui:setButtonCallback( "wpnBtn3", "cl_weaponSwitch" )
	self.cl.gui:setButtonCallback( "wpnBtn4", "cl_weaponSwitch" )

	self.cl.gui:setVisible( "wpnBtn1", true )
	self.cl.gui:setVisible( "wpnBtn2", true )
	self.cl.gui:setVisible( "wpnBtn3", true )
	self.cl.gui:setVisible( "wpnBtn4", true )

	self.cl.gui:setImage( "cycleUp", "$GAME_DATA/Gui/Resolutions/3840x2160/Lift/gui_icon_lift_uploaded.png" )
	self.cl.gui:setImage( "cycleDown", "$GAME_DATA/Gui/Resolutions/3840x2160/Lift/gui_icon_lift_downloaded.png" )
	self.cl.gui:setVisible( "cycleUp", true )
	self.cl.gui:setVisible( "cycleDown", true )
	self.cl.gui:setButtonCallback( "cycleUp", "cl_cycle" )
	self.cl.gui:setButtonCallback( "cycleDown", "cl_cycle" )

	self.cl.gui:setButtonCallback( "mod1Purchase", "cl_modBtn" )
	self.cl.gui:setButtonCallback( "mod2Purchase", "cl_modBtn" )

	self.cl.gui:setOnCloseCallback( "cl_reset" )
end

function ModBot:cl_reset()
	sm.localPlayer.getPlayer().character:setLockingInteractable( nil )
	self.network:sendToServer("sv_reset")
end

function ModBot:sv_reset()
	self.sv = {
		cycleIndex = 1,
		player = nil,
		playerInv = nil,
		data = nil,
		currentWeapon = nil,
		currentMod = 1,
	}
	self.network:sendToClients("cl_setData", self.sv)
end

function ModBot:sv_setMod( mod )
	self.sv.currentMod = mod
end

function ModBot:sv_setData( data )
	self.sv = data
	self.network:sendToClients("cl_setData", self.sv)
end

function ModBot:cl_setData( data )
	self.cl.data = data
end

function ModBot:cl_weaponSwitch( button )
	local index = self.cl.data.cycleIndex + tonumber(button:sub(-1)) - 1

	if sm.container.totalQuantity( self.cl.data.playerInv, g_allWeapons.moddables[index].uuid ) == 0 then
		sm.gui.displayAlertText( "You dont have that weapon yet!", 2.5 )
		sm.audio.play("RaftShark")
		return
	end

	self.cl.gui:setVisible( "modInfo", false )
	self.cl.gui:setVisible( "modVid", false )
	self.cl.vidPlaying = false
	self.cl.data.currentMod = 1
	self.cl.data.currentWeapon = g_allWeapons.moddables[index]

	self.cl.gui:setVisible( "mod2Purchase", self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod2 ~= nil )
	self.network:sendToServer("sv_setData", self.cl.data)
end

function ModBot:cl_cycle( button )
	if button == "cycleUp" then
		if self.cl.data.cycleIndex > 1 then
			self.cl.data.cycleIndex = self.cl.data.cycleIndex - 1
		end
	else
		if self.cl.data.cycleIndex < #g_allWeapons.moddables - displayListLength + 1 then
			self.cl.data.cycleIndex = self.cl.data.cycleIndex + 1
		end
	end

	if sm.container.totalQuantity( self.cl.data.playerInv, g_allWeapons.moddables[self.cl.data.cycleIndex].uuid ) == 0 then
		self.cl.gui:setVisible( "mod1Purchase", false )
		self.cl.gui:setVisible( "mod2Purchase", false )
		return
	else
		self.cl.gui:setVisible( "mod1Purchase", true )
		self.cl.gui:setVisible( "mod2Purchase", true )
	end

	self.cl.gui:setVisible( "modInfo", false )
	self.cl.gui:setVisible( "modVid", false )
	self.cl.vidPlaying = false
	self.cl.data.currentMod = 1
	self.cl.data.currentWeapon = g_allWeapons.moddables[self.cl.data.cycleIndex]
	self.network:sendToServer("sv_setData", self.cl.data)
end

function ModBot:cl_modBtn( button )
	self.network:sendToServer("sv_setMod", button == "mod1Purchase" and 1 or 2)
	self.cl.gui:setVisible( "modInfo", true )

	--self.cl.gui:setVisible( "modVid", true )
	--self.vidPlaying = true
end

function ModBot:client_canInteract()
	return self.cl.data.player == nil
end

function ModBot:client_onInteract( char, lookAt )
	if lookAt then
		self.cl.data.player = sm.localPlayer.getPlayer()
		self.cl.data.playerInv = self.cl.data.player:getInventory()
		self.cl.data.weaponData = self.cl.data.player.clientPublicData.data.weaponData

		local modsOwned = 0
		for v, k in pairs(self.cl.data.weaponData) do
			if self.cl.data.weaponData[v].mod1 ~= nil and self.cl.data.weaponData[v].mod1.owned then
				modsOwned = modsOwned + 1
			end

			if self.cl.data.weaponData[v].mod2 ~= nil and self.cl.data.weaponData[v].mod2.owned then
				modsOwned = modsOwned + 1
			end
		end

		if modsOwned == 14 then
			sm.gui.displayAlertText("You already have all of the upgrades!", 2.5)
			sm.audio.play("RaftShark")

			--if #sm.player.getAllPlayers() == 1 then
			--	self.network:sendToServer("sv_sendDestroy", sm.localPlayer.getPlayer())
			--end

			--return
		end

		char:setLockingInteractable( self.interactable )

		self.cl.gui:setVisible( "mod1Purchase", true )
		self.cl.gui:setVisible( "mod2Purchase", true )
		self.cl.gui:setVisible( "modInfo", false )
		self.cl.gui:setVisible( "modVid", false )
		self.cl.vidPlaying = false
		self.cl.data.cycleIndex = 1

		self.cl.data.currentWeapon = g_allWeapons.moddables[self.cl.data.cycleIndex]
		self.cl.data.currentMod = 0

		self.cl.gui:open()
		self.network:sendToServer("sv_setData", self.cl.data)
	end
end

function ModBot:client_onAction( action, state )
	if action == sm.interactable.actions.jump then
		self.network:sendToServer("sv_onAction", sm.localPlayer.getPlayer())
	end

	return true
end

function ModBot:sv_onAction( player )
	local close = true

	if self.sv.currentMod == 1 then
		if not self.sv.data[self.sv.currentWeapon.tableName].mod1.owned then
			self.sv.data[self.sv.currentWeapon.tableName].mod1.owned = true
		else
			close = false
		end
	else
		if not self.sv.data[self.sv.currentWeapon.tableName].mod2.owned then
			self.sv.data[self.sv.currentWeapon.tableName].mod2.owned = true
		else
			close = false
		end
	end

	if close then
		self:sv_save()
		self.network:sendToServer("sv_sendDestroy", sm.localPlayer.getPlayer())
	end

	self.network:sendToClient(player, "cl_onAction_msg", close)
end

function ModBot:cl_onAction_msg( sucess )
	if sucess then
		sm.effect.playHostedEffect( "Part - Upgrade", self.interactable )
		self.cl.gui:close()
	else
		sm.gui.displayAlertText("You already have this upgrade! Choose one you dont have yet.", 2.5)
		sm.audio.play("RaftShark")
	end
end

function ModBot:client_onUpdate( dt )
	if not sm.exists(self.cl.gui) or self.cl.data.player == nil then return end

	if sm.exists(self.cl.gui) and self.cl.gui:isActive() then
		local guns = {
			g_allWeapons.moddables[self.cl.data.cycleIndex],
			g_allWeapons.moddables[self.cl.data.cycleIndex+1],
			g_allWeapons.moddables[self.cl.data.cycleIndex+2],
			g_allWeapons.moddables[self.cl.data.cycleIndex+3]
		}

		for pos, moddable in pairs(guns) do
			local index = tostring(pos)
			local currentButton = "wpnBtn"..index
			local currentIcon = "wpn"..index.."ico"
			local icon = cantMod

			if sm.container.totalQuantity( self.cl.data.playerInv, moddable.uuid ) > 0 then
				icon = canMod
			end

			self.cl.gui:setImage( currentIcon, icon )

			local colour = "#ff9d00"
			for v, k in pairs(self.cl.data.weaponData) do
				local weapon = self.cl.data.weaponData[v]
				if weapon.uuid == moddable.uuid then
					if weapon.mod1.owned and weapon.mod2 ~= nil and weapon.mod2.owned or weapon.mod1.owned and weapon.mod2 == nil then
						colour = "#ffffff"
					end
				end
			end
			self.cl.gui:setText( currentButton, colour..moddable.name )
		end

		for i = 0, 3 do
			local textbox = "wpn"..tostring(i+1).."index"
			self.cl.gui:setText( textbox, tostring(self.cl.data.cycleIndex + i) )
		end

		local text = self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod1.owned and "#ffffff"..self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod1.name.." (OWNED)" or "#ff9d00"..self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod1.name
		self.cl.gui:setText( "mod1Purchase", text )
		self.cl.gui:setImage( "mod1ico", self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod1.icon)

		if self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod2 ~= nil then
			local text = self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod2.owned and "#ffffff"..self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod2.name.." (OWNED)" or "#ff9d00"..self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod2.name
			--self.cl.gui:setVisible( "mod2Purchase", true )
			self.cl.gui:setText( "mod2Purchase", text )
			self.cl.gui:setImage( "mod2ico", self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod2.icon)
		else
			self.cl.gui:setVisible( "mod2Purchase", false )
		end

		local modInfo
		if self.cl.data.currentMod == 1 then
			modInfo = self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod1.tip
		elseif self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod2 ~= nil then
			modInfo = self.cl.data.weaponData[self.cl.data.currentWeapon.tableName].mod2.tip
		end

		if modInfo ~= nil then
			self.cl.gui:setText( "modInfo", modInfo )
		end
	end
end

function ModBot:client_onFixedUpdate( dt )
	if self.cl.vidPlaying then
		self.cl.frameCount = self.cl.frameCount + dt
		if self.cl.frameCount >= dt * (40/#vidTest) then
			self.cl.frameCount = 0
			self.cl.vidIndex = self.cl.vidIndex < #vidTest and self.cl.vidIndex + 1 or 1
			self.cl.gui:setImage( "modVid", vidTest[self.cl.vidIndex] )
		end
	else
		self.cl.frameCount = 0
	end
end

function ModBot:sv_sendDestroy( player )
	self.network:sendToClients("cl_destroy", player)
	self:sv_destroy()
end

function ModBot:cl_destroy( player )
	self.cl.gui:close()
	self.cl.gui:destroy()

	if player == sm.localPlayer.getPlayer() then
		self.cl.player:getCharacter():setLockingInteractable( nil )
	end
end

function ModBot:sv_destroy()
	sm.shape.destroyPart( self.cl.shape )
end