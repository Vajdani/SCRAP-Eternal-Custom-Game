--[[
I planned to make the hammer have two mods, but I decided against that
if I ever make a haybot pitchfork weapon, it's mod will be the throw mod that the hammer would have originally had.
]]


dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

local hammerUUID = sm.uuid.new("bb641a4f-e391-441c-bc6d-0ae21a069476")
local mod_slam = "Slam"
local mod_throw = "Throw"
local slamDashAmount = 1250

Sledgehammer = class()

local renderables = {
	"$GAME_DATA/Character/Char_Tools/Char_sledgehammer/char_sledgehammer.rend"
}

local renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_sledgehammer.rend", "$GAME_DATA/Character/Char_Tools/Char_sledgehammer/char_sledgehammer_tp_animlist.rend"}
local renderablesFp = {"$GAME_DATA/Character/Char_Tools/Char_sledgehammer/char_sledgehammer_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

local Range = 3.0
local SwingStaminaSpend = 1.5

Sledgehammer.swingCount = 2
Sledgehammer.mayaFrameDuration = 1.0/30.0
Sledgehammer.freezeDuration = 0.075

Sledgehammer.swings = { "sledgehammer_attack1", "sledgehammer_attack2" }
Sledgehammer.swingFrames = { 4.2 * Sledgehammer.mayaFrameDuration, 4.2 * Sledgehammer.mayaFrameDuration }
Sledgehammer.swingExits = { "sledgehammer_exit1", "sledgehammer_exit2" }

function Sledgehammer.client_onCreate( self )
	self.isLocal = self.tool:isLocal()
	self:init()

	--SE
	self.player = sm.localPlayer.getPlayer()
	self.playerChar = self.player:getCharacter()

	self.dmgMult = 1
	self.spdMult = 1
	self.berserk = false
	self.Damage = 20

	self.data = sm.playerInfo[self.player:getId()].weaponData.hammer
	self.playerData = sm.playerInfo[self.player:getId()].playerData

	--[[if self.data.mod1.owned then
		self.currentWeaponMod = mod_slam
	elseif self.data.mod2.owned then
		self.currentWeaponMod = mod_throw
	else
		self.currentWeaponMod = "poor"
	end

	self.modSwitchCount = 0]]

	--mod_slam
	self.inHammerState = false
	self.invincibiltyCD = false
	self.invincibiltyCDcount = 0.25
	self.slamStateCheck = 0.1
	self.slamDashCount = 0
	self.unitsToStun = {}

	--mod_throw
	self.playerInv = nil
	self.hammer = true
	self.aimFireMode = {
		fireCooldown = 0.20,
		spreadCooldown = 0.18,
		spreadIncrement = 1.3,
		spreadMinAngle = 0,
		spreadMaxAngle = 8,
		fireVelocity =  10.0,

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

	--SE
end

function Sledgehammer.client_onRefresh( self )
	self:init()
	self:loadAnimations()
end

function Sledgehammer.init( self )

	self.attackCooldownTimer = 0.0
	self.freezeTimer = 0.0
	self.pendingRaycastFlag = false
	self.nextAttackFlag = false
	self.currentSwing = 1

	self.swingCooldowns = {}
	for i = 1, self.swingCount do
		self.swingCooldowns[i] = 0.0
	end

	self.dispersionFraction = 0.001

	self.blendTime = 0.2
	self.blendSpeed = 10.0

	self.sharedCooldown = 0.0
	self.hitCooldown = 1.0
	self.blockCooldown = 0.5
	self.swing = false
	self.block = false

	self.wantBlockSprint = false

	if self.animationsLoaded == nil then
		self.animationsLoaded = false
	end
end

function Sledgehammer.loadAnimations( self )

	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			equip = { "sledgehammer_pickup", { nextAnimation = "idle" } },
			unequip = { "sledgehammer_putdown" },
			idle = {"sledgehammer_idle", { looping = true } },
			idleRelaxed = {"sledgehammer_idle_relaxed", { looping = true } },
			
			sledgehammer_attack1 = { "sledgehammer_attack1", { nextAnimation = "sledgehammer_exit1" } },
			sledgehammer_attack2 = { "sledgehammer_attack2", { nextAnimation = "sledgehammer_exit2" } },
			sledgehammer_exit1 = { "sledgehammer_exit1", { nextAnimation = "idle" } },
			sledgehammer_exit2 = { "sledgehammer_exit2", { nextAnimation = "idle" } },
			
			guardInto = { "sledgehammer_guard_into", { nextAnimation = "guardIdle" } },
			guardIdle = { "sledgehammer_guard_idle", { looping = true } },
			guardExit = { "sledgehammer_guard_exit", { nextAnimation = "idle" } },
			
			guardBreak = { "sledgehammer_guard_break", { nextAnimation = "idle" } }--,
			--guardHit = { "sledgehammer_guard_hit", { nextAnimation = "guardIdle" } }
			--guardHit is missing for tp
			
		
		}
	)
	local movementAnimations = {
		idle = "sledgehammer_idle",
		idleRelaxed = "sledgehammer_idle_relaxed",

		runFwd = "sledgehammer_run_fwd",
		runBwd = "sledgehammer_run_bwd",

		sprint = "sledgehammer_sprint",

		jump = "sledgehammer_jump",
		jumpUp = "sledgehammer_jump_up",
		jumpDown = "sledgehammer_jump_down",

		land = "sledgehammer_jump_land",
		landFwd = "sledgehammer_jump_land_fwd",
		landBwd = "sledgehammer_jump_land_bwd",

		crouchIdle = "sledgehammer_crouch_idle",
		crouchFwd = "sledgehammer_crouch_fwd",
		crouchBwd = "sledgehammer_crouch_bwd"
		
	}
    
	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end
    
	setTpAnimation( self.tpAnimations, "idle", 5.0 )
    
	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "sledgehammer_pickup", { nextAnimation = "idle" } },
				unequip = { "sledgehammer_putdown" },				
				idle = { "sledgehammer_idle",  { looping = true } },

				sprintInto = { "sledgehammer_sprint_into", { nextAnimation = "sprintIdle" } },
				sprintIdle = { "sledgehammer_sprint_idle", { looping = true } },
				sprintExit = { "sledgehammer_sprint_exit", { nextAnimation = "idle" } },

				sledgehammer_attack1 = { "sledgehammer_attack1", { nextAnimation = "sledgehammer_exit1" } },
				sledgehammer_attack2 = { "sledgehammer_attack2", { nextAnimation = "sledgehammer_exit2" } },
				sledgehammer_exit1 = { "sledgehammer_exit1", { nextAnimation = "idle" } },
				sledgehammer_exit2 = { "sledgehammer_exit2", { nextAnimation = "idle" } },

				guardInto = { "sledgehammer_guard_into", { nextAnimation = "guardIdle" } },
				guardIdle = { "sledgehammer_guard_idle", { looping = true } },
				guardExit = { "sledgehammer_guard_exit", { nextAnimation = "idle" } },

				guardBreak = { "sledgehammer_guard_break", { nextAnimation = "idle" } },
				guardHit = { "sledgehammer_guard_hit", { nextAnimation = "guardIdle" } }

			}
		)
		setFpAnimation( self.fpAnimations, "idle", 0.0 )
	end
	--self.swingCooldowns[1] = self.fpAnimations.animations["sledgehammer_attack1"].info.duration
	self.swingCooldowns[1] = 0.6
	--self.swingCooldowns[2] = self.fpAnimations.animations["sledgehammer_attack2"].info.duration
	self.swingCooldowns[2] = 0.6

	self.animationsLoaded = true

