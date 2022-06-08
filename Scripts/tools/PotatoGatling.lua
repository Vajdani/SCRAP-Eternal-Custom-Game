dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"


PotatoGatling = class()

local mod_turret = "Mobile Turret"
local mod_shield = "Energy Shield"

local renderables = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_spinner/char_spudgun_barrel_spinner.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_spinner/char_spudgun_sight_spinner.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
}

local renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend", "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"}
local renderablesFp = {"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function PotatoGatling.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunSpinner - SpinnerMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunSpinner - FPSpinnerMuzzel" )
	self.windupEffect = sm.effect.createEffect( "SpudgunSpinner - Windup" )

	--SE

	--General stuff
	self.player = sm.localPlayer.getPlayer()
	self.playerChar = self.player:getCharacter()

	self.playerData = sm.playerInfo[self.player:getId()].playerData
	self.data = sm.playerInfo[self.player:getId()].weaponData.chaingun

	self.dmgMult = 1
	self.spdMult = 1
	self.Damage = 20
	self.isFiring = false
	self.usingMod = false

	--Mod switch
	if self.data.mod1.owned then
		self.currentWeaponMod = mod_turret
	elseif self.data.mod2.owned then
		self.currentWeaponMod = mod_shield
	else
		self.currentWeaponMod = "poor"
	end

	self.modSwitchCount = 0
	self.afterModCD = false
	self.afterModCDCount = 1

	--mod_turret
	self.mobileTurretActivateCD = 1.5
	self.mobileTurretActivateMax = 1.5
	self.canFireMobileTurret = false
	self.mobileTurretOverheatCD = 15
	self.overheated = false
	self.trMobility = false

	--mod_shield
	self.energyShieldActiveCD = 5
	self.canUseEnergyShield = true
	self.energyShieldActive = false
	self.esRechargeDivider = 3
	self.esCanProgress = true
	self.esMasteryKills = 0

	self.shield = {
		effect = sm.effect.createEffect("Energy Shield"),
		trigger = self.network:sendToServer("sv_createShieldTrigger"),
		launch = false,
		pos = sm.vec3.zero(),
		dir = sm.vec3.zero(),
		lifeTime = 0
	}
	--SE
end

function PotatoGatling.client_onRefresh( self )
	self:loadAnimations()
end

