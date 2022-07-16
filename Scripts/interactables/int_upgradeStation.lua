UpgradeStation = class()

local hasMod = "$GAME_DATA/Gui/Resolutions/3840x2160/ChallengeMode/IconChallengeCompleted.png"
local hasntMod = "$GAME_DATA/Gui/Resolutions/3840x2160/ChallengeMode/IconChallengeLocked.png"

function UpgradeStation:client_onCreate()
	self.gui = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/UpgradeStation/UpgradeStation.layout" )
	self.gui:setOnCloseCallback( "cl_reset" )

	self.gui:setButtonCallback( "modBtn1", "cl_modBtn1" )
	self.gui:setButtonCallback( "modBtn2", "cl_modBtn2" )
	self.gui:setVisible( "modBtn1", false )
	self.gui:setVisible( "modBtn2", false )

	self.gui:setButtonCallback( "upgradeBtn1", "cl_upgradeBtn1" )
	self.gui:setButtonCallback( "upgradeBtn2", "cl_upgradeBtn2" )
	self.gui:setButtonCallback( "upgradeBtn3", "cl_upgradeBtn3" )
	self.gui:setButtonCallback( "masteryBypass", "cl_masteryBtn" )

	self.gui:setButtonCallback( "wpn1", "cl_weaponSwitch" )
	self.gui:setButtonCallback( "wpn2", "cl_weaponSwitch" )
	self.gui:setButtonCallback( "wpn3", "cl_weaponSwitch" )
	self.gui:setButtonCallback( "wpn4", "cl_weaponSwitch" )
	self.gui:setButtonCallback( "wpn5", "cl_weaponSwitch" )
	self.gui:setButtonCallback( "wpn6", "cl_weaponSwitch" )
	self.gui:setButtonCallback( "wpn7", "cl_weaponSwitch" )

	self.gui:setVisible( "wpn1up1", false )
	self.gui:setVisible( "wpn1up2", false )
	self.gui:setVisible( "wpn2up1", false )
	self.gui:setVisible( "wpn2up2", false )
	self.gui:setVisible( "wpn3up1", false )
	self.gui:setVisible( "wpn3up2", false )
	self.gui:setVisible( "wpn4up1", false )
	self.gui:setVisible( "wpn4up1", false )
	self.gui:setVisible( "wpn5up1", false )
	self.gui:setVisible( "wpn5up2", false )
	self.gui:setVisible( "wpn6up1", false )
	self.gui:setVisible( "wpn6up2", false )
	self.gui:setVisible( "wpn7up1", false )
	self.gui:setVisible( "wpn7up2", false )

	self.gui:setText( "wpn1", "Combat Shotgun" )
	self.gui:setText( "wpn2", "Heavy Cannon" )
	self.gui:setText( "wpn3", "Plasma Rifle" )
	self.gui:setText( "wpn4", "Rocket Launcher" )
	self.gui:setText( "wpn5", "Super Shotgun")
	self.gui:setText( "wpn6", "Ballista" )
	self.gui:setText( "wpn7", "Chaingun" )

	self.gui:setVisible( "wpn1", false )
	self.gui:setVisible( "wpn2", false )
	self.gui:setVisible( "wpn3", false )
	self.gui:setVisible( "wpn4", false )
	self.gui:setVisible( "wpn5", false )
	self.gui:setVisible( "wpn6", false )
	self.gui:setVisible( "wpn7", false )

	self.gui:setVisible( "mod1ico", false )
	self.gui:setVisible( "mod2ico", false )

	self.gui:setImage("wpPointIcon", "$CONTENT_DATA/Gui/UpgradeStation/IconCreativeMode.png" ) -- $GAME_DATA/Gui/Resolutions/3840x2160/Icons/IconCreativeMode.png
	self.gui:setImage("mastPointIcon", "$CONTENT_DATA/Gui/UpgradeStation/IconChallengeMode.png" ) --$GAME_DATA/Gui/Resolutions/3840x2160/Icons/IconChallengeMode.png

	self.CurrentWeapon = nil
	self.CurrentMod = nil
	self.Player = nil
	self.PlayerInventory = nil
	self.Data = nil
end

function UpgradeStation:cl_reset()
	self.CurrentWeapon = nil
	self.CurrentMod = nil
	self.Player = nil
	self.PlayerInventory = nil
	self.Data = nil
end

function UpgradeStation:cl_modBtn1()
	local mod = self.CurrentWeapon.mod1
	self.CurrentMod = 1
	if mod.owned then
		self:cl_upgradeGUI(mod)
	end
end

function UpgradeStation:cl_modBtn2()
	local mod = self.CurrentWeapon.mod2
	self.CurrentMod = 2
	if mod.owned then
		self:cl_upgradeGUI(mod)
	end
end

