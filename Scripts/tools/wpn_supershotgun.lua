dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

local hookPointUUID = sm.uuid.new("93710416-d976-4702-96ab-d0107fd4abb2")
local hookRange = 50

SSG = class()

local renderables = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_frier/char_spudgun_barrel_frier.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"

	--"$GAME_DATA/Character/Char_Tools/SCRAP_Eternal/SSG/SSG.rend"
}

local renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend", "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"}
local renderablesFp = {"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function SSG.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunFrier - FrierMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunFrier - FPFrierMuzzel" )

	--SE

	--General stuff
	self.player = sm.localPlayer.getPlayer()
	self.playerChar = self.player:getCharacter()

	self.data = sm.playerInfo[self.player:getId()].weaponData.ssg

	--Hook
	self.hookAttached = false
	self.target = nil
	self.distance = sm.vec3.zero()
	self.distanceNormalized = sm.vec3.zero()
	self.targetPos = sm.vec3.zero()
	self.hookCD = false
	self.hookCDcount = 5
	self.hookCDMax = 5

	self.leftOrbit = false
	self.rightOrbit = false

	--Chains
	self.ropeEffect = sm.effect.createEffect("ShapeRenderable")
	self.ropeEffect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))

	self.hookGui = sm.gui.createWaypointIconGui()
	--SE
end

function SSG.client_onRefresh( self )
	self:loadAnimations()
end

