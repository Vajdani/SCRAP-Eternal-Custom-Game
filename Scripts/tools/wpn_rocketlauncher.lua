dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

--local Damage = 28

RLauncher = class()

local mod_lock = "Lock-On Burst"
local mod_detonate = "Remote Detonate"
local turnSpeed = 5
local rocketVel = sm.vec3.new(0.35,0.35,0.35)

local renderables = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_basic/char_spudgun_barrel_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
}

local renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend", "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"}
local renderablesFp = {"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function RLauncher:server_onCreate()
	self.sv = {}
	self.sv.detRockets = self.storage:load() or {}
	self.network:setClientData( self.sv.detRockets )
end

function RLauncher.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunBasic - BasicMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunBasic - FPBasicMuzzel" )

    --SE
	if not self.tool:isLocal() then return end
    --General stuff
	self.cl = {}

	self.cl.player = sm.localPlayer.getPlayer()

	self.cl.allData = self.cl.player:getClientPublicData().data
	self.cl.weaponData = self.cl.allData.weaponData.rocket

	self.cl.dmgMult = 1
	self.cl.spdMult = 1
	self.cl.usingMod = false

	--Mod switch
	if self.cl.weaponData.mod1.owned then
		self.cl.currentWeaponMod = mod_lock
	elseif self.cl.weaponData.mod2.owned then
		self.cl.currentWeaponMod = mod_detonate
	else
		self.cl.currentWeaponMod = "poor"
	end

	self.cl.modSwitchCount = 0
	self.cl.afterModCD = false
	self.cl.afterModCDCount = 1

	--mod_lock
	self.cl.loadedRockets = 0
	self.cl.loadedRocketsMax = 3
	self.cl.rocketLoadCount = 0
	self.cl.rocketLoadMax = 1
	self.cl.lockCD = false
	self.cl.lockCDCount = 0
	self.cl.lockCDMax = 1.5
	self.cl.fireRockets = false
	self.cl.fireRocketCount = 0
	self.cl.rocketTarget = nil
	self.cl.fireType = { count = 0, current = "Burst", types = { "Burst", "Blast" } }

	--mod_detonate
	self.cl.detRockets = {}
end

function RLauncher.client_onRefresh( self )
	self:loadAnimations()
end

function RLauncher.loadAnimations( self )

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
		fireCooldown = 1.25,
		spreadCooldown = 0,
		spreadIncrement = 0,
		spreadMinAngle = 0,
		spreadMaxAngle = 0,
		fireVelocity = 150.0,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.aimFireMode = {
		fireCooldown = 1.25,
		spreadCooldown = 0,
		spreadIncrement = 0,
		spreadMinAngle = 0,
		spreadMaxAngle = 0,
		fireVelocity =  150.0,

		minDispersionStanding = 0.01,
		minDispersionCrouching = 0.01,

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

end

--SE
function RLauncher:client_onFixedUpdate( dt )
	if not self.tool:isLocal() or self.cl.allData == nil or not self.tool:isEquipped() then return end

	local playerData = self.cl.allData.playerData
	self.cl.dmgMult = playerData.damageMultiplier > 1 and playerData.damageMultiplier / 2 or playerData.damageMultiplier
	self.cl.spdMult = playerData.speedMultiplier

	local lookDir = self.tool:getOwner().character:getDirection()

	--fuck off
	if self.fireCooldownTimer == nil then
		self.fireCooldownTimer = 0
	end

	if self.cl.currentWeaponMod == "poor" then
		if self.cl.weaponData.mod1.owned then
			self.cl.currentWeaponMod = mod_detonate
		elseif self.cl.weaponData.mod2.owned then
			self.cl.currentWeaponMod = mod_lock
		end

		--checks if youre still poor, and if you are, it returns so that it doesnt calculate all the shit below this
		if self.cl.currentWeaponMod == "poor" then
			return
		end
	end

	--upgrades
	self.cl.lockCDMax = self.cl.weaponData.mod2.up1.owned and 1 or 1.5
	self.cl.rocketLoadMax = self.cl.weaponData.mod2.up2.owned and 0.5 or 1
	--this will definitely be balanced, yes
	self.cl.loadedRocketsMax = self.cl.weaponData.mod2.mastery.owned and 5 or 3
	--also reduce the load max to make it even more balanced
	self.cl.rocketLoadMax = self.cl.weaponData.mod2.mastery.owned and self.cl.rocketLoadMax * 0.33 or self.cl.rocketLoadMax

	--powerup
	local increase = dt * self.cl.spdMult

    --Mod switch cooldown
	if self.cl.afterModCD then
		self.cl.afterModCDCount = self.cl.afterModCDCount + increase*1.75

		if self.cl.afterModCDCount >= 1 then
			self.cl.afterModCDCount = 1
			self.cl.afterModCD = false
		end
	end

	--mod_lock
	if self.cl.lockCD then
		self.cl.lockCDCount = self.cl.lockCDCount + dt
		if self.cl.lockCDCount >= self.cl.lockCDMax then
			self.cl.lockCDCount = 0
			self.cl.lockCD = false
		end
	end

	if self.cl.fireRockets and self.cl.loadedRockets > 0 then
		if self.cl.fireType.current == self.cl.fireType.types[1] then
			self.cl.fireRocketCount = self.cl.fireRocketCount + increase

			if self.cl.fireRocketCount >= 0.25 then
				self.cl.loadedRockets = self.cl.loadedRockets - 1
				self.cl.fireRocketCount = 0
				sm.audio.play( "Retrofmblip" )
				if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_rocket, 1 ) then
					local dir = sm.localPlayer.getDirection()
					local owner = sm.localPlayer.getPlayer()
					self.network:sendToServer("sv_shootRocket",
						{
							pos = self:calculateFirePosition() + lookDir,
							dir = dir,
							owner = owner,
							tracking = true,
							target = self.cl.rocketTarget,
							type = "lock"
						}
					)
				end

				self:onShoot( lookDir )
				self.network:sendToServer( "sv_n_onShoot", lookDir )
				setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
			end
		else
			for i = 1, self.cl.loadedRockets do
				local dir = lookDir:rotate( math.rad(math.random(-5,5)), sm.camera.getUp() )
				dir = dir:rotate( math.rad(math.random(-4,4)), sm.camera.getRight() )
				local owner = sm.localPlayer.getPlayer()

				self.network:sendToServer("sv_shootRocket",
					{
						pos = self:calculateFirePosition() + lookDir,
						dir = dir,
						owner = owner,
						tracking = true,
						target = self.cl.rocketTarget,
						type = "lock"
					}
				)
				self.cl.loadedRockets = self.cl.loadedRockets - 1
			end

			self:onShoot( lookDir )
			self.network:sendToServer( "sv_n_onShoot", lookDir )
			setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
		end

		if self.cl.loadedRockets == 0 then
			self.cl.lockCD = true
			self.cl.rocketTarget = nil
			self.cl.fireRockets = false
		end
	end

	if self.cl.currentWeaponMod == mod_lock and self.cl.usingMod and not self.cl.lockCD then
		local hit, result = sm.localPlayer.getRaycast( 100 )
		if self.cl.rocketTarget == nil then
			if result.type == "character" then
				self.cl.rocketTarget = result:getCharacter()
			end
		elseif sm.exists(self.cl.rocketTarget) then
			if (result.type ~= "character" or result:getCharacter() ~= self.cl.rocketTarget) and self.cl.loadedRockets < self.cl.loadedRocketsMax and not self.cl.fireRockets then
				self.cl.rocketTarget = nil
				self.cl.loadedRockets = 0
				self.cl.rocketLoadCount = 0
			elseif not self.cl.fireRockets then
				if self.cl.loadedRockets < self.cl.loadedRocketsMax and self.cl.rocketLoadCount < self.cl.rocketLoadMax then
					self.cl.rocketLoadCount = self.cl.rocketLoadCount + dt
				--elseif self.cl.loadedRockets == self.cl.loadedRocketsMax then
				--	self.cl.fireRockets = true
				end

				if self.cl.rocketLoadCount >= self.cl.rocketLoadMax then
					sm.audio.play( "Blueprint - Open" )
					self.cl.loadedRockets = self.cl.loadedRockets + 1
					self.cl.rocketLoadCount = 0
				end
			end
		elseif not sm.exists(self.cl.rocketTarget) and self.cl.rocketTarget ~= nil then
			self.cl.rocketTarget = nil
			self.cl.loadedRockets = 0
			self.cl.rocketLoadCount = 0
		end
	end
end

function RLauncher.client_onReload( self )
	if self.cl.weaponData.mod1.owned and self.cl.weaponData.mod2.owned then
		self.cl.modSwitchCount = self.cl.modSwitchCount + 1
		if self.cl.modSwitchCount % 2 == 0 then
			self.cl.currentWeaponMod = mod_lock
		else
			self.cl.currentWeaponMod = mod_detonate
		end
		self.cl.afterModCDCount = 0
		self.cl.afterModCD = true
		sm.gui.displayAlertText("Current weapon mod: #ff9d00" .. self.cl.currentWeaponMod, 2.5)
		sm.audio.play("PaintTool - ColorPick")
	elseif self.cl.weaponData.mod1.owned or self.cl.weaponData.mod2.owned or self.cl.currentWeaponMod == "poor" then
		sm.audio.play("Button off")
	end

	return true
end

--[[function RLauncher:client_onToggle()
	if self.cl.fireRockets then return end

	self.cl.fireType.count = self.cl.fireType.count + 1
	self.cl.fireType.current = self.cl.fireType.count%2 == 0 and self.cl.fireType.types[1] or self.cl.fireType.types[2]
	sm.gui.displayAlertText("Current fire mode: #ff9d00"..self.cl.fireType.current, 2.5)
	sm.audio.play("PaintTool - ColorPick")

	return true
end]]

function RLauncher:client_onClientDataUpdate( data, channel )
	if not self.tool:isLocal() then return end

	self.cl.detRockets = data
end

function RLauncher:sv_saveCurrentWpnData( data )
	sm.event.sendToPlayer( self.cl.player, "sv_saveWPData", data )
end

function RLauncher:sv_shootRocket( args )
	local player = self.tool:getOwner()
	sm.container.beginTransaction()
	sm.container.spend( player:getInventory(), se_ammo_rocket, 1, true )
	sm.container.endTransaction()

	args.spawnTick = sm.game.getServerTick()
	local playerPublic = player:getPublicData().data
	args.flare = playerPublic.weaponData.rocket.mod1.up1.owned
	args.falter = playerPublic.weaponData.rocket.mod1.up2.owned
	local rocket = sm.scriptableObject.createScriptableObject(
		proj_rocket_sob,
		args,
		args.owner:getCharacter():getWorld()
	)

	if args.type == "detonate" then
		self.sv.detRockets[#self.sv.detRockets+1] = rocket
		self.storage:save( self.sv.detRockets )
		self.network:setClientData( self.sv.detRockets )
	end
end

function RLauncher:sv_detonateRockets()
	for k, rocket in pairs(self.sv.detRockets) do
		if sm.exists(rocket) then
			sm.event.sendToScriptableObject(rocket, "sv_onDetonate")
		end
	end

	self.sv.detRockets = {}
	self.storage:save( self.sv.detRockets )
	self.network:setClientData( self.sv.detRockets )
end
--SE

function RLauncher.client_onUpdate( self, dt )
	--SE
	local increase = dt * self.cl.spdMult
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
		updateFpAnimations( self.fpAnimations, self.equipped, increase )
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
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0
	self.tool:setBlockSprint( blockSprint )

	local playerDir = self.tool:getDirection()
	local angle = math.asin( playerDir:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )
	local linareAngle = playerDir:dot( sm.vec3.new( 0, 0, 1 ) )

	local linareAngleDown = clamp( -linareAngle, 0.0, 1.0 )

	local down = clamp( -angle, 0.0, 1.0 )
	local fwd = ( 1.0 - math.abs( angle ) )
	local up = clamp( angle, 0.0, 1.0 )

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight

	local totalWeight = 0.0
	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + increase

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * increase ), 1.0 )

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
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * increase ), 0.0 )
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
		self.jointWeight = math.min( self.jointWeight + ( 10.0 * increase ), 1.0 )
	else
		self.jointWeight = math.max( self.jointWeight - ( 6.0 * increase ), 0.0 )
	end

	if ( not isSprinting ) then
		self.spineWeight = math.min( self.spineWeight + ( 10.0 * increase ), 1.0 )
	else
		self.spineWeight = math.max( self.spineWeight - ( 10.0 * increase ), 0.0 )
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
		local blend = 1 - math.pow( 1 - 1 / self.aimBlendSpeed, increase * 60 )
		self.aimWeight = sm.util.lerp( self.aimWeight, 1.0, blend )
		bobbing = 0.12
	else
		local blend = 1 - math.pow( 1 - 1 / self.aimBlendSpeed, increase * 60 )
		self.aimWeight = sm.util.lerp( self.aimWeight, 0.0, blend )
		bobbing = 1
	end

	self.tool:updateCamera( 2.8, 30.0, sm.vec3.new( 0.65, 0.0, 0.05 ), self.aimWeight )
	self.tool:updateFpCamera( 30.0, sm.vec3.new( 0.0, 0.0, 0.0 ), self.aimWeight, bobbing )
