--[[
I planned to make the hammer have two mods, but I decided against that
if I ever make a haybot pitchfork weapon, it's mod will be the throw mod that the hammer would have originally had.
]]


dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

local hammerUUID = sm.uuid.new("bb641a4f-e391-441c-bc6d-0ae21a069476")
local slamDashAmount = 1250
local weakUnits = {
	"48c03f69-3ec8-454c-8d1a-fa09083363b1",
	"8984bdbf-521e-4eed-b3c4-2b5e287eb879",
	"04761b4a-a83e-4736-b565-120bc776edb2",
	"9dbbd2fb-7726-4e8f-8eb4-0dab228a561d",
	"fcb2e8ce-ca94-45e4-a54b-b5acc156170b",
	"68d3b2f3-ed4b-4967-9d22-8ee6f555df63",
	"c3d31c47-0c9b-4b07-9bd4-8f022dc4333e"
}

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

function Sledgehammer:server_onCreate()
	self.sv = {}
	self.sv.owner = self.tool:getOwner()
	self.sv.ownerChar = self.sv.owner.character
	self.sv.hammerStunArea = sm.areaTrigger.createBox(sm.vec3.new(6,6,6), self.sv.ownerChar.worldPosition, sm.quat.identity(), sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody )

	self.inHammerState = false
	self.invincibiltyCD = false
	self.invincibiltyCDcount = 0.25
	self.slamStateCheck = 0.1
	self.slamDashCount = 0
end

function Sledgehammer:server_onFixedUpdate( dt )
	self.sv.hammerStunArea:setWorldPosition( self.sv.ownerChar.worldPosition )

	if self.slamStateCheck < 0.1 then
		self.slamStateCheck = self.slamStateCheck + dt
		if self.slamStateCheck > 0.1 then
			self.slamStateCheck = 0.1
		end
	end

	if self.inHammerState and self.slamStateCheck == 0.1 then
	 	if self.playerVel.z < 2.5 and self.slamDashCount > 0 then
			sm.physics.applyImpulse(self.sv.ownerChar, sm.vec3.new(0, 0, -slamDashAmount) + self.sv.ownerChar:getDirection() * sm.vec3.new(slamDashAmount, slamDashAmount, 0), false, nil)
			self.slamDashCount = 0 --self.slamDashCount - dt
		end

		if self.sv.ownerChar:isOnGround() then
			self:sv_onLand()
			--self:sv_explode(self.playerPos)

			self.inHammerState = false
			self.invincibiltyCD = true
		end
	end

	if self.invincibiltyCD then
		self.invincibiltyCDcount = self.invincibiltyCDcount - dt
		if self.invincibiltyCDcount <= 0 then
			self.invincibiltyCDcount = 0.25
			self.invincibiltyCD = false
			self.data.isInvincible = false
		end
	end
end

function Sledgehammer.client_onCreate( self )
	self.isLocal = self.tool:isLocal()
	self:init()

	self.cl = {}
	self.cl.baseWeapon = BaseWeapon()
	self.cl.baseWeapon.cl_onCreate( self, "hammer" )

	if not self.tool:isLocal() then return end

	self.dmgMult = 1
	self.spdMult = 1
	self.berserk = false
	self.Damage = 20

	self.data = sm.playerInfo[self.cl.owner:getId()].weaponData.hammer
	self.playerData = sm.playerInfo[self.cl.owner:getId()].playerData
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

function Sledgehammer.client_onFixedUpdate( self, dt )
	self.dmgMult = self.playerData.damageMultiplier
	self.spdMult = self.playerData.speedMultiplier
	self.berserk = self.playerData.berserk

	self.Damage = 20 --nice fix there bro
	local multVal = self.berserk and self.dmgMult * 2 or self.dmgMult
	self.Damage = self.Damage * multVal
end