end

--SE
function Sledgehammer.client_onFixedUpdate( self, dt )
	self.playerChar = self.player:getCharacter()
	self.playerPos = self.playerChar:getWorldPosition()
	self.playerVel = self.playerChar:getVelocity()
	self.raycastEnd = sm.vec3.new(self.playerPos.x, self.playerPos.y, self.playerPos.z - 1)
	self.playerLookDir = sm.localPlayer.getDirection()

	self.data = sm.playerInfo[self.player:getId()].weaponData.hammer
	self.playerData = sm.playerInfo[self.player:getId()].playerData

	self.dmgMult = self.playerData.damageMultiplier
	self.spdMult = self.playerData.speedMultiplier
	self.berserk = self.playerData.berserk

	self.Damage = 20 --nice fix there bro
	local multVal = self.berserk and self.dmgMult * 2 or self.dmgMult
	self.Damage = self.Damage * multVal
end

function Sledgehammer:sv_spendHammer()
	sm.container.beginTransaction()
	sm.container.spend( self.playerInv, hammerUUID, 1, 1 )
	sm.container.endTransaction()
end

function Sledgehammer.client_onReload( self )
	if self.playerData.hammerCharge >= 1 and not sm.physics.raycast( self.playerPos, sm.vec3.new(self.playerPos.x, self.playerPos.y, self.playerPos.z + 2.5)) and not self.playerChar:isSwimming() and not self.playerChar:isDiving() then
		if sm.physics.raycast( self.playerPos, self.raycastEnd) then
			sm.physics.applyImpulse(self.playerChar, sm.vec3.new(0, 0, 1000))
		else
			sm.physics.applyImpulse(self.playerChar, sm.vec3.new(0, 0, -slamDashAmount))
			sm.physics.applyImpulse(self.playerChar, self.playerLookDir*sm.vec3.new(slamDashAmount, slamDashAmount, 0))
		end
		setFpAnimation( self.fpAnimations, "guardIdle", 0.25 )
		setTpAnimation( self.tpAnimations, "guardIdle", 0.25 )

		self.playerData.hammerCharge = self.playerData.hammerCharge - 1
		self.slamStateCheck = 0
		self.slamDashCount = 1
		self.data.isInvincible = true
		self.inHammerState = true
	elseif self.playerData.hammerCharge < 1 then
		sm.gui.displayAlertText("You dont have a slam charge yet.", 2.5)
		sm.audio.play( "RaftShark" )
	else
		sm.gui.displayAlertText("You cant slam here.", 2.5)
		sm.audio.play( "RaftShark" )
	end

	--[[if self.data.mod1.owned and self.data.mod2.owned then
		self.modSwitchCount = self.modSwitchCount + 1
		if self.modSwitchCount % 2 == 0 then
			self.currentWeaponMod = mod_slam
		else
			self.currentWeaponMod = mod_throw
		end
		--self.afterModCDCount = 0
		--self.afterModCD = true
		sm.gui.displayAlertText(" Current weapon mod: #ff9d00" .. self.currentWeaponMod, 2.5)
		sm.audio.play("PaintTool - ColorPick")
	elseif self.data.mod1.owned or self.data.mod2.owned or self.currentWeaponMod == "poor" then
		sm.audio.play("Button off")
	end]]

	return true