function PotatoGatling.loadAnimations( self )

	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			shoot = { "spudgun_shoot", { crouch = "spudgun_crouch_shoot" } },
			aim = { "spudgun_aim", { crouch = "spudgun_crouch_aim" } },
			aimShoot = { "spudgun_aim_shoot", { crouch = "spudgun_crouch_aim_shoot" } },
			idle = { "spudgun_idle" },
			pickup = { "spudgun_pickup", { nextAnimation = "idle" } },
			putdown = { "spudgun_putdown" }
		}
	)
	local movementAnimations = {
		idle = "spudgun_idle",
		idleRelaxed = "spudgun_relax",

		sprint = "spudgun_sprint",
		runFwd = "spudgun_run_fwd",
		runBwd = "spudgun_run_bwd",

		jump = "spudgun_jump",
		jumpUp = "spudgun_jump_up",
		jumpDown = "spudgun_jump_down",

		land = "spudgun_jump_land",
		landFwd = "spudgun_jump_land_fwd",
		landBwd = "spudgun_jump_land_bwd",

		crouchIdle = "spudgun_crouch_idle",
		crouchFwd = "spudgun_crouch_fwd",
		crouchBwd = "spudgun_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	setTpAnimation( self.tpAnimations, "idle", 5.0 )

	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "spudgun_pickup", { nextAnimation = "idle" } },
				unequip = { "spudgun_putdown" },

				idle = { "spudgun_idle", { looping = true } },
				shoot = { "spudgun_shoot", { nextAnimation = "idle" } },
				
				aimInto = { "spudgun_aim_into", { nextAnimation = "aimIdle" } },
				aimExit = { "spudgun_aim_exit", { nextAnimation = "idle", blendNext = 0 } },
				aimIdle = { "spudgun_aim_idle", { looping = true} },
				aimShoot = { "spudgun_aim_shoot", { nextAnimation = "aimIdle"} },

				sprintInto = { "spudgun_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
				sprintExit = { "spudgun_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
				sprintIdle = { "spudgun_sprint_idle", { looping = true } },
			}
		)
	end

	self.normalFireMode = {
		fireCooldown = 0.1,
		spreadCooldown = 0.18,
		spreadIncrement = 0.10,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 2.5,
		fireVelocity = 260.0,
		
		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,
		
		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.aimFireMode = {
		fireCooldown = 0.1,
		spreadCooldown = 0.18,
		spreadIncrement = 0.10,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 2.5,
		fireVelocity =  260.0,
		
		minDispersionStanding = 0.01,
		minDispersionCrouching = 0.04,
		
		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.fireCooldownTimer = 0.0
	self.spreadCooldownTimer = 0.0

	self.movementDispersion = 0.0

	self.sprintCooldownTimer = 0.0
	self.sprintCooldown = 0.3

	self.aimBlendSpeed = 3.0
	self.blendTime = 0.2

	self.jointWeight = 0.0
	self.spineWeight = 0.0
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )

	self.gatlingActive = false
	self.gatlingBlendSpeedIn = 100 --1.5
	self.gatlingBlendSpeedOut = 0.375
	self.gatlingWeight = 0.0
	self.gatlingTurnSpeed = ( 1 / self.normalFireMode.fireCooldown ) / 3
	self.gatlingTurnFraction = 0.0
end

--SE
function PotatoGatling:sv_killUnits( trigger, result )
	if self.shield.launch then
		for pos, char in pairs(result) do
			if sm.exists(char) and char:getCharacterType() ~= unit_mechanic then
				sm.event.sendToUnit( char:getUnit(), "sv_se_takeDamage", { damage = 100, impact = self.lookDir, hitPos = char:getWorldPosition(), attacker = self.player } )
				sm.event.sendToUnit(char:getUnit(), "sv_addStagger", 10 )
			end
		end
	end
end

function PotatoGatling:sv_createShieldTrigger()
	self.shield.trigger = sm.areaTrigger.createBox( sm.vec3.new(2, 0.25, 1.5), sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.character )
	self.shield.trigger:bindOnEnter( "sv_killUnits" )
end

function PotatoGatling.client_onFixedUpdate( self, dt )
	local playerData = sm.playerInfo[self.player:getId()].playerData
	self.data = sm.playerInfo[self.player:getId()].weaponData.chaingun
	self.dmgMult = playerData.damageMultiplier
	self.spdMult = playerData.speedMultiplier

	--upgrades
	self.mobileTurretActivateMax = self.data.mod1.up1.owned and 0.75 or 1.5
	self.trMobility = self.data.mod1.up2.owned and true or false
	self.esRechargeDivider = self.data.mod2.up1.owned and 1.875 or 3

	self.Damage = self.currentWeaponMod == mod_turret and self.usingMod and 26 or 24

	--powerup
	local increase = dt * self.spdMult
	local multVal = self.berserk and self.dmgMult * 4 or self.dmgMult
	self.Damage = self.Damage * multVal

	--Mod switch cooldown
	if self.afterModCD then
		self.afterModCDCount = self.afterModCDCount + increase*1.75

		if self.afterModCDCount >= 1 then
			self.afterModCDCount = 1
			self.afterModCD = false
		end
	end

	--mod_turret activate
	if self.currentWeaponMod == mod_turret and self.usingMod and not self.afterModCD then
		if self.mobileTurretActivateCD < self.mobileTurretActivateMax then
			self.mobileTurretActivateCD = self.mobileTurretActivateCD + increase*2
		end

		if self.mobileTurretActivateCD >= self.mobileTurretActivateMax then
			self.mobileTurretActivateCD = self.mobileTurretActivateMax
			self.canFireMobileTurret = true
		end
	else
		self.canFireMobileTurret = false
	end

	--mod_turret overheat
	if self.mobileTurretOverheatCD < 15 and self.usingMod and self.fireCooldownTimer <= 0.0 or self.mobileTurretOverheatCD < 15 and not self.usingMod or self.mobileTurretOverheatCD < 15 and self.usingMod and self.overheated then
		self.mobileTurretOverheatCD = self.mobileTurretOverheatCD + increase
	end

	if self.mobileTurretOverheatCD >= 15 then
		self.mobileTurretOverheatCD = 15
		self.overheated = false
	end

	if self.mobileTurretOverheatCD <= 0 then
		self.overheated = true
	end

	local kills = 0
	for pos, val in pairs(self.playerData.kills) do
		kills = kills + val
	end
	self.esMasteryKills = kills

	if self.data.mod1.up1.owned and self.data.mod1.up2.owned and not self.data.mod1.mastery.owned then
		if self.esCanProgress and self.currentWeaponMod == mod_turret and self.usingMod and not self.overheated then

			if self.esMasteryKills >= 5 then
				self.data.mod1.mastery.progress = self.data.mod1.mastery.progress + 1
				self.esCanProgress = false
				self.network:sendToServer("sv_saveESMastery")
				for pos, val in pairs(self.playerData.kills) do
					self.playerData.kills[pos] = 0
				end
			end
		elseif self.currentWeaponMod == mod_turret and (not self.usingMod or self.overheated) then
			self.esCanProgress = true
			for pos, val in pairs(self.playerData.kills) do
				self.playerData.kills[pos] = 0
			end
		end
	end

	--mod_shield
	if self.currentWeaponMod == mod_shield and self.energyShieldActive and self.canUseEnergyShield then
		self.energyShieldActiveCD = self.energyShieldActiveCD - dt
		if self.energyShieldActiveCD <= 0 then
			self.canUseEnergyShield = false
			self.energyShieldActive = false
			self.playerData.isInvincible = false

			if self.playerData.damage >= 500 then
				self.shield.launch = true
				sm.audio.play( "Retrofmblip" )
			end
		end
	end

	if self.energyShieldActiveCD < 5 and not self.energyShieldActive then
		self.energyShieldActiveCD = self.energyShieldActiveCD + increase/3
		if self.energyShieldActiveCD >= 5 then
			self.energyShieldActiveCD = 5
			self.canUseEnergyShield = true
		end
	end

	if self.currentWeaponMod == mod_shield then
		self.tool:setMovementSlowDown( self.energyShieldActive )
	elseif self.usingMod and (not self.trMobility or self.currentWeaponMod == "poor") then
		self.tool:setMovementSlowDown( self.usingMod )
	else
		self.tool:setMovementSlowDown( false )
	end
end

function PotatoGatling:sv_saveESMastery()
	if self.data.mod1.mastery.progress >= self.data.mod1.mastery.max then
		sm.event.sendToPlayer( self.player, "sv_displayMsg", "#ff9d00"..self.data.mod1.mastery.name.." #ffffffunlocked!" )
		self.data.mod1.mastery.owned = true
	end

	sm.event.sendToPlayer(self.player, "sv_save")
end

function PotatoGatling.client_onReload( self )
	if self.data.mod1.owned and self.data.mod2.owned then
		self.modSwitchCount = self.modSwitchCount + 1
		if self.modSwitchCount % 2 == 0 then
			self.currentWeaponMod = mod_turret
		else
			self.currentWeaponMod = mod_shield
		end
		self.afterModCDCount = 0
		self.afterModCD = true
		sm.gui.displayAlertText("Current weapon mod: #ff9d00" .. self.currentWeaponMod, 2.5)
		sm.audio.play("PaintTool - ColorPick")
	elseif self.data.mod1.owned or self.data.mod2.owned or self.currentWeaponMod == "poor" then
		sm.audio.play("Button off")
	end

	return true
end

function PotatoGatling:sv_saveCurrentWpnData( data )
	sm.event.sendToPlayer( self.player, "sv_saveWPData", data )
end
--SE

function PotatoGatling.client_onUpdate( self, dt )
	--SE
	self.playerChar = self.player:getCharacter()
	self.lookDir = self.playerChar:getDirection()
	self.playerPos = self.playerChar:getWorldPosition()

	local increase = dt * self.spdMult
	local fpsAdjust = dt * 50

	local minColor = sm.color.new( 0.0, 0.0, 0.25, 0.1 )
	local maxColor = sm.color.new( 0.0, 0.3, 0.75, 1 ) --0.6 for Alpha
	self.shield.effect:setParameter( "minColor", minColor )
	self.shield.effect:setParameter( "maxColor", maxColor )

	if self.energyShieldActive then
		if self.tool:isEquipped() and self.currentWeaponMod == mod_shield and not self.afterModCD then
			--the vertical offset and the distance from the player look kinda dumb in TP, but this mod would mainly be played in FP
			--I dont think it really matters
			local offset = self.playerChar:isCrouching() and sm.vec3.zero() or sm.vec3.new(0,0,0.43)
			local newPos = self.playerChar:getTpBonePos( "jnt_spine2" ) + offset + self.lookDir * 0.55

			--[[local shieldHor = sm.vec3.new( self.shield.dir.x, self.shield.dir.y, 0 )
			local lookHor = sm.vec3.new( self.lookDir.x, self.lookDir.y, 0 )
			local angleHor = math.acos( (shieldHor:dot(lookHor)) / (shieldHor:length() * lookHor:length()) )
			print(angleHor)

			local shieldVer = sm.vec3.new( self.shield.dir.x, 0, self.shield.dir.z )
			local lookVer = sm.vec3.new( self.lookDir.x, 0, self.lookDir.z )
			local angleVer = math.acos( (shieldVer:dot(lookVer)) / (shieldVer:length() * lookVer:length()) )
			print(angleVer)

			if angleHor == angleHor then
				sm.vec3.rotate( self.shield.dir, math.rad(angleHor), sm.camera.getUp() )
			end

			if angleVer == angleVer then
				sm.vec3.rotate( self.shield.dir, math.rad(angleVer), sm.camera.getRight() )
			end

			self.shield.effect:setRotation( sm.vec3.getRotation( sm.vec3.new(0,-1,0), self.shield.dir ) )]]

			self.shield.pos = newPos
			self.shield.dir = self.lookDir
			if not self.shield.effect:isPlaying() then
				self.shield.effect:start()
			end
			self.shield.effect:setPosition( newPos )
			self.shield.effect:setRotation( sm.vec3.getRotation( sm.vec3.new(0,-1,0), self.lookDir ) )
		elseif not self.tool:isEquipped() or self.currentWeaponMod ~= mod_shield then
			self.shield.effect:stop()
		end
	else
		if self.shield.launch and self.shield.lifeTime < 3.5 then
			local newPos = self.shield.pos + sm.vec3.new(0.35,0.35,0.35) * self.shield.dir * fpsAdjust
            local newRot = sm.vec3.getRotation( sm.vec3.new(0,-1,0), self.shield.dir )
            self.shield.pos = newPos

			self.shield.lifeTime = self.shield.lifeTime + dt
            self.shield.effect:setPosition( newPos )
			self.shield.effect:setRotation( newRot )
			self.shield.trigger:setWorldPosition( newPos )

			--sm.camera.setCameraState( 2 )
			--sm.camera.setPosition( newPos )
			--sm.camera.setDirection( self.shield.dir )
		else
			self.shield.effect:stop()
			self.playerData.damage = 0
			self.shield.lifeTime = 0
			self.shield.launch = false
			self.shield.dir = sm.vec3.zero()
			self.shield.pos = sm.vec3.zero()

			--sm.camera.setCameraState( 1 )
		end
	end
	--SE

	-- First person animation	
	local isSprinting =  self.tool:isSprinting() 
	local isCrouching =  self.tool:isCrouching() 

	if self.tool:isLocal() then
		if self.equipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end

			if self.aiming and not isAnyOf( self.fpAnimations.currentAnimation, { "aimInto", "aimIdle", "aimShoot" } ) then
				swapFpAnimation( self.fpAnimations, "aimExit", "aimInto", 0.0 )
			end
			if not self.aiming and isAnyOf( self.fpAnimations.currentAnimation, { "aimInto", "aimIdle", "aimShoot" } ) then
				swapFpAnimation( self.fpAnimations, "aimInto", "aimExit", 0.0 )
			end
		end
		updateFpAnimations( self.fpAnimations, self.equipped, dt )
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end

	local effectPos, rot

	if self.tool:isLocal() then

		local zOffset = 0.6
		if self.tool:isCrouching() then
			zOffset = 0.29
		end

		local dir = sm.localPlayer.getDirection()
		local firePos = self.tool:getFpBonePos( "pejnt_barrel" )

		if not self.aiming then
			effectPos = firePos + dir * 0.2
		else
			effectPos = firePos + dir * 0.45
		end

		rot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), dir )

		self.shootEffectFP:setPosition( effectPos )
		self.shootEffectFP:setVelocity( self.tool:getMovementVelocity() )
		self.shootEffectFP:setRotation( rot )
	end
	local pos = self.tool:getTpBonePos( "pejnt_barrel" )
	local dir = self.tool:getTpBoneDir( "pejnt_barrel" )

	effectPos = pos + dir * 0.2

	rot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), dir )

	self.shootEffect:setPosition( effectPos )
	self.shootEffect:setVelocity( self.tool:getMovementVelocity() )
	self.shootEffect:setRotation( rot )
	self.windupEffect:setPosition( effectPos )

	-- Timers
	self.fireCooldownTimer = math.max( self.fireCooldownTimer - increase, 0.0 )
	self.spreadCooldownTimer = math.max( self.spreadCooldownTimer - increase, 0.0 )
	self.sprintCooldownTimer = math.max( self.sprintCooldownTimer - increase, 0.0 )

	if self.tool:isLocal() then
		local dispersion = 0.0
		local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
		local recoilDispersion = 1.0 - ( math.max( fireMode.minDispersionCrouching, fireMode.minDispersionStanding ) + fireMode.maxMovementDispersion )

		if isCrouching then
			dispersion = fireMode.minDispersionCrouching
		else
			dispersion = fireMode.minDispersionStanding
		end

		if self.tool:getRelativeMoveDirection():length() > 0 then
			dispersion = dispersion + fireMode.maxMovementDispersion * self.tool:getMovementSpeedFraction()
		end

		if not self.tool:isOnGround() then
			dispersion = dispersion * fireMode.jumpDispersionMultiplier
		end

		self.movementDispersion = dispersion

		self.spreadCooldownTimer = clamp( self.spreadCooldownTimer, 0.0, fireMode.spreadCooldown )
		local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp( self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0 ) or 0.0

		self.tool:setDispersionFraction( clamp( self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0 ) )

		if self.aiming then
			if self.tool:isInFirstPersonView() then
				self.tool:setCrossHairAlpha( 0.0 )
			else
				self.tool:setCrossHairAlpha( 1.0 )
			end
			self.tool:setInteractionTextSuppressed( true )
		else
			self.tool:setCrossHairAlpha( 1.0 )
			self.tool:setInteractionTextSuppressed( false )
		end
	end

	-- Sprint block
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0 or self.currentWeaponMod == mod_shield and self.energyShieldActive
	self.tool:setBlockSprint( blockSprint )

	local playerDir = self.tool:getDirection()
	local angle = math.asin( playerDir:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight 

	local totalWeight = 0.0
	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if ( name == "shoot" or name == "aimShoot" ) then
					setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 10.0 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end 
			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do
		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end

	-- Third Person joint lock
	local relativeMoveDirection = self.tool:getRelativeMoveDirection()
	if ( ( ( isAnyOf( self.tpAnimations.currentAnimation, { "aimInto", "aim", "shoot" } ) and ( relativeMoveDirection:length() > 0 or isCrouching) ) or ( self.aiming and ( relativeMoveDirection:length() > 0 or isCrouching) ) ) and not isSprinting ) then
		self.jointWeight = math.min( self.jointWeight + ( 10.0 * dt ), 1.0 )
	else
		self.jointWeight = math.max( self.jointWeight - ( 6.0 * dt ), 0.0 )
	end

	if ( not isSprinting ) then
		self.spineWeight = math.min( self.spineWeight + ( 10.0 * dt ), 1.0 )
	else
		self.spineWeight = math.max( self.spineWeight - ( 10.0 * dt ), 0.0 )
	end

	local finalAngle = ( 0.5 + angle * 0.5 )
	self.tool:updateAnimation( "spudgun_spine_bend", finalAngle, self.spineWeight )

	local totalOffsetZ = lerp( -22.0, -26.0, crouchWeight )
	local totalOffsetY = lerp( 6.0, 12.0, crouchWeight )
	local crouchTotalOffsetX = clamp( ( angle * 60.0 ) -15.0, -60.0, 40.0 )
	local normalTotalOffsetX = clamp( ( angle * 50.0 ), -45.0, 50.0 )
	local totalOffsetX = lerp( normalTotalOffsetX, crouchTotalOffsetX , crouchWeight )

	local finalJointWeight = ( self.jointWeight )

	self.tool:updateJoint( "jnt_hips", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), 0.35 * finalJointWeight * ( normalWeight ) )

	local crouchSpineWeight = ( 0.35 / 3 ) * crouchWeight

	self.tool:updateJoint( "jnt_spine1", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.10 + crouchSpineWeight )  * finalJointWeight )
	self.tool:updateJoint( "jnt_spine2", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.10 + crouchSpineWeight ) * finalJointWeight )
	self.tool:updateJoint( "jnt_spine3", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.45 + crouchSpineWeight ) * finalJointWeight )
	self.tool:updateJoint( "jnt_head", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), 0.3 * finalJointWeight )

	-- Camera update
	local bobbing = 1
	if self.aiming then
		local blend = 1 - math.pow( 1 - 1 / self.aimBlendSpeed, dt * 60 )
		self.aimWeight = sm.util.lerp( self.aimWeight, 1.0, blend )
		bobbing = 0.12
	else
		local blend = 1 - math.pow( 1 - 1 / self.aimBlendSpeed, dt * 60 )
		self.aimWeight = sm.util.lerp( self.aimWeight, 0.0, blend )
		bobbing = 1
	end

	self.tool:updateCamera( 2.8, 30.0, sm.vec3.new( 0.65, 0.0, 0.05 ), self.aimWeight )
	self.tool:updateFpCamera( 30.0, sm.vec3.new( 0.0, 0.0, 0.0 ), self.aimWeight, bobbing )
	
	self:cl_updateGatling( dt )
