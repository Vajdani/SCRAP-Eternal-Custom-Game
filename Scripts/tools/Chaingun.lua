dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"


Chaingun = class()
Chaingun.mod1 = "Mobile Turret"
Chaingun.mod2 = "Energy Shield"
Chaingun.renderables = {
	poor = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_spinner/char_spudgun_barrel_spinner.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_spinner/char_spudgun_sight_spinner.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	["Mobile Turret"] = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_spinner/char_spudgun_barrel_spinner.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_spinner/char_spudgun_sight_spinner.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	["Energy Shield"] = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_spinner/char_spudgun_barrel_spinner.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_spinner/char_spudgun_sight_spinner.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	}
}
Chaingun.renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend", "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"}
Chaingun.renderablesFp = {"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"}
Chaingun.firePosOffsets = {
	function() return sm.localPlayer.getRight() end,
	function() return sm.localPlayer.getRight() * 0.5 - sm.vec3.new(0,0,0.5) end,
	function() return -sm.localPlayer.getRight() * 0.5 - sm.vec3.new(0,0,0.5) end,
	function() return -sm.localPlayer.getRight() end
}
Chaingun.baseDamage = 26

for k, v in pairs(Chaingun.renderables) do
	sm.tool.preloadRenderables( v )
end
sm.tool.preloadRenderables( Chaingun.renderablesTp )
sm.tool.preloadRenderables( Chaingun.renderablesFp )

function Chaingun:sv_shootShield( args )
	args.spawnTick = sm.game.getServerTick()
	sm.scriptableObject.createScriptableObject(
		proj_shield_sob,
		args,
		args.owner:getCharacter():getWorld()
	)
end

function Chaingun:sv_startShield()
	self.network:sendToClients("cl_startShield")
end

function Chaingun:sv_stopShield()
	self.network:sendToClients("cl_stopShield")
end



function Chaingun:cl_startShield()
	self.cl.shield.effect:start()
	self.cl.shield.active = true
end

function Chaingun:cl_stopShield()
	self.cl.shield.effect:stop()
	self.cl.shield.active = false
end

function Chaingun.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunSpinner - SpinnerMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunSpinner - FPSpinnerMuzzel" )
	self.windupEffect = sm.effect.createEffect( "SpudgunSpinner - Windup" )

	self.cl = {}
	self.cl.baseWeapon = BaseWeapon()
	self.cl.baseWeapon.cl_onCreate( self, "chaingun" )

	self.cl.shield = {
		active = false,
		effect = sm.effect.createEffect("Energy Shield") 
	}

	local minColor = sm.color.new( 0.0, 0.0, 0.25, 0.1 )
	local maxColor = sm.color.new( 0.0, 0.3, 0.75, 0.6 ) --0.6 for Alpha
	self.cl.shield.effect:setParameter( "minColor", minColor )
	self.cl.shield.effect:setParameter( "maxColor", maxColor )

	if not self.tool:isLocal() then return end
	self.cl.playerData = self.cl.ownerData.data.playerData

	self.cl.spdMult = 1

	--self.mod1
	self.cl.mobileTurretActivateCD = 1.5
	self.cl.mobileTurretActivateMax = 1.5
	self.cl.canFireMobileTurret = false
	self.cl.mobileTurretOverheatCD = 15
	self.cl.overheated = false
	self.cl.trMobility = false

	--self.mod2
	self.cl.shield.timer = Timer()
	self.cl.shield.timer:start( 5*40 )
	self.cl.shield.canUse = true
	self.cl.shield.canProgress = true
	self.cl.shield.masteryKills = 0
end

function Chaingun.client_onRefresh( self )
	self:loadAnimations()
end

function Chaingun.loadAnimations( self )

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