end

function Sledgehammer:sv_saveCurrentWpnData( data )
	sm.event.sendToPlayer( self.player, "sv_saveWPData", data )
end

function Sledgehammer.sv_explode( self, pos )
	sm.physics.explode( pos, 10, 50, 10, 20, "PropaneTank - ExplosionBig")
end

function Sledgehammer:cl_freezeUnits( trigger, result )
	self.unitsToStun = result
	self.network:sendToServer("sv_freezeUnits")
end

function Sledgehammer:sv_freezeUnits()
	for i, object in pairs(self.unitsToStun) do
		if type(object) == "Body" then
			sm.physics.applyImpulse( object, ( object:getCenterOfMassPosition() - self.playerPos ):normalize() * object:getMass() * 20 )
			--print("Applied impulse to:", object)
		elseif type(object) == "Character" then
			if object:getId() ~= self.playerChar:getId() and sm.exists(object) then
				local uuidStr = tostring(object:getCharacterType())
				if uuidStr ~= "48c03f69-3ec8-454c-8d1a-fa09083363b1" and uuidStr ~= "8984bdbf-521e-4eed-b3c4-2b5e287eb879" and uuidStr ~= "04761b4a-a83e-4736-b565-120bc776edb2" and uuidStr ~= "9dbbd2fb-7726-4e8f-8eb4-0dab228a561d" and uuidStr ~= "fcb2e8ce-ca94-45e4-a54b-b5acc156170b" and uuidStr ~= "68d3b2f3-ed4b-4967-9d22-8ee6f555df63" and uuidStr ~= "c3d31c47-0c9b-4b07-9bd4-8f022dc4333e"  then
					sm.event.sendToUnit( object:getUnit(), "sv_stun", { deadly = false, playerPos = self.playerPos, player = self.player } )
					--print( "Froze unit", object:getId() )
				else
					sm.event.sendToUnit( object:getUnit(), "sv_stun", { deadly = true, playerPos = self.playerPos, player = self.player } )
					--print( "Killed unit", object:getId() )
				end
			end
		end
	end
	--print(" ")
	sm.areaTrigger.destroy( self.hammerStunArea )