end

function PotatoGatling.client_onEquip( self, animate )
	--SE
	if self.currentWeaponMod ~= "poor" then
		sm.gui.displayAlertText("Current weapon mod: #ff9d00" .. self.currentWeaponMod, 2.5)
	end
	--SE

	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.windupEffect:start()
	self.wantEquipped = true
	self.aiming = false
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )
	self.jointWeight = 0.0

	currentRenderablesTp = {}
	currentRenderablesFp = {}

	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.tool:setTpRenderables( currentRenderablesTp )

	self:loadAnimations()

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )

	if self.tool:isLocal() then
		-- Sets PotatoGatling renderable, change this to change the mesh
		self.tool:setFpRenderables( currentRenderablesFp )
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function PotatoGatling.client_onUnequip( self, animate )
	--SE
	local data = {
		mod = "none",
		using = false,
		ammo = 0,
		recharge = 0
	}
	self.network:sendToServer( "sv_saveCurrentWpnData", data )
	--SE


	if animate then
		sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
	end

	--SE
	self.usingMod = false
	--SE
	self.windupEffect:stop()
	self.wantEquipped = false
	self.equipped = false
	setTpAnimation( self.tpAnimations, "putdown" )
	if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
		swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
	end
end

function PotatoGatling.sv_n_onAim( self, aiming )
	self.network:sendToClients( "cl_n_onAim", aiming )