function Chaingun:client_onFixedUpdate( dt )
	if not self.tool:isLocal() then return end

	self.cl.baseWeapon.cl_onFixed( self )

	--upgrades
	self.cl.mobileTurretActivateMax = self.cl.weaponData.mod1.up1.owned and 0.75 or 1.5
	self.cl.trMobility = self.cl.weaponData.mod1.up2.owned and true or false

	--powerup
	local speedMult = self.cl.powerups.speedMultiplier.current
	local increase = dt * speedMult

	--self.mod1 activate
	if self.cl.currentWeaponMod == self.mod1 and self.cl.usingMod and not self.cl.modSwitch.active then
		if self.cl.mobileTurretActivateCD < self.cl.mobileTurretActivateMax then
			self.cl.mobileTurretActivateCD = self.cl.mobileTurretActivateCD + increase*2
		end

		if self.cl.mobileTurretActivateCD >= self.cl.mobileTurretActivateMax then
			self.cl.mobileTurretActivateCD = self.cl.mobileTurretActivateMax
			self.cl.canFireMobileTurret = true
		end
	else
		self.cl.canFireMobileTurret = false
	end

	--self.mod1 overheat
	if self.cl.mobileTurretOverheatCD < 15 and self.cl.usingMod and self.fireCooldownTimer <= 0.0 or self.cl.mobileTurretOverheatCD < 15 and not self.cl.usingMod or self.cl.mobileTurretOverheatCD < 15 and self.cl.usingMod and self.cl.overheated then
		self.cl.mobileTurretOverheatCD = self.cl.mobileTurretOverheatCD + increase
	end

	if self.cl.mobileTurretOverheatCD >= 15 then
		self.cl.mobileTurretOverheatCD = 15
		self.cl.overheated = false
	end

	if self.cl.mobileTurretOverheatCD <= 0 then
		self.cl.overheated = true
	end

	local kills = 0
	for pos, val in pairs(self.cl.playerData.kills) do
		kills = kills + val
	end
	self.cl.shield.masteryKills = kills

	if self.cl.weaponData.mod1.up1.owned and self.cl.weaponData.mod1.up2.owned and not self.cl.weaponData.mod1.mastery.owned then
		if self.cl.shield.canProgress and self.cl.currentWeaponMod == self.mod1 and self.cl.usingMod and not self.cl.overheated then

			if self.cl.shield.masteryKills >= 5 then
				self.cl.weaponData.mod1.mastery.progress = self.cl.weaponData.mod1.mastery.progress + 1
				self.cl.shield.canProgress = false
				self.network:sendToServer("sv_saveESMastery")
				for pos, val in pairs(self.cl.playerData.kills) do
					self.cl.playerData.kills[pos] = 0
				end
			end
		elseif self.cl.currentWeaponMod == self.mod1 and (not self.cl.usingMod or self.cl.overheated) then
			self.cl.shield.canProgress = true
			for pos, val in pairs(self.cl.playerData.kills) do
				self.cl.playerData.kills[pos] = 0
			end
		end
	end

	--self.mod2
	if self.cl.currentWeaponMod == self.mod2 and self.cl.shield.active and self.cl.shield.canUse then
		self.cl.shield.timer:tick()
		if self.cl.shield.timer:done() then
			self.cl.shield.canUse = false
			self.cl.shield.active = false
			self.cl.playerData.isInvincible = false

			--if self.cl.playerData.damage >= 500 then
				self.network:sendToServer("sv_shootShield",
					{
						pos = self:calculateFirePosition(),
						dir = sm.localPlayer.getDirection(),
						owner = self.cl.owner,
						rot = sm.camera.getRotation()
					}
				)
				
				sm.audio.play( "Retrofmblip" )
			--end

			self.network:sendToServer("sv_stopShield")
		end
	end

	if self.cl.shield.timer.count > 0 and not self.cl.shield.active then
		for i = 1, speedMult do
			self.cl.shield.timer.count = self.cl.shield.timer.count - 1
		end
		
		if self.cl.shield.timer.count <= 0 then
			self.cl.shield.timer:reset()
			self.cl.shield.canUse = true
		end
	end

	if self.cl.currentWeaponMod == self.mod2 then
		self.tool:setMovementSlowDown( self.cl.shield.active )
	elseif self.cl.usingMod and (not self.cl.trMobility or self.cl.currentWeaponMod == "poor") then
		self.tool:setMovementSlowDown( self.cl.usingMod )
	else
		self.tool:setMovementSlowDown( false )
	end
end

function Chaingun:sv_saveESMastery()
	if self.cl.weaponData.mod1.mastery.progress >= self.cl.weaponData.mod1.mastery.max then
		sm.event.sendToPlayer( self.cl.owner, "sv_displayMsg", "#ff9d00"..self.cl.weaponData.mod1.mastery.name.." #ffffffunlocked!" )
		self.cl.weaponData.mod1.mastery.owned = true
	end

	sm.event.sendToPlayer(self.cl.owner, "sv_save")
end

function Chaingun:client_onReload()
	self.cl.baseWeapon.onModSwitch( self )
	self.cl.shield.effect:stop()
	self.cl.shield.active = false

	return true
end