function SSG.loadAnimations( self )

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
		spreadCooldown = 0.18,
		spreadIncrement = 4,
		spreadMinAngle = 4,
		spreadMaxAngle = 16,
		fireVelocity = 130.0,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.aimFireMode = {
		fireCooldown = 1.25,
		spreadCooldown = 0.18,
		spreadIncrement = 4,
		spreadMinAngle = 4,
		spreadMaxAngle = 16,
		fireVelocity =  130.0,

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
function SSG:server_onFixedUpdate( dt )
	if self.hookAttached then
		if self.distance.z <= 3 or not sm.exists(self.target) then
			self.network:sendToClient( self.player, "cl_toggleHook", { toggle = false, cd = true })
		else
			sm.physics.applyImpulse( self.playerChar, se.vec3.num(10000) * self.distanceNormalized * dt)
		end
	end
end

function SSG:sv_saveCurrentWpnData( data )
	sm.event.sendToPlayer( self.player, "sv_saveWPData", data )
end

function SSG:client_onFixedUpdate( dt )
	self.playerChar = self.player:getCharacter()
	self.playerLookDir = self.playerChar:getDirection()
	self.playerPos = self.playerChar:getWorldPosition()

	local data = sm.playerInfo[self.player:getId()]
	local playerData = data.playerData
	local jump = playerData.inputs.jump
	local left = playerData.inputs.dir.left.active
	local right = playerData.inputs.dir.right.active
	self.dmgMult = playerData.damageMultiplier
	self.spdMult = playerData.speedMultiplier
	self.data = data.weaponData.ssg

	playerData.meathookAttached = self.hookAttached

	--fuck off
	if self.fireCooldownTimer == nil then
		self.fireCooldownTimer = 0
	end

	--upgrades
	self.hookCDMax = self.data.mod1.up1.owned and 2.5 or 5
	if self.normalFireMode ~= nil then
		self.normalFireMode.fireCooldown = self.data.mod1.up2.owned and 0.8 or 1.25
	end

	local colour = self.data.mod1.mastery.owned and sm.color.new("#DF7F00") or sm.color.new(0,0,0)
	self.ropeEffect:setParameter("color", colour)

	--powerup
	local increase = dt * self.spdMult
	self.Damage = 35 --nice fix there bro
	self.Damage = self.Damage * self.dmgMult

	if self.hookAttached then
		--Detach jump
		if jump then
			self:cl_toggleHook({ toggle = false, cd = true })
			self.network:sendToServer("sv_applyImpulse", { char = self.playerChar, force = se.vec3.redirectVel( "z", 1000, self.playerChar ) } )
		end

		--Orbit around enemy
		if left then
			if self.rightOrbit then
				self.rightOrbit = false
			elseif self.leftOrbit then
				self.leftOrbit = false
			else
				self.leftOrbit = true
			end
		elseif right then
			if self.leftOrbit then
				self.leftOrbit = false
			elseif self.rightOrbit then
				self.rightOrbit = false
			else
				self.rightOrbit = true
			end
		end

		local dir = sm.vec3.zero()
		if self.leftOrbit then
			dir = sm.vec3.rotate( self.delta, math.rad(-90), sm.vec3.new(0,0,1) ):normalize()
		elseif self.rightOrbit then
			dir = sm.vec3.rotate( self.delta, math.rad(90), sm.vec3.new(0,0,1) ):normalize()
		end

		if dir ~= sm.vec3.zero() then
			self.network:sendToServer("sv_applyImpulse", { char = self.playerChar, force = sm.vec3.new( 8000, 8000, 0 ) * dir * dt } )
		end
	else
		self.leftOrbit = false
		self.rightOrbit = false
	end

	if self.target ~= nil and sm.exists(self.target) and self.hookAttached then
		self:cl_calcHookData( self.target )

		local hit, result = sm.physics.raycast( self.playerPos, self.targetPos )

		if hit then
			if result.type == "Character" then
				if type(self.target) == "Shape" or result:getCharacter() ~= self.target then
					self:cl_toggleHook({ toggle = false, cd = true })
				end
			elseif result.type == "Shape" then
				if type(self.target) == "Character" or result:getShape() ~= self.target then
					self:cl_toggleHook({ toggle = false, cd = true })
				end
			end
		end
	end

	--Hook cooldown
	if self.hookCD then
		self.hookCDcount = self.hookCDcount + increase
		if self.hookCDcount >= self.hookCDMax then
			self.hookCDcount = self.hookCDMax
			self.hookCD = false
			sm.audio.play("Blueprint - Open")
			sm.gui.displayAlertText("Hook recharged.")
		end
	end
end

function SSG:sv_applyImpulse( args )
	sm.physics.applyImpulse( args.char, args.force )
end

function SSG.cl_onSecondaryUse( self, state )
	if state == sm.tool.interactState.start and not self.hookAttached and self.target == nil then
		local hit, result = sm.localPlayer.getRaycast( hookRange )
		if hit then
			self:cl_toggleHook({ toggle = true, data = result })
		end
	elseif state == sm.tool.interactState.start and self.hookAttached then
		self:cl_toggleHook({ toggle = false, cd = true })
	end
end

function SSG:cl_toggleHook( args )
	if args.toggle --[[and not self.hookCD]] then
		if args.data.type == "character" then
			self.hookAttached = true
			self.target = args.data:getCharacter()
			self.targetPos = self.target:getWorldPosition()
			self.ropeEffect:start()
			self:cl_calcHookData( self.target )

			self.network:sendToServer("sv_toggleHook", true )
			sm.audio.play("WeldTool - Weld")

			self.oneTickBehind = sm.game.getCurrentTick()
			self.playerHeight = self.playerPos.z
		elseif args.data.type == "body" then
			if sm.shape.getShapeUuid( args.data:getShape() ) == hookPointUUID then
				self.target = args.data:getShape()
				self.targetUUID = sm.shape.getShapeUuid( self.target )
				self.network:sendToServer("sv_hookAPoint", true)
				self.network:sendToServer("sv_toggleHook", true )
			else
				sm.audio.play("Lever off")
			end
		else
			sm.audio.play("Lever off")
		end
	elseif not args.toggle then
		if type(self.target) == "Shape" then
			self.network:sendToServer("sv_hookAPoint", false)
		end

		self.distanceNormalized = sm.vec3.zero()
		self.distance = sm.vec3.zero()
		if args.cd then
			self.hookCD = true
			self.hookCDcount = 0
		end
		self.ropeEffect:stop()

		sm.audio.play("Lever off")
		self.network:sendToServer("sv_toggleHook", false )
	else
		sm.audio.play("RaftShark")
		sm.gui.displayAlertText("You dont have a hook charge yet.")
	end
end

function SSG:sv_toggleHook( toggle )
	self.playerChar:setSwimming( toggle )
	sm.effect.playEffect( "Sledgehammer - Hit", self.targetPos )

	if type(self.target) == "Character" then
		if toggle then
			sm.event.sendToUnit(self.target:getUnit(), "sv_onHook", { player = self.player, fire = self.data.mod1.mastery.owned } )
		else
			if self.target ~= nil and sm.exists(self.target) and sm.exists(self.target:getUnit()) then
				sm.event.sendToUnit(self.target:getUnit(), "sv_onUnHook")
			end
			self.hookAttached = false
			self.target = nil
			self.targetPos = sm.vec3.zero()
		end
	end
end

function SSG:cl_calcHookData( hookedObj )
	self.targetPos = hookedObj:getWorldPosition()
	self.delta = (self.hookPos - self.targetPos)
	self.rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), self.delta)
	self.distanceNormalized = self.delta:normalize() * -1
	self.distance = sm.vec3.new(0.01, 0.01, self.delta:length())

	self.ropeEffect:setPosition(self.targetPos + self.delta * 0.5)
	self.ropeEffect:setScale(self.distance)
	self.ropeEffect:setRotation(self.rot)