end

function PotatoGatling.cl_n_onAim( self, aiming )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onAim( aiming )
	end
end

function PotatoGatling.onAim( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function PotatoGatling.sv_n_onShoot( self, dir ) 
	self.network:sendToClients( "cl_n_onShoot", dir )
end

function PotatoGatling.cl_n_onShoot( self, dir ) 
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onShoot( dir )
	end
end

function PotatoGatling.onShoot( self, dir ) 
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0
	self.tpAnimations.animations.aimShoot.time = 0

	setTpAnimation( self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0 )

	if self.tool:isInFirstPersonView() then
		if self.afterModCD or self.currentWeaponMod == mod_turret and self.usingMod and not self.canFireMobileTurret or self.overheated and self.usingMod and self.currentWeaponMod == mod_turret then
			sm.audio.play( "PotatoRifle - NoAmmo" )
		else
			self.shootEffectFP:start()
		end
	else
		if self.afterModCD or self.currentWeaponMod == mod_turret and self.usingMod and not self.canFireMobileTurret or self.overheated and self.usingMod and self.currentWeaponMod == mod_turret then
			sm.audio.play( "PotatoRifle - NoAmmo" )
		else
			self.shootEffect:start()
		end
	end
end

function PotatoGatling.calculateFirePosition( self )
	local crouching = self.tool:isCrouching()
	local firstPerson = self.tool:isInFirstPersonView()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin( dir.z )		
	local right = sm.localPlayer.getRight()

	local fireOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

	if crouching then
		fireOffset.z = 0.15
	else
		fireOffset.z = 0.45
	end

	if firstPerson then
		if not self.aiming then
			fireOffset = fireOffset + right * 0.05
		end
	else
		fireOffset = fireOffset + right * 0.25		
		fireOffset = fireOffset:rotate( math.rad( pitch ), right )
	end
	local firePosition = GetOwnerPosition( self.tool ) + fireOffset
	return firePosition
end

function PotatoGatling.calculateTpMuzzlePos( self )
	local crouching = self.tool:isCrouching()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin( dir.z )		
	local right = sm.localPlayer.getRight()
	local up = right:cross(dir)

	local fakeOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

	--General offset
	fakeOffset = fakeOffset + right * 0.25
	fakeOffset = fakeOffset + dir * 0.5
	fakeOffset = fakeOffset + up * 0.25

	--Action offset
	local pitchFraction = pitch / ( math.pi * 0.5 )
	if crouching then
		fakeOffset = fakeOffset + dir * 0.2
		fakeOffset = fakeOffset + up * 0.1
		fakeOffset = fakeOffset - right * 0.05

		if pitchFraction > 0.0 then
			fakeOffset = fakeOffset - up * 0.2 * pitchFraction
		else
			fakeOffset = fakeOffset + up * 0.1 * math.abs( pitchFraction )
		end
	else
		fakeOffset = fakeOffset + up * 0.1 *  math.abs( pitchFraction )		
	end

	local fakePosition = fakeOffset + GetOwnerPosition( self.tool )
	return fakePosition
end

function PotatoGatling.calculateFpMuzzlePos( self )
	local fovScale = ( sm.camera.getFov() - 45 ) / 45

	local up = sm.localPlayer.getUp()
	local dir = sm.localPlayer.getDirection()
	local right = sm.localPlayer.getRight()

	local muzzlePos45 = sm.vec3.new( 0.0, 0.0, 0.0 )
	local muzzlePos90 = sm.vec3.new( 0.0, 0.0, 0.0 )

	if self.aiming then
		muzzlePos45 = muzzlePos45 - up * 0.2
		muzzlePos45 = muzzlePos45 + dir * 0.5

		muzzlePos90 = muzzlePos90 - up * 0.5
		muzzlePos90 = muzzlePos90 - dir * 0.6
	else
		muzzlePos45 = muzzlePos45 - up * 0.15
		muzzlePos45 = muzzlePos45 + right * 0.2
		muzzlePos45 = muzzlePos45 + dir * 1.25

		muzzlePos90 = muzzlePos90 - up * 0.15
		muzzlePos90 = muzzlePos90 + right * 0.2
		muzzlePos90 = muzzlePos90 + dir * 0.25
	end

	return self.tool:getFpBonePos( "pejnt_barrel" ) + sm.vec3.lerp( muzzlePos45, muzzlePos90, fovScale )
end

function PotatoGatling.cl_updateGatling( self, dt )
	local increase = dt * self.spdMult

	self.gatlingWeight = self.gatlingActive and ( self.gatlingWeight + self.gatlingBlendSpeedIn * increase ) or ( self.gatlingWeight - self.gatlingBlendSpeedOut * increase )
	self.gatlingWeight = math.min( math.max( self.gatlingWeight, 0.0 ), 1.0 )
	local frac
	frac, self.gatlingTurnFraction = math.modf( self.gatlingTurnFraction + self.gatlingTurnSpeed * self.gatlingWeight * increase )

	self.windupEffect:setParameter( "velocity", self.gatlingWeight )
	if self.equipped and not self.windupEffect:isPlaying() then
		self.windupEffect:start()
	elseif not self.equipped and self.windupEffect:isPlaying() then
		self.windupEffect:stop()
	end

	-- Update gatling animation
	if self.tool:isLocal() then
		self.tool:updateFpAnimation( "spudgun_spinner_shoot_fp", self.gatlingTurnFraction, 1.0/self.spdMult, true )
	end
	self.tool:updateAnimation( "spudgun_spinner_shoot_tp", self.gatlingTurnFraction, 1.0/self.spdMult )

	if self.fireCooldownTimer <= 0.0 and self.gatlingWeight >= 1.0/self.spdMult and self.gatlingActive then
		self:cl_fire()
	end
end

function PotatoGatling.cl_fire( self )
	if self.tool:getOwner().character == nil then
		return
	end
	if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), obj_plantables_potato, 1 ) then

		local firstPerson = self.tool:isInFirstPersonView()

		local dir = sm.localPlayer.getDirection()

		firePos = self:calculateFirePosition()
		local fakePosition = self:calculateTpMuzzlePos()
		local fakePositionSelf = fakePosition
		if firstPerson then
			fakePositionSelf = self:calculateFpMuzzlePos()
		end

		-- Aim assist
		if not firstPerson then
			local raycastPos = sm.camera.getPosition() + sm.camera.getDirection() * sm.camera.getDirection():dot( GetOwnerPosition( self.tool ) - sm.camera.getPosition() )
			local hit, result = sm.localPlayer.getRaycast( 250, raycastPos, sm.camera.getDirection() )
			if hit then 
				local norDir = sm.vec3.normalize( result.pointWorld - firePos )
				local dirDot = norDir:dot( dir )

				if dirDot > 0.96592583 then -- max 15 degrees off
					dir = norDir
				else
					local radsOff = math.asin( dirDot )
					dir = sm.vec3.lerp( dir, norDir, math.tan( radsOff ) / 3.7320508 ) -- if more than 15, make it 15
				end
			end
		end

		dir = dir:rotate( math.rad( 0.955 ), sm.camera.getRight() ) -- 50 m sight calibration

		-- Spread
		local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
		local recoilDispersion = 1.0 - ( math.max(fireMode.minDispersionCrouching, fireMode.minDispersionStanding ) + fireMode.maxMovementDispersion )

		local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp( self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0 ) or 0.0
		spreadFactor = clamp( self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0 )
		local spreadDeg =  fireMode.spreadMinAngle + ( fireMode.spreadMaxAngle - fireMode.spreadMinAngle ) * spreadFactor

		dir = sm.noise.gunSpread( dir, spreadDeg )

		--SE
		local owner = self.tool:getOwner()
		if owner and not self.afterModCD and not self.usingMod or owner and not self.afterModCD and self.currentWeaponMod == mod_shield and self.usingMod or owner and self.currentWeaponMod == "poor" then
			sm.projectile.projectileAttack( "potato", self.Damage, firePos, dir * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf )
		elseif owner and not self.afterModCD and self.currentWeaponMod == mod_turret and self.usingMod and self.canFireMobileTurret and not self.overheated then
			if not self.data.mod1.mastery.owned then
				self.mobileTurretOverheatCD = self.mobileTurretOverheatCD - 0.5
			end

			for i = 0, 3 do
				sm.projectile.projectileAttack( "potato", self.Damage, firePos, (sm.noise.gunSpread( dir, spreadDeg )) * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf )
			end
		end
		--SE

		-- Timers
		self.fireCooldownTimer = fireMode.fireCooldown
		self.spreadCooldownTimer = math.min( self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown )
		self.sprintCooldownTimer = self.sprintCooldown

		-- Send TP shoot over network and dircly to self
		self:onShoot( dir )
		self.network:sendToServer( "sv_n_onShoot", dir )

		-- Play FP shoot animation
		setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
	else
		local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
		self.fireCooldownTimer = fireMode.fireCooldown
		sm.audio.play( "PotatoRifle - NoAmmo" )
	end