function Sledgehammer.client_onReload( self )
	local char = self.cl.owner.character
	local pos = char.worldPosition

	if self.playerData.hammerCharge >= 1 and not sm.physics.raycast( pos, pos + sm.vec3.new(0,0,2.5)) and not char:isSwimming() and not char:isDiving() then
		self.network:sendToServer("sv_onSlam")
	elseif self.playerData.hammerCharge < 1 then
		sm.gui.displayAlertText("You dont have a slam charge yet.", 2.5)
		sm.audio.play( "RaftShark" )
	else
		sm.gui.displayAlertText("You cant slam here.", 2.5)
		sm.audio.play( "RaftShark" )
	end

	return true
end

function Sledgehammer.sv_explode( self, pos )
	sm.physics.explode( pos, 10, 50, 10, 20, "PropaneTank - ExplosionBig")
end

function Sledgehammer:sv_onLand()
	local pos = self.sv.owner.worldPosition

	for i, object in pairs(self.sv.hammerStunArea:getContents()) do
		if type(object) == "Body" then
			sm.physics.applyImpulse( object, ( object:getCenterOfMassPosition() - pos ):normalize() * 20 )
			--print("Applied impulse to:", object)
		elseif type(object) == "Character" then
			if sm.exists(object) and not object:isPlayer() then
				if isAnyOf(tostring(object:getCharacterType()), weakUnits) then
					sm.event.sendToUnit( object:getUnit(), "sv_stun", { deadly = true, playerPos = pos, player = self.sv.owner } )
					--print( "Killed unit", object:getId() )
				else
					sm.event.sendToUnit( object:getUnit(), "sv_stun", { deadly = false, playerPos = pos, player = self.sv.owner } )
					--print( "Froze unit", object:getId() )
				end
			end
		end
	end

	self.network:sendToClients( "cl_onLand" )
end

function Sledgehammer:cl_onLand()
	setFpAnimation( self.fpAnimations, "sledgehammer_attack1", 0.0 )
	setTpAnimation( self.tpAnimations, "sledgehammer_attack1", 0.0 )
	sm.effect.playEffect( "PropaneTank - ExplosionSmall", self.cl.owner.character.worldPosition )
	sm.audio.play( "Sledgehammer - Swing" )
end

function Sledgehammer:sv_onSlam()
	local pos = self.sv.ownerChar.worldPosition
	if sm.physics.raycast( pos, pos - sm.vec3.new(0,0,1)) then
		sm.physics.applyImpulse(self.sv.ownerChar, sm.vec3.new(0, 0, 1000))
	else
		sm.physics.applyImpulse(self.sv.ownerChar, sm.vec3.new(0, 0, -slamDashAmount) + self.sv.ownerChar:getDirection() * sm.vec3.new(slamDashAmount, slamDashAmount, 0))
	end

	self.playerData.hammerCharge = self.playerData.hammerCharge - 1
	self.slamStateCheck = 0
	self.slamDashCount = 1
	self.data.isInvincible = true
	self.inHammerState = true

	self.network:sendToClients("cl_onSlam")
end

function Sledgehammer:cl_onSlam()
	setFpAnimation( self.fpAnimations, "guardIdle", 0.25 )
	setTpAnimation( self.tpAnimations, "guardIdle", 0.25 )
end

function Sledgehammer.client_onUpdate( self, dt )
	--Why the fuck can you scroll off? The tool stays equipped but you can scroll off. Such shit
	--also buggy apparently
	--[[if self.inHammerState then
		sm.tool.forceTool( self.tool )
	end]]

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
	if primaryState == sm.tool.interactState.start and self.inHammerState == false or ( primaryState == sm.tool.interactState.hold and self.startedSwinging ) and self.inHammerState == false then 

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

	sm.gui.setProgressFraction(self.playerData.hammerCharge / 1)

	return true, false
end

function Sledgehammer.client_onEquip( self, animate )
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
	if self.isLocal then
		self.network:sendToServer("sv_onUnequip")
		if self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	end

	--self.network:sendToServer( "sv_updateBlocking", false )
end

function Sledgehammer:sv_onUnequip()
	self.inHammerState = false
	self.data.isInvincible = false
end

function Sledgehammer.sv_updateBlocking( self, isBlocking )
	if self.isBlocking ~= isBlocking then
		sm.event.sendToPlayer( self.tool:getOwner(), "sv_updateBlocking", isBlocking )
	end
	self.isBlocking = isBlocking
end