end

function Sledgehammer.sv_toggleRagdoll( self, args)
    args.ragdollingChar:setTumbling( args.tumbleBool )
end

function Sledgehammer.calculateFirePosition( self )
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

function Sledgehammer.calculateTpMuzzlePos( self )
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

function Sledgehammer.calculateFpMuzzlePos( self )
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
--SE

function Sledgehammer.client_onUpdate( self, dt )
	--SE
	--Why the fuck can you scroll off? The tool stays equipped but you can scroll off. Such shit
	--also buggy apparently
	--[[if self.inHammerState then
		sm.tool.forceTool( self.tool )
	end]]

	self.playerInv = self.player:getInventory()
	self.hammer = sm.container.totalQuantity( self.playerInv, hammerUUID ) and true or false

	if self.slamStateCheck < 0.1 then
		self.slamStateCheck = self.slamStateCheck + dt
		if self.slamStateCheck > 0.1 then
			self.slamStateCheck = 0.1
		end
	end

	if self.inHammerState then
	 	if self.playerVel.z < 2.5 and self.slamStateCheck == 0.1 and self.slamDashCount > 0 then
			sm.physics.applyImpulse(self.playerChar, sm.vec3.new(0, 0, -slamDashAmount), false, nil)
			sm.physics.applyImpulse(self.playerChar, self.playerLookDir*sm.vec3.new(slamDashAmount, slamDashAmount, 0), nil, nil)
			self.slamDashCount = 0 --self.slamDashCount - dt
		end

		if self.slamStateCheck == 0.1 and self.playerChar:isOnGround() then
			setFpAnimation( self.fpAnimations, "sledgehammer_attack1", 0.0 )
			setTpAnimation( self.tpAnimations, "sledgehammer_attack1", 0.0 )
			sm.audio.play( "Sledgehammer - Swing" )

			self.hammerStunArea = sm.areaTrigger.createBox(sm.vec3.new(6,6,6), self.playerPos, sm.quat.identity(), sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody )
			self.hammerStunArea:bindOnEnter("cl_freezeUnits")
			sm.effect.playEffect( "PropaneTank - ExplosionSmall", self.playerPos )

			--self.network:sendToServer("sv_explode", self.playerPos)

			--fucking retarded ass tumbling bullshit, why did I do this? wtf
			--self.network:sendToServer("sv_toggleRagdoll", { ragdollingChar = self.playerChar, tumbleBool = true } )

			self.inHammerState = false
			self.invincibiltyCD = true
		end

		self.network:sendToServer("sv_toggleRagdoll", { ragdollingChar = self.playerChar, tumbleBool = false } )
	end

	if self.invincibiltyCD then
		self.invincibiltyCDcount = self.invincibiltyCDcount - dt
		if self.invincibiltyCDcount <= 0 then
			self.invincibiltyCDcount = 0.25
			self.invincibiltyCD = false
			self.data.isInvincible = false
		end
	end

	--SE

	if sm.exists(self.tool) then
		if not self.animationsLoaded then
			return
		end

		--synchronized update
		self.attackCooldownTimer = math.max( self.attackCooldownTimer - (dt*self.spdMult), 0.0 )

		--standard third person updateAnimation
		updateTpAnimations( self.tpAnimations, self.equipped, (dt*self.spdMult) )

		--update
		if self.isLocal then
			if self.fpAnimations.currentAnimation == self.swings[self.currentSwing] then
				self:updateFreezeFrame(self.swings[self.currentSwing], (dt*self.spdMult))
			end

			local preAnimation = self.fpAnimations.currentAnimation

			updateFpAnimations( self.fpAnimations, self.equipped, (dt*self.spdMult) )

			if preAnimation ~= self.fpAnimations.currentAnimation then

				-- Ended animation - re-evaluate what next state is
				local keepBlockSprint = false
				local endedSwing = preAnimation == self.swings[self.currentSwing] and self.fpAnimations.currentAnimation == self.swingExits[self.currentSwing]
				if self.nextAttackFlag == true and endedSwing == true then
					-- Ended swing with next attack flag

					-- Next swing
					self.currentSwing = self.currentSwing + 1
					if self.currentSwing > self.swingCount then
						self.currentSwing = 1
					end
					local params = { name = self.swings[self.currentSwing] }
					self.network:sendToServer( "server_startEvent", params )
					sm.audio.play( "Sledgehammer - Swing" )
					self.pendingRaycastFlag = true
					self.nextAttackFlag = false
					self.attackCooldownTimer = self.swingCooldowns[self.currentSwing]
					keepBlockSprint = true

				elseif isAnyOf( self.fpAnimations.currentAnimation, { "guardInto", "guardIdle", "guardExit", "guardBreak", "guardHit" } )  then
					keepBlockSprint = true
				end

				--Stop sprint blocking
				self.tool:setBlockSprint(keepBlockSprint)
			end

			local isSprinting =  self.tool:isSprinting() 
			if isSprinting and self.fpAnimations.currentAnimation == "idle" and self.attackCooldownTimer <= 0 and not isAnyOf( self.fpAnimations.currentAnimation, { "sprintInto", "sprintIdle" } ) then
				local params = { name = "sprintInto" }
				self:client_startLocalEvent( params )
			end

			if ( not isSprinting and isAnyOf( self.fpAnimations.currentAnimation, { "sprintInto", "sprintIdle" } ) ) and self.fpAnimations.currentAnimation ~= "sprintExit" then
				local params = { name = "sprintExit" }
				self:client_startLocalEvent( params )
			end
		end
	end