function Chaingun.client_onUpdate( self, dt )
	dt = dt * self.cl.powerups.speedMultiplier.current

	if self.cl.shield.active and self.tool:isEquipped() and self.cl.currentWeaponMod == self.mod2 then
		local char = self.cl.owner.character
        local lookDir = char:getDirection()
        local offset = char:isCrouching() and sm.vec3.zero() or sm.vec3.new(0,0,0.43)
        local newPos = char:getTpBonePos( "jnt_spine2" ) + offset + lookDir * 0.55

        self.cl.shield.effect:setPosition( newPos )
        self.cl.shield.effect:setRotation( sm.quat.fromEuler( lookDir * 90 ) )
	end
	

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
	self.fireCooldownTimer = math.max( self.fireCooldownTimer - dt, 0.0 )
	self.spreadCooldownTimer = math.max( self.spreadCooldownTimer - dt, 0.0 )
	self.sprintCooldownTimer = math.max( self.sprintCooldownTimer - dt, 0.0 )

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
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0 or self.cl.currentWeaponMod == self.mod2 and self.cl.shield.active
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

function Chaingun.client_onEquip( self, animate )
	
	if self.cl.currentWeaponMod ~= "poor" then
		sm.gui.displayAlertText("Current weapon mod: #ff9d00" .. self.cl.currentWeaponMod, 2.5)
	end
	
	if self.cl.shield.active and self.cl.currentWeaponMod == self.mod2 then
		self.cl.shield.effect:start()
	end

	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.windupEffect:start()
	self.wantEquipped = true
	self.aiming = false
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )
	self.jointWeight = 0.0

	self:updateRenderables()

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.tool:isLocal() then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function Chaingun.client_onUnequip( self, animate )
	--[[local data = {
		mod = "none",
		using = false,
		ammo = 0,
		recharge = 0
	}
	self.network:sendToServer( "sv_saveCurrentWpnData", data )]]
	
	if animate then
		sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
	end

	
	self.cl.usingMod = false
	self.cl.shield.effect:stop()
	
	self.windupEffect:stop()
	self.wantEquipped = false
	self.equipped = false
	setTpAnimation( self.tpAnimations, "putdown" )
	if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
		swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
	end
end

function Chaingun.sv_n_onAim( self, aiming )
	self.network:sendToClients( "cl_n_onAim", aiming )
end

function Chaingun.cl_n_onAim( self, aiming )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onAim( aiming )
	end
end

function Chaingun.onAim( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function Chaingun.sv_n_onShoot( self, dir ) 
	self.network:sendToClients( "cl_n_onShoot", dir )
end

function Chaingun.cl_n_onShoot( self, dir ) 
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onShoot( dir )
	end
end

function Chaingun.onShoot( self, dir ) 
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0
	self.tpAnimations.animations.aimShoot.time = 0

	setTpAnimation( self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0 )

	if self.tool:isInFirstPersonView() then
		if self.cl.modSwitch.active or self.cl.currentWeaponMod == self.mod1 and self.cl.usingMod and not self.cl.canFireMobileTurret or self.cl.overheated and self.cl.usingMod and self.cl.currentWeaponMod == self.mod1 then
			sm.audio.play( "PotatoRifle - NoAmmo" )
		else
			self.shootEffectFP:start()
		end
	else
		if self.cl.modSwitch.active or self.cl.currentWeaponMod == self.mod1 and self.cl.usingMod and not self.cl.canFireMobileTurret or self.cl.overheated and self.cl.usingMod and self.cl.currentWeaponMod == self.mod1 then
			sm.audio.play( "PotatoRifle - NoAmmo" )
		else
			self.shootEffect:start()
		end
	end
end

function Chaingun.cl_updateGatling( self, dt )
	local divide = 1/self.cl.spdMult

	self.gatlingWeight = self.gatlingActive and ( self.gatlingWeight + self.gatlingBlendSpeedIn * dt ) or ( self.gatlingWeight - self.gatlingBlendSpeedOut * dt )
	self.gatlingWeight = math.min( math.max( self.gatlingWeight, 0.0 ), 1.0 )
	local frac
	frac, self.gatlingTurnFraction = math.modf( self.gatlingTurnFraction + self.gatlingTurnSpeed * self.gatlingWeight * dt )

	self.windupEffect:setParameter( "velocity", self.gatlingWeight )
	if self.equipped and not self.windupEffect:isPlaying() then
		self.windupEffect:start()
	elseif not self.equipped and self.windupEffect:isPlaying() then
		self.windupEffect:stop()
	end

	-- Update gatling animation
	if self.tool:isLocal() then
		self.tool:updateFpAnimation( "spudgun_spinner_shoot_fp", self.gatlingTurnFraction, divide, true )
	end
	self.tool:updateAnimation( "spudgun_spinner_shoot_tp", self.gatlingTurnFraction, divide )

	if self.fireCooldownTimer <= 0.0 and self.gatlingWeight >= divide and self.gatlingActive then
		self:cl_fire()
	end
end

function Chaingun.cl_fire( self )
	if self.tool:getOwner().character == nil then
		return
	end
	if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), obj_plantables_potato, 1 ) then

		local firstPerson = self.tool:isInFirstPersonView()

		local dir = sm.localPlayer.getDirection()

		local firePos = self:calculateFirePosition()
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

		
		local owner = self.tool:getOwner()
		if owner and not self.cl.modSwitch.active then
			if self.cl.currentWeaponMod ~= self.mod1 or not self.cl.usingMod then
				sm.projectile.projectileAttack(
					projectile_potato,
					self.baseDamage * self.cl.powerups.damageMultiplier.current,
					firePos,
					dir * fireMode.fireVelocity,
					owner,
					fakePosition,
					fakePositionSelf
				)
			elseif self.cl.canFireMobileTurret and not self.cl.overheated then
				if not self.cl.weaponData.mod1.mastery.owned then
					self.cl.mobileTurretOverheatCD = self.cl.mobileTurretOverheatCD - 0.5
				end

				for i = 1, 4 do
					dir = sm.noise.gunSpread( dir, spreadDeg )
					sm.projectile.projectileAttack(
						projectile_potato,
						self.baseDamage * self.cl.powerups.damageMultiplier.current,
						firePos + self.firePosOffsets[i](),
						dir * fireMode.fireVelocity,
						owner,
						fakePosition,
						fakePositionSelf
					)					
				end
			end
		end
		

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