end

function RLauncher.client_onEquip( self, animate )
    --SE
    if self.cl.currentWeaponMod ~= "poor" then
        sm.gui.displayAlertText("Current weapon mod: #ff9d00" .. self.cl.currentWeaponMod, 2.5)
    end
    --SE

	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

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

	setTpAnimation( self.tpAnimations, "pickup", 0.1 )

	if self.tool:isLocal() then
		-- Sets RLauncher renderable, change this to change the mesh
		self.tool:setFpRenderables( currentRenderablesFp )
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function RLauncher.client_onUnequip( self, animate )

	if animate then
		sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
	end

	self.wantEquipped = false
	self.equipped = false
	setTpAnimation( self.tpAnimations, "putdown" )
	if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
		swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
	end
end

function RLauncher.sv_n_onAim( self, aiming )
	self.network:sendToClients( "cl_n_onAim", aiming )
end

function RLauncher.cl_n_onAim( self, aiming )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onAim( aiming )
	end
end

function RLauncher.onAim( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function RLauncher.sv_n_onShoot( self, dir )
	self.network:sendToClients( "cl_n_onShoot", dir )
end

function RLauncher.cl_n_onShoot( self, dir )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onShoot( dir )
	end
end

function RLauncher.onShoot( self, dir )

	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0
	self.tpAnimations.animations.aimShoot.time = 0

	setTpAnimation( self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0 )

	if self.tool:isInFirstPersonView() then
			self.shootEffectFP:start()
		else
			self.shootEffect:start()
	end

end

function RLauncher.calculateFirePosition( self )
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

function RLauncher.calculateTpMuzzlePos( self )
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

function RLauncher.calculateFpMuzzlePos( self )
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

function RLauncher.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end

	if self.fireCooldownTimer <= 0.0 and state == sm.tool.interactState.start and getFpAnimationProgress(self.fpAnimations, "equip") >= 0.75 then

		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_rocket, 1 ) then
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
			if owner then
				if self.cl.currentWeaponMod == mod_lock and self.cl.loadedRockets == 0 or self.cl.currentWeaponMod == "poor" then
					self.network:sendToServer("sv_shootRocket",
						{
							pos = firePos,
							dir = sm.localPlayer.getDirection(),
							owner = sm.localPlayer.getPlayer(),
							tracking = false,
							target = nil,
							type = "lock"
						}
					)
				elseif self.cl.currentWeaponMod == mod_lock and self.cl.loadedRockets > 0 and self.cl.usingMod then
					self.cl.fireRockets = true
				elseif self.cl.currentWeaponMod == mod_detonate then
					self.network:sendToServer("sv_shootRocket",
						{
							pos = firePos,
							dir = sm.localPlayer.getDirection(),
							owner = sm.localPlayer.getPlayer(),
							tracking = false,
							target = nil,
							type = "detonate"
						}
					)
				end
			end

			-- Timers
			self.fireCooldownTimer = fireMode.fireCooldown
			self.spreadCooldownTimer = math.min( self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown )
			self.sprintCooldownTimer = self.sprintCooldown

			if not self.cl.fireRockets then
				self:onShoot( dir )
				self.network:sendToServer( "sv_n_onShoot", dir )
				setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
			end
		else
			local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
			self.fireCooldownTimer = fireMode.fireCooldown
			sm.audio.play( "PotatoRifle - NoAmmo" )
		end
	end