end

function Sledgehammer.updateFreezeFrame( self, state, dt )
	local p = 1 - math.max( math.min( self.freezeTimer / self.freezeDuration, 1.0 ), 0.0 )
	local playRate = p * p * p * p
	self.fpAnimations.animations[state].playRate = playRate
	self.freezeTimer = math.max( self.freezeTimer - dt, 0.0 )
end

function Sledgehammer.server_startEvent( self, params )
	local player = self.tool:getOwner()
	if player then
		sm.event.sendToPlayer( player, "sv_e_staminaSpend", SwingStaminaSpend )
	end
	self.network:sendToClients( "client_startLocalEvent", params )
end

function Sledgehammer.client_startLocalEvent( self, params )
	self:client_handleEvent( params )
end

function Sledgehammer.client_handleEvent( self, params )
	-- Setup animation data on equip
	if params.name == "equip" then
		self.equipped = true
		--self:loadAnimations()
	elseif params.name == "unequip" then
		self.equipped = false
	end

	if not self.animationsLoaded then
		return
	end

	--Maybe not needed
-------------------------------------------------------------------

	-- Third person animations
	local tpAnimation = self.tpAnimations.animations[params.name]
	if tpAnimation then
		local isSwing = false
		for i = 1, self.swingCount do
			if self.swings[i] == params.name then
				self.tpAnimations.animations[self.swings[i]].playRate = 1
				isSwing = true
			end
		end

		local blend = not isSwing
		setTpAnimation( self.tpAnimations, params.name, blend and 0.2 or 0.0 )
	end

	-- First person animations
	if self.isLocal then
		local isSwing = false

		for i = 1, self.swingCount do
			if self.swings[i] == params.name then
				self.fpAnimations.animations[self.swings[i]].playRate = 1
				isSwing = true
			end
		end

		if isSwing or isAnyOf( params.name, { "guardInto", "guardIdle", "guardExit", "guardBreak", "guardHit" } ) then
			self.tool:setBlockSprint( true )
		else
			self.tool:setBlockSprint( false )
		end

		if params.name == "guardInto" then
			swapFpAnimation( self.fpAnimations, "guardExit", "guardInto", 0.2 )
		elseif params.name == "guardExit" then
			swapFpAnimation( self.fpAnimations, "guardInto", "guardExit", 0.2 )
		elseif params.name == "sprintInto" then
			swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.2 )
		elseif params.name == "sprintExit" then
			swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.2 )
		else
			local blend = not ( isSwing or isAnyOf( params.name, { "equip", "unequip" } ) )
			setFpAnimation( self.fpAnimations, params.name, blend and 0.2 or 0.0 )
		end

	end
end

--function Sledgehammer.sv_n_toggleTumble( self )
--	local character = self.tool:getOwner().character
--	character:setTumbling( not character:isTumbling() )
--end

