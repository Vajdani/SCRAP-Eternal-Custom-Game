dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"

local hookPointUUID = sm.uuid.new("93710416-d976-4702-96ab-d0107fd4abb2")
local baseDamage = 35
local hookRange = 50
local hookForceMult = 250
local hookDetachDistance = 1.5
local meathookDetachImpulse = 1250
local meathookUseCD = 5 * 40
local normalHookColour = sm.color.new(0,0,0)
local burningHookColour = sm.color.new("#df7f00")

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

	self.cl = {}
	self.cl.hooks = {}
	self.cl.owner = sm.localPlayer.getPlayer()
	local data = self.cl.owner:getClientPublicData()
	self.cl.weaponData = data.data.weaponData.ssg
	self.cl.prpData = data.powerup

	if not self.tool:isLocal() then return end
	self.cl.data = data.data

	self.cl.useCD = {
		active = false,
		timer = Timer(),
		ticks = 5 * 40
	}
	self.cl.useCD.timer:start(self.cl.useCD.ticks)

	self.cl.primState = nil
	self.cl.secState = nil

	self.cl.hookGui = sm.gui.createWorldIconGui( 50, 50 )
	self.cl.hookGui:setImage("Icon", "$CONTENT_DATA/Gui/UpgradeStation/icon_mod_meathook.png")
	self.cl.hookTarget = nil
end

function SSG:server_onCreate()
	self.sv = {}
	self.sv.hookTarget = nil
	self.sv.owner = self.tool:getOwner()
	self.sv.data = self.sv.owner:getPublicData()
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

function SSG:sv_saveCurrentWpnData( data )
	sm.event.sendToPlayer( self.cl.owner, "sv_saveWPData", data )
end

function SSG:client_onToggle()
	return true
end

function SSG:client_onFixedUpdate( dt )
	if not sm.exists(self.tool) or not self.tool:isLocal() then return end

	--Hook cooldown
	if self.cl.useCD.active then
		self.cl.useCD.timer:tick()
		if self.cl.useCD.timer:done() then
			self.cl.useCD.timer:reset()
			self.cl.useCD.active = false
			sm.audio.play("Blueprint - Open")
			sm.gui.displayAlertText("Hook recharged.")
		end

		if self.cl.hookGui:isActive() then
			self.cl.hookGui:close()
		end

		return
	end

	if not self.tool:isEquipped() then return end

	--upgrades
	self.cl.useCD.timer.ticks = self.cl.weaponData.mod1.up1.owned and meathookUseCD / 2 or meathookUseCD
	if self.normalFireMode ~= nil then
		self.normalFireMode.fireCooldown = self.cl.weaponData.mod1.up2.owned and 0.8 or 1.25
	end

	local clientData = self.cl.owner:getClientPublicData()
	if clientData.data.playerData.meathookAttached and clientData.input[sm.interactable.actions.jump] then
		self.network:sendToServer("sv_applyImpulse", { char = self.cl.owner.character, dir = se.vec3.up() * meathookDetachImpulse } )
		self.cl.hookTarget = nil
		self.network:sendToServer("sv_setHookTarget", { target = nil, player = self.cl.owner })
	end

	if self.cl.hookTarget ~= nil and sm.exists(self.cl.hookTarget) then
		if self.cl.secState == 1 then
			self.cl.hookTarget = nil
			self.network:sendToServer("sv_setHookTarget", { target = nil, player = self.cl.owner })
		end

		return
	else
		self.cl.hookTarget = nil
	end

	local hit, result = sm.localPlayer.getRaycast( hookRange )
	if hit then
		local char = result:getCharacter()
		local shape = result:getShape()
		local target = char and isAnyOf(char:getCharacterType(), g_robots) and char or nil
		target = shape and shape.uuid == hookPointUUID and shape or target

		if target then
			self:cl_updateHookGUI_HookTarget( target )
		else
			self.cl.hookGui:close()
		end
	else
		self.cl.hookGui:close()
	end
end

function SSG:cl_updateHookGUI_HookTarget( target )
	self.cl.hookGui:open()
	self.cl.hookGui:setWorldPosition( target:getWorldPosition() )

	if self.cl.secState == sm.tool.interactState.start then
		self.cl.hookTarget = target
		self.cl.owner:getClientPublicData().data.playerData.meathookAttached = true
		self.network:sendToServer("sv_setHookTarget", { target = target, player = self.cl.owner })
		self.cl.hookGui:close()
	end
end