function UpgradeStation:cl_upgradeGUI( mod )
	if mod ~= nil then
		local points = self.Data.playerData.upgradePoints

		local colour
		if mod.up1.owned then
			self.gui:setText( "upgradeBtn1", "#ffffff" .. mod.up1.name )
		elseif not mod.up1.owned and points >= mod.up1.cost then
			self.gui:setText( "upgradeBtn1", "#ffd549" .. mod.up1.name )
		else
			self.gui:setText( "upgradeBtn1", "#ff1100" .. mod.up1.name )
		end
		self.gui:setVisible( "upgradeBtn1", true )

		if mod.up2.owned then
			self.gui:setText( "upgradeBtn2", "#ffffff" .. mod.up2.name )
		elseif not mod.up2.owned and points >= mod.up2.cost then
			self.gui:setText( "upgradeBtn2", "#ffd549" .. mod.up2.name )
		else
			self.gui:setText( "upgradeBtn2", "#ff1100" .. mod.up2.name )
		end
		self.gui:setVisible( "upgradeBtn2", true )

		if mod.up3 then
			if mod.up3.owned then
				self.gui:setText( "upgradeBtn3", "#ffffff" .. mod.up3.name )
			elseif not mod.up3.owned and points >= mod.up3.cost then
				self.gui:setText( "upgradeBtn3", "#ffd549" .. mod.up3.name )
			else
				self.gui:setText( "upgradeBtn3", "#ff1100" .. mod.up3.name )
			end
			self.gui:setVisible( "upgradeBtn3", true )
		else
			self.gui:setVisible( "upgradeBtn3", false )
		end

		if self.Data.playerData.masteryPoints > 0 and mod.up1.owned and mod.up2.owned and ( mod.up3 and mod.up3.owned or not mod.up3 ) and not mod.mastery.owned then
			self.gui:setText( "masteryBypass", "#ffd549BYPASS THE MASTERY CHALLENGE" )
		elseif mod.mastery.owned then
			self.gui:setText( "masteryBypass", "#ffffffMASTERY OWNED" )
		else
			self.gui:setText( "masteryBypass", "#ff1100BYPASS THE MASTERY CHALLENGE" )
		end

		local valid = not mod.mastery.owned and points > 0 and mod.up1.owned and mod.up2.owned and mod.up3 and mod.up3.owned or not mod.mastery.owned and points > 0 and mod.up1.owned and mod.up2.owned and not mod.up3 or mod.mastery.owned
		if valid then
			self.gui:setText( "mastProgress", tostring(mod.mastery.progress).."/#ff9d00"..tostring(mod.mastery.max) )
		else
			self.gui:setText( "mastProgress", "Buy all upgrades to progress" )
		end


		self.gui:setVisible( "masteryBypass", true )
		self.gui:setText( "tipsBox", mod.tip )
		self.gui:setText( "mastName", mod.mastery.name )
		self.gui:setText( "mastDesc", mod.mastery.desc )
		self.gui:setText( "mastChallenge", mod.mastery.challenge )
		self.gui:setImage( "mastChallengeIcon", mod.mastery.challengeIcon )
		self.gui:setVisible( "mastChallengeIcon", true )
		self.gui:setImage( "mastIcon", mod.mastery.icon )
		self.gui:setVisible( "mastIcon", true )
		self.gui:setText( "upgradeDesc", "" )
	else
		self.gui:setText( "masteryBypass", "#ff1100BYPASS THE MASTERY CHALLENGE" )
		self.gui:setText( "tipsBox", "" )
		self.gui:setText( "mastName", "" )
		self.gui:setText( "mastDesc", "" )
		self.gui:setText( "mastChallenge", "" )
		self.gui:setVisible( "mastChallengeIcon", false )
		self.gui:setVisible( "mastIcon", false )
		self.gui:setText( "mastProgress", "" )
		self.gui:setVisible( "upgradeBtn1", false )
		self.gui:setVisible( "upgradeBtn2", false )
		self.gui:setVisible( "upgradeBtn3", false )
		self.gui:setText( "upgradeDesc", "" )
	end
end

function UpgradeStation:cl_upgradeBtn1()
	local mod = self.CurrentMod == 1 and self.CurrentWeapon.mod1 or self.CurrentWeapon.mod2
	self.gui:setText( "upgradeDesc", mod.up1.desc )
	self:cl_manageUpgrades( mod, mod.up1 )
end

function UpgradeStation:cl_upgradeBtn2()
	local mod = self.CurrentMod == 1 and self.CurrentWeapon.mod1 or self.CurrentWeapon.mod2
	self.gui:setText( "upgradeDesc", mod.up2.desc )
	self:cl_manageUpgrades( mod, mod.up2 )
end

function UpgradeStation:cl_upgradeBtn3()
	local mod = self.CurrentMod == 1 and self.CurrentWeapon.mod1 or self.CurrentWeapon.mod2
	self.gui:setText( "upgradeDesc", mod.up3.desc )
	self:cl_manageUpgrades( mod, mod.up3 )
end

function UpgradeStation:cl_manageUpgrades( mod, upgrade )
	local points = self.Data.playerData.upgradePoints
	if not upgrade.owned and points >= upgrade.cost then
		points = points - upgrade.cost
		upgrade.owned = true

		self.Data.playerData.upgradePoints = points
		self:cl_upgradeGUI( mod )
		self.network:sendToServer("sv_save")
	end