end

function RLauncher.cl_onSecondaryUse( self, state )
	if state == sm.tool.interactState.start and not self.cl.usingMod then
		--SE
		self.cl.usingMod = true
		--SE
	end

	if self.cl.usingMod and (state == sm.tool.interactState.stop or state == sm.tool.interactState.null) then
		--SE
		self.cl.usingMod = false

		if self.cl.loadedRockets > 0 and not self.cl.fireRockets then
			self.cl.fireRockets = true
		end

		if self.cl.currentWeaponMod == mod_detonate then
			if #self.cl.detRockets > 0 then
				self.network:sendToServer("sv_detonateRockets")
				sm.audio.play( "Retrofmblip" )
			else
				sm.audio.play("Lever off")
			end
		end
		--SE
	end
end

function RLauncher.client_onEquippedUpdate( self, primaryState, secondaryState )
    --SE
	local data = {
		mod = self.cl.currentWeaponMod,
		using = self.cl.usingMod,
		ammo = 0,
		recharge = 0
	}
	self.network:sendToServer( "sv_saveCurrentWpnData", data )

    if self.cl.afterModCD then
		sm.gui.setProgressFraction(self.cl.afterModCDCount/1)
	end

	if self.cl.currentWeaponMod == mod_lock and self.cl.usingMod and not self.cl.afterModCD or self.cl.currentWeaponMod == mod_lock and self.cl.loadedRockets > 0 then
		sm.gui.setProgressFraction(self.cl.loadedRockets/self.cl.loadedRocketsMax)
	end
    --SE

    if primaryState ~= self.prevPrimaryState then
		self:cl_onPrimaryUse( primaryState )
		self.prevPrimaryState = primaryState
	end

	if secondaryState ~= self.prevSecondaryState then
		self:cl_onSecondaryUse( secondaryState )
		self.prevSecondaryState = secondaryState
	end

	return true, true
end