function SSG:sv_setHookTarget( args )
	self.sv.data.data.playerData.meathookAttached = args.target ~= nil
	self.sv.hookTarget = args.target

	self.network:sendToClients("cl_createHook", { player = args.player, target = args.target, pos = args.player:getCharacter():getWorldPosition(), dir = args.player:getCharacter():getDirection(), delete = args.target == nil } )
end

function SSG:cl_createHook( args )
	local id = args.player:getId()
	if args.delete then
		self.cl.hooks[id].effect:stopImmediate()
		self.cl.hooks[id] = nil

		local player = sm.localPlayer.getPlayer()
		if args.player == player then
			player:getClientPublicData().data.playerData.meathookAttached = false
			self.cl.useCD.active = true
		end

		return
	end

	local hook = sm.effect.createEffect("ShapeRenderable")
	hook:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
	hook:setParameter("color", self.cl.weaponData.mod1.mastery.owned and burningHookColour or normalHookColour)
	hook:setPosition( args.pos )
	hook:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), args.dir ) )
	hook:setScale(sm.vec3.new(0.1,0.1,0.1))
	hook:start()
	self.cl.hooks[id] = { effect = hook, player = args.player, target = args.target, pos = args.pos }
end

function SSG:server_onFixedUpdate( dt )
	if self.sv.hookTarget ~= nil and sm.exists(self.sv.hookTarget) then
		local playerChar = self.sv.owner:getCharacter()
		local dir = self.sv.hookTarget:getWorldPosition() - playerChar.worldPosition

		if dir:length() <= hookDetachDistance or se_weapon_isInvalidMeathookDir(self.sv.owner.character:getDirection():cross(dir)) then
			self:sv_setHookTarget( { target = nil, player = self.sv.owner })
			self.network:sendToClients("cl_reset")

			--sm.physics.applyImpulse( playerChar, -playerChar.velocity * playerChar.mass)
			--playerChar:setWorldPosition(playerChar.worldPosition)
			return
		end

		local orbitDir = dir:rotate( math.rad(-90), se.vec3.up() )
		if self.sv.data.input[sm.interactable.actions.right] then
			dir = dir + orbitDir
		end

		if self.sv.data.input[sm.interactable.actions.left] then
			dir = dir - orbitDir
		end

		sm.physics.applyImpulse(playerChar, dir:normalize() * hookForceMult, true)
		--playerChar:setWorldPosition(playerChar.worldPosition + dir:normalize())
	elseif self.sv.hookTarget ~= nil then
		self:sv_setHookTarget( { target = nil, player = self.sv.owner })
		self.network:sendToClients("cl_reset")
	end
end

function SSG:sv_applyImpulse( args )
	sm.physics.applyImpulse(args.char, args.dir, true)
end

function SSG:cl_reset()
	if self.tool:isLocal() then
		self.cl.hookTarget = nil
	end
end


function SSG.client_onUpdate( self, dt )
	if not sm.exists(self.tool) then return end

	for v, k in pairs(self.cl.hooks) do
		if sm.exists(k.target) then
			k.pos = self.tool:getOwner() == sm.localPlayer.getPlayer() and self.tool:isInFirstPersonView() and self.tool:getFpBonePos( "pejnt_barrel" ) or self.tool:getTpBonePos( "pejnt_barrel" )
			local targetPos = k.target:getWorldPosition()
			local delta = targetPos - k.pos
			local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta)
			local distance = sm.vec3.new(0.01, 0.01, delta:length())

			k.effect:setPosition(k.pos + delta * 0.5)
			k.effect:setScale(distance)
			k.effect:setRotation(rot)
		end
	end

	local increase = dt * self.cl.prpData.speedMultiplier.current

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
	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.wantEquipped = true
	self.aiming = false
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )
	self.jointWeight = 0.0

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}

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
	if self.tool:isLocal() then
		self.cl.hookGui:close()
	end

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
				sm.projectile.projectileAttack( proj_ssg, baseDamage * self.cl.data.playerData.damageMultiplier, firePos, dir * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf )
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
	self.cl.primState = primaryState
	self.cl.secState = secondaryState

	if self.cl.useCD.active then
		sm.gui.setProgressFraction(self.cl.useCD.timer.count/self.cl.useCD.timer.ticks)
	end

	if primaryState ~= self.prevPrimaryState then
		self:cl_onPrimaryUse( primaryState )
		self.prevPrimaryState = primaryState
	end

	return true, true
end