end

function PotatoGatling.cl_onSecondaryUse( self, state )
	if state == sm.tool.interactState.start and not self.usingMod --[[self.aiming]] then
		--SE
		self.usingMod = true

		if self.currentWeaponMod == mod_turret or self.currentWeaponMod == "poor" then
			self.tpAnimations.animations.idle.time = 0
			self:onAim( self.usingMod )
			if not self.trMobility or self.currentWeaponMod == "poor" then
				self.tool:setMovementSlowDown( self.usingMod )
			end
			self.network:sendToServer( "sv_n_onAim", self.usingMod )
		end
		--SE

		--[[self.aiming = true
		self.tpAnimations.animations.idle.time = 0

		self:onAim( self.aiming )
		self.tool:setMovementSlowDown( self.aiming )
		self.network:sendToServer( "sv_n_onAim", self.aiming )]]
	end

	if self.usingMod --[[self.aiming]] and (state == sm.tool.interactState.stop or state == sm.tool.interactState.null) then
		--SE
		self.usingMod = false

		if self.currentWeaponMod == mod_turret or self.currentWeaponMod == "poor" then
			self.tpAnimations.animations.idle.time = 0
			self:onAim( self.usingMod )
			if not self.trMobility or self.currentWeaponMod == "poor" then
				self.tool:setMovementSlowDown( self.usingMod )
			end
			self.network:sendToServer( "sv_n_onAim", self.usingMod )
		end
		--SE

		--[[self.aiming = false
		self.tpAnimations.animations.idle.time = 0

		self:onAim( self.aiming )
		self.tool:setMovementSlowDown( self.aiming )
		self.network:sendToServer( "sv_n_onAim", self.aiming )]]
	end

	--SE
	if self.currentWeaponMod == mod_turret then
		self.mobileTurretActivateCD = 0
	elseif self.currentWeaponMod == mod_shield and self.canUseEnergyShield then
		self.energyShieldActive = true
		self.shield.dir = self.lookDir
		self.playerData.isInvincible = true
	end
	--SE