function Sledgehammer.client_onEquippedUpdate( self, primaryState, secondaryState )
	--HACK Enter/exit tumble state when hammering
	--if primaryState == sm.tool.interactState.start then
	--	self.network:sendToServer( "sv_n_toggleTumble" )
	--end

	if self.pendingRaycastFlag then
		local time = 0.0
		local frameTime = 0.0
		if self.fpAnimations.currentAnimation == self.swings[self.currentSwing] then
			time = self.fpAnimations.animations[self.swings[self.currentSwing]].time
			frameTime = self.swingFrames[self.currentSwing] * self.spdMult
		end
		if time >= frameTime and frameTime ~= 0 then
			self.pendingRaycastFlag = false
			local raycastStart = sm.localPlayer.getRaycastStart()
			local direction = sm.localPlayer.getDirection()
			sm.melee.meleeAttack( "Sledgehammer", self.Damage, raycastStart, direction * Range, self.tool:getOwner() )
			local success, result = sm.localPlayer.getRaycast( Range, raycastStart, direction )
			if success then
				self.freezeTimer = self.freezeDuration
			end
		end
	end

	--Start attack?
	self.startedSwinging = ( self.startedSwinging or primaryState == sm.tool.interactState.start ) and primaryState ~= sm.tool.interactState.stop and primaryState ~= sm.tool.interactState.null
	if primaryState == sm.tool.interactState.start and self.inHammerState == false or ( primaryState == sm.tool.interactState.hold and self.startedSwinging ) and self.inHammerState == false then --SE

		--Check if we are currently playing a swing
		if self.fpAnimations.currentAnimation == self.swings[self.currentSwing] then
			if self.attackCooldownTimer < 0.125 then
				self.nextAttackFlag = true
			end
		else
			--Not currently swinging
			--Is the prev attack done?
			if self.attackCooldownTimer <= 0 then
				self.currentSwing = 1
				--Not sprinting and not close to anything
				--Start swinging!
				local params = { name = self.swings[self.currentSwing] }
				self.network:sendToServer( "server_startEvent", params )
				sm.audio.play( "Sledgehammer - Swing" )
				self.pendingRaycastFlag = true
				self.nextAttackFlag = false
				self.attackCooldownTimer = self.swingCooldowns[self.currentSwing]
				--self.network:sendToServer( "sv_updateBlocking", false )
			end
		end
	end

	--SE
	--[[if secondaryState == sm.tool.interactState.start and self.currentWeaponMod == mod_slam then
		if self.playerData.hammerCharge == 1 and not sm.physics.raycast( self.playerPos, sm.vec3.new(self.playerPos.x, self.playerPos.y, self.playerPos.z + 2.5), 1 ) and not self.playerChar:isSwimming() and not self.playerChar:isDiving() then
			if sm.physics.raycast( self.playerPos, sm.vec3.new(self.raycastEnd.x, self.raycastEnd.y, self.raycastEnd.z - 1.5), 1 ) then
				sm.physics.applyImpulse(self.playerChar, sm.vec3.new(0, 0, 1000))
			else
				sm.physics.applyImpulse(self.playerChar, sm.vec3.new(0, 0, -250))
				sm.physics.applyImpulse(self.playerChar, self.playerLookDir*sm.vec3.new(slamDashAmount, slamDashAmount, 0))
			end
			setFpAnimation( self.fpAnimations, "guardIdle", 0.25 )
			setTpAnimation( self.tpAnimations, "guardIdle", 0.25 )
			--sm.audio.play( "ConnectTool" )

			--self.playerData.hammerCharge = 0
			self.slamStateCheck = 0
			self.slamDashCount = 1
			beginTick = sm.game.getCurrentTick()
			g_godMode = true
			self.inHammerState = true
		elseif self.playerData.hammerCharge < 1 then
			sm.gui.displayAlertText(" You dont have a slam charge yet.", 2.5)
			sm.audio.play( "RaftShark" )
		else
			sm.gui.displayAlertText(" You cant slam here.", 2.5)
			sm.audio.play( "RaftShark" )
		end
	elseif secondaryState == sm.tool.interactState.hold and self.currentWeaponMod == mod_throw and self.hammer then
		if self.tool:getOwner().character == nil then
			return
		end

		local firstPerson = self.tool:isInFirstPersonView()

		local dir = sm.localPlayer.getDirection()

		local firePos = self:calculateFirePosition()
		--local fakePosition = self:calculateTpMuzzlePos()
		--local fakePositionSelf = fakePosition
		--if firstPerson then
		--	fakePositionSelf = self:calculateFpMuzzlePos()
		--end

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
		local fireMode = self.aimFireMode
		local recoilDispersion = 1.0 - ( math.max(fireMode.minDispersionCrouching, fireMode.minDispersionStanding ) + fireMode.maxMovementDispersion )

		local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp( self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0 ) or 0.0 spreadFactor = clamp( self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0 )
		local spreadDeg =  fireMode.spreadMinAngle + ( fireMode.spreadMaxAngle - fireMode.spreadMinAngle ) * spreadFactor

		dir = sm.noise.gunSpread( dir, spreadDeg )

		local owner = self.tool:getOwner()

		if owner then
			sm.projectile.projectileAttack( "hammer", 100, firePos, dir * fireMode.fireVelocity, owner )
		end 

		self.network:sendToServer("sv_spendHammer")
	end]]
	--SE

	--Seondary Block
	--if secondaryState == sm.tool.interactState.start then
	--	if not isAnyOf( self.fpAnimations.currentAnimation, { "guardInto", "guardIdle" } ) and self.attackCooldownTimer <= 0 then
	--		local params = { name = "guardInto" }
	--		self.network:sendToServer( "server_startEvent", params )
	--		self.network:sendToServer( "sv_updateBlocking", true )
	--	end
	--end
	--
	--if secondaryState == sm.tool.interactState.stop or secondaryState == sm.tool.interactState.null then
	--	if isAnyOf( self.fpAnimations.currentAnimation, { "guardInto", "guardIdle" } ) and self.fpAnimations.currentAnimation ~= "guardExit"  then
	--		local params = { name = "guardExit" }
	--		self.network:sendToServer( "server_startEvent", params )
	--		self.network:sendToServer( "sv_updateBlocking", false )
	--	end
	--end
	--
	--return primaryState ~= sm.tool.interactState.null or secondaryState ~= sm.tool.interactState.null

	--Secondary destruction

	--SE
	sm.gui.setProgressFraction(self.playerData.hammerCharge / 1)
	--SE

	return true, false