function Chaingun.cl_onSecondaryUse( self, state )
	if self.cl.currentWeaponMod ~= self.mod2 then
		local prevAim = self.aiming
		self.aiming = state == sm.tool.interactState.start or state == sm.tool.interactState.hold

		if prevAim ~= self.aiming then
			self.tpAnimations.animations.idle.time = 0

			self:onAim( self.aiming )
			if not self.cl.trMobility or self.cl.currentWeaponMod == "poor" then
				self.tool:setMovementSlowDown( self.aiming )
			end
			self.network:sendToServer( "sv_n_onAim", self.aiming )
		end
	end
	
	if state ~= sm.tool.interactState.start or self.cl.shield.active then return end

	if self.cl.currentWeaponMod == self.mod1 then
		self.cl.mobileTurretActivateCD = 0
	elseif self.cl.currentWeaponMod == self.mod2 and self.cl.shield.canUse then
		self.network:sendToServer("sv_startShield")
		self.cl.playerData.isInvincible = true
	end
end

function Chaingun.client_onEquippedUpdate( self, primaryState, secondaryState )
	self.cl.baseWeapon.onEquipped( self, primaryState, secondaryState )
	
	--[[local data = {
		mod = self.cl.currentWeaponMod,	
		using = self.cl.currentWeaponMod == self.mod2 and self.cl.shield.active or self.cl.currentWeaponMod == self.mod1 and self.cl.usingMod or self.cl.currentWeaponMod == "poor" and self.cl.usingMod,
		ammo = 0,
		recharge = 0
	}
	self.network:sendToServer( "sv_saveCurrentWpnData", data )]]

	if self.cl.modSwitch.active then
		sm.gui.setProgressFraction(self.cl.modSwitch.timer.count/self.cl.modSwitch.timer.ticks)
	end

	if self.cl.currentWeaponMod == self.mod1 and self.cl.usingMod and not self.cl.canFireMobileTurret then
		sm.gui.setProgressFraction(self.cl.mobileTurretActivateCD/self.cl.mobileTurretActivateMax)
	elseif self.cl.mobileTurretOverheatCD < 15 and self.cl.currentWeaponMod == self.mod1 then
		sm.gui.setProgressFraction(self.cl.mobileTurretOverheatCD*2/30)
	elseif self.cl.currentWeaponMod == self.mod2 and self.cl.shield.timer.count > 0 then
		sm.gui.setProgressFraction(self.cl.shield.timer.count/self.cl.shield.timer.ticks)
	end

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