end

function UpgradeStation:cl_masteryBtn()
    local points = self.Data.playerData.masteryPoints
    local mod = self.CurrentMod == 1 and self.CurrentWeapon.mod1 or self.CurrentWeapon.mod2
	local valid = not mod.mastery.owned and points > 0 and mod.up1.owned and mod.up2.owned and ( not mod.up3 or mod.up3.owned  ) and not mod.mastery.owned
	--mod.up1.owned and mod.up2.owned and mod.up3 and mod.up3.owned or not mod.mastery.owned and points > 0 and mod.up1.owned and mod.up2.owned and not mod.up3

    if valid then
        points = points - 1
        mod.mastery.owned =  true
		mod.mastery.progress = mod.mastery.max
        self.Data.playerData.masteryPoints = points
		self:cl_upgradeGUI( mod )
        self.gui:setText( "masteryBypass", "#ffffff" .. "MASTERY OWNED" )
        self.network:sendToServer("sv_save")
    end
end

function UpgradeStation:cl_weaponSwitch( button )
	self.CurrentWeapon = self.Data.weaponData[g_allWeapons.upgradeStation[tonumber(button:sub(-1))].tableName]

	self:cl_wpnModGUI()
	self:cl_upgradeGUI()
end

function UpgradeStation:cl_wpnModGUI()
	self.gui:setVisible( "masteryBypass", false )
	self.gui:setText( "wpTips", self.CurrentWeapon.tip )
end

function UpgradeStation:sv_save()
	sm.event.sendToPlayer( self.Player, "sv_save" )
end

function UpgradeStation:client_onInteract( char, lookAt )
	if lookAt then
		self.Player = sm.localPlayer.getPlayer()
		self.PlayerInventory = self.Player:getInventory()
		self.CurrentWeapon = nil
		self.CurrentMod = 1

		self.Data = self.Player:getClientPublicData().data

		for pos, moddable in pairs(g_allWeapons.upgradeStation) do
			local widget = "wpn"..tostring(pos)
			local owned = sm.container.totalQuantity( self.PlayerInventory, moddable.uuid ) > 0

			self.gui:setVisible( widget, owned )
			self.gui:setVisible( widget.."up1", owned )
			self.gui:setVisible( widget.."up2", owned )
			if self.CurrentWeapon == nil and owned then
				self.CurrentWeapon = self.Data.weaponData[moddable.tableName]
			end
		end

		self.gui:setVisible( "modBtn1", false )
		self.gui:setVisible( "modBtn2", false )
		self.gui:setVisible( "upgradeBtn1", false )
		self.gui:setVisible( "upgradeBtn2", false )
		self.gui:setVisible( "upgradeBtn3", false )
		self.gui:setVisible( "masteryBypass", false )

		self.gui:setText( "tipsBox", "" )
		self.gui:setText( "mastName", "" )
		self.gui:setText( "mastDesc", "" )
		self.gui:setText( "mastChallenge", "" )
		self.gui:setVisible( "mastChallengeIcon", false )
		self.gui:setVisible( "mastIcon", false )
		self.gui:setText( "mastProgress", "" )
		self.gui:setText( "upgradeDesc", "" )

		self:cl_wpnModGUI()

		for pos, moddable in pairs(g_allWeapons.upgradeStation) do
			local widget = "wpn"..tostring(pos).."up"
			self.gui:setImage( widget.."1", self.Data.weaponData[moddable.tableName].mod1.owned and hasMod or hasntMod )

			if self.Data.weaponData[moddable.tableName].mod2 then
				self.gui:setImage( widget.."2", self.Data.weaponData[moddable.tableName].mod2.owned and hasMod or hasntMod )
			end
		end

		self.gui:open()
	end
end

function UpgradeStation:client_onUpdate()
	if self.gui:isActive() and self.Player ~= nil then
		self.gui:setText( "wpPoints", tostring(self.Data.playerData.upgradePoints) )
		self.gui:setText( "mastPoints", tostring(self.Data.playerData.masteryPoints) )

		local colour = self.CurrentWeapon.mod1.owned and "#ffffff" or "#ff1100"
		self.gui:setText( "modBtn1", colour .. self.CurrentWeapon.mod1.name )
		self.gui:setVisible( "modBtn1", true )

		self.gui:setImage( "mod1ico", self.CurrentWeapon.mod1.icon )
		self.gui:setVisible( "mod1ico", true )

		if self.CurrentWeapon.mod2 ~= nil then
			local colour = self.CurrentWeapon.mod2.owned and "#ffffff" or "#ff1100"
			self.gui:setText( "modBtn2", colour .. self.CurrentWeapon.mod2.name )
			self.gui:setVisible( "modBtn2", true )
			self.gui:setImage( "mod2ico", self.CurrentWeapon.mod2.icon )
			self.gui:setVisible( "mod2ico", true )
		else
			self.gui:setVisible( "modBtn2", false )
		end
	end
end

function UpgradeStation:client_onDestroy()
	self.gui:close()
	self.gui:destroy()
end