end

function Sledgehammer.client_onEquip( self, animate )
	--SE
	--if self.currentWeaponMod ~= "poor" then
		--sm.gui.displayAlertText(" Current weapon mod: #ff9d00" .. self.currentWeaponMod, 2.5)
		local data = {
			mod = "hammer", --self.currentWeaponMod
			ammo = 0,
			recharge = 0
		}
		self.network:sendToServer( "sv_saveCurrentWpnData", data )
	--end
	--SE

	if animate then
		sm.audio.play( "Sledgehammer - Equip", self.tool:getPosition() )
	end

	self.equipped = true

	for k,v in pairs( renderables ) do renderablesTp[#renderablesTp+1] = v end
	for k,v in pairs( renderables ) do renderablesFp[#renderablesFp+1] = v end

	self.tool:setTpRenderables( renderablesTp )

	self:init()
	self:loadAnimations()

	setTpAnimation( self.tpAnimations, "equip", 0.0001 )

	if self.isLocal then
		self.tool:setFpRenderables( renderablesFp )
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end

	--self.network:sendToServer( "sv_updateBlocking", false )
end

function Sledgehammer.client_onUnequip( self, animate )

	if animate then
		sm.audio.play( "Sledgehammer - Unequip", self.tool:getPosition() )
	end

	self.equipped = false
	setTpAnimation( self.tpAnimations, "unequip" )
	if self.isLocal and self.fpAnimations.currentAnimation ~= "unequip" then
		swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
	end

	--self.network:sendToServer( "sv_updateBlocking", false )

	--SE
	self.inHammerState = false
	self.data.isInvincible = false
	--SE
end

function Sledgehammer.sv_updateBlocking( self, isBlocking )
	if self.isBlocking ~= isBlocking then
		sm.event.sendToPlayer( self.tool:getOwner(), "sv_updateBlocking", isBlocking )
	end
	self.isBlocking = isBlocking
end