end

function SSG:sv_hookAPoint( toggle )
	local hookPointData
	if self.target ~= nil then
		local int = self.target:getInteractable()
		sm.event.sendToInteractable( int, "togglehook", toggle )
		hookPointData = sm.interactable.getPublicData( int )
	end

	self.network:sendToClient(self.player, "cl_hookAPoint", { toggle = toggle, data = hookPointData })
end

function SSG:cl_hookAPoint( args )
	if args.toggle and args.data.canBeHooked then
		self.hookAttached = true
		self:cl_calcHookData( self.target )
		self.ropeEffect:start()
		self.network:sendToServer("sv_toggleHook", true )
		sm.audio.play("WeldTool - Weld")
	else
		self.hookAttached = false
		self.target = nil
		self:cl_toggleHook( { toggle = false, cd = false } )
	end
end
--SE

function SSG.client_onUpdate( self, dt )
	--SE
	local increase = dt * self.spdMult
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
	--local dir = self.tool:getTpBoneDir( "pejnt_barrel" )
	local dir = sm.localPlayer.getDirection()

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

function SSG.client_onEquip( self, animate )
	--SE
	local data = {
		mod = "ssg",
		ammo = 0,
		recharge = 0
	}
	self.network:sendToServer( "sv_saveCurrentWpnData", data )
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

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )

	if self.tool:isLocal() then
		-- Sets SSG renderable, change this to change the mesh
		self.tool:setFpRenderables( currentRenderablesFp )
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function SSG.client_onUnequip( self, animate )
	--SE
	if self.hookAttached then
		self:cl_toggleHook( { toggle = false, cd = true } )
	end

	self.hookGui:close()
	--SE
	
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

function SSG.sv_n_onAim( self, aiming )
	self.network:sendToClients( "cl_n_onAim", aiming )
end

function SSG.cl_n_onAim( self, aiming )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onAim( aiming )
	end
end

function SSG.onAim( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function SSG.sv_n_onShoot( self, dir )
	self.network:sendToClients( "cl_n_onShoot", dir )
end

function SSG.cl_n_onShoot( self, dir )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onShoot( dir )
	end
end

function SSG.onShoot( self, dir )
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

function SSG.calculateFirePosition( self )
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

function SSG.calculateTpMuzzlePos( self )
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

function SSG.calculateFpMuzzlePos( self )
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

function SSG.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end
	if self.fireCooldownTimer <= 0.0 and state == sm.tool.interactState.start then

		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_shells, 2 ) then

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

			local owner = self.tool:getOwner()
			if owner then
				sm.projectile.projectileAttack( proj_ssg, self.Damage, firePos, dir * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf )
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
end

function SSG.client_onEquippedUpdate( self, primaryState, secondaryState )
	--SE
	if not self.hookCD then
		local hit, result = sm.localPlayer.getRaycast( hookRange )
		if hit and result:getCharacter() then
			self.hookGui:setWorldPosition( result:getCharacter():getWorldPosition(), self.playerChar:getWorld() )
			self.hookGui:setItemIcon( "Icon", "WaypointIconMap", "WaypointIconMap", "meathook" )
			self.hookGui:setRequireLineOfSight( false )
			self.hookGui:setMaxRenderDistance( 10000 )

			self.hookGui:open()
		else
			self.hookGui:close()
		end
	else
		self.hookGui:close()
	end

	if self.tool:isInFirstPersonView() then
		self.hookPos = self.tool:getFpBonePos( "pejnt_barrel" )
	else
		self.hookPos = self.tool:getTpBonePos( "pejnt_barrel" )
	end

	if self.hookCD then
		sm.gui.setProgressFraction(self.hookCDcount/self.hookCDMax)
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