end

function PotatoGatling.client_onEquippedUpdate( self, primaryState, secondaryState )
	--SE
	local data = {
		mod = self.currentWeaponMod,	
		using = self.currentWeaponMod == mod_shield and self.energyShieldActive or self.currentWeaponMod == mod_turret and self.usingMod or self.currentWeaponMod == "poor" and self.usingMod,
		ammo = 0,
		recharge = 0
	}
	self.network:sendToServer( "sv_saveCurrentWpnData", data )

	if self.afterModCD then
		sm.gui.setProgressFraction(self.afterModCDCount/1)
	end

	if self.currentWeaponMod == mod_turret and self.usingMod and not self.canFireMobileTurret then
		sm.gui.setProgressFraction(self.mobileTurretActivateCD/self.mobileTurretActivateMax)
	elseif self.mobileTurretOverheatCD < 15 and self.currentWeaponMod == mod_turret then
		sm.gui.setProgressFraction(self.mobileTurretOverheatCD*2/30)
	elseif self.currentWeaponMod == mod_shield and self.energyShieldActiveCD < 5 then
		sm.gui.setProgressFraction(self.energyShieldActiveCD/5)
	end

	self.isFiring = (primaryState == sm.tool.interactState.start or primaryState == sm.tool.interactState.hold) and true or false
	--SE

	if primaryState == sm.tool.interactState.start or primaryState == sm.tool.interactState.hold then
		self.gatlingActive = true
	else
		self.gatlingActive = false
	end

	if secondaryState ~= self.prevSecondaryState then
		self:cl_onSecondaryUse( secondaryState )
		self.prevSecondaryState = secondaryState
	end

	return true, true
end
