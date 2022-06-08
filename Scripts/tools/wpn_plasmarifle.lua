dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

PRifle = class()

local mod_blast = "Heat Blast"
local mod_beam = "Microwave Beam"
local blastDamage = 50

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

function PRifle.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunBasic - BasicMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunBasic - FPBasicMuzzel" )

	--SE

	--General stuff
	self.player = sm.localPlayer.getPlayer()
	self.playerChar = self.player:getCharacter()

	self.data = sm.playerInfo[self.player:getId()].weaponData.plasma

	self.dmgMult = 1
	self.spdMult = 1
	self.Damage = 24
	self.isFiring = false
	self.usingMod = false

	--Mod switch
	if self.data.mod1.owned then
		self.currentWeaponMod = mod_blast
	elseif self.data.mod2.owned then
		self.currentWeaponMod = mod_beam
	else
		self.currentWeaponMod = "poor"
	end

	self.modSwitchCount = 0
	self.afterModCD = false
	self.afterModCDCount = 1

	--mod_blast
	self.blastChargeIncrease = 1
	self.blastCharge = 0
	self.blastChargeLevel = 0
	self.blastFireDelay = false
	self.blastFireDelayCD = 0
	self.blastFireDelayCDMax = 0.75
	self.blastMasteryDmg = false
	self.blastMasteryDmgCD = 0
	self.blastTrigger = nil
	self.triggerDestroycd = false
	self.triggerDestroyCD = 0.3
	self.effect = sm.effect.createEffect( "Thruster - Level 5" )

	--mod_beam
	self.beamActivateMax = 1
	self.beamActivateCD = 0
	self.beamCD = false
	self.beamRange = 10
	self.beamTargets = { target1 = nil, target2 = nil }
	self.beamDmgCounter = 0
	self.targetData = nil

	self.beamEffect = sm.effect.createEffect("ShapeRenderable")
	self.beamEffect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
	self.beamEffect:setParameter("color", sm.color.new(0, 1, 1, 1))
end

function PRifle.client_onRefresh( self )
	self:loadAnimations()
end

function PRifle.loadAnimations( self )

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
		fireCooldown = 0.20,
		spreadCooldown = 0.18,
		spreadIncrement = 2.6,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 8,
		fireVelocity = 130.0,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.aimFireMode = {
		fireCooldown = 0.20,
		spreadCooldown = 0.18,
		spreadIncrement = 1.3,
		spreadMinAngle = 0,
		spreadMaxAngle = 8,
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
function PRifle:client_onFixedUpdate( dt )
	local playerData = sm.playerInfo[self.player:getId()].playerData
	self.data = sm.playerInfo[self.player:getId()].weaponData.plasma
	self.dmgMult = playerData.damageMultiplier
	self.spdMult = playerData.speedMultiplier

	--fuck off
	if self.fireCooldownTimer == nil then
		self.fireCooldownTimer = 0
	end

	if self.currentWeaponMod == "poor" then
		if self.data.mod1.owned then
			self.currentWeaponMod = mod_blast
		elseif self.data.mod2.owned then
			self.currentWeaponMod = mod_beam
		end

		--checks if youre still poor, and if you are, it returns so that it doesnt calculate all the shit below this
		if self.currentWeaponMod == "poor" then
			return
		end
	end

	--upgrades
	self.blastFireDelayCDMax = self.data.mod1.up1.owned and 0.5 or 0.75
	self.blastChargeIncrease = self.data.mod1.up2.owned and 2 or 1
	self.beamActivateMax = self.data.mod2.up1.owned and 0.75 or 1
	self.beamRange = self.data.mod2.up2.owned and 15 or 10

	if self.blastMasteryDmg then
		self.blastMasteryDmgCD = self.blastMasteryDmgCD + dt
		if self.blastMasteryDmgCD >= 5 then
			self.blastMasteryDmgCD = 0
			self.blastMasteryDmg = false
		end
	else
		self.Damage = 24
	end

	--powerup
	local increase = dt * self.spdMult

	if not self.blastMasteryDmg then
		self.Damage = self.Damage * self.dmgMult
	end

	--main and some mod_blast
	if (self.currentWeaponMod == "poor" and self.isFiring or self.currentWeaponMod == mod_blast and self.isFiring and not self.blastFireDelay or self.currentWeaponMod == mod_beam and not self.afterModCD and self.isFiring and not self.usingMod ) and not self.playerChar:isSwimming() and not self.playerChar:isDiving() and self.tool:isEquipped() then
		self.fireCounter = self.fireCounter + increase
		if (self.fireCounter/0.2) > 1 then
			if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_plasma, 1 ) then
				self:shootProjectile( proj_plasma, self.Damage )
				if self.blastMasteryDmg then
					sm.audio.play( "Retrofmblip" )
				end

				if self.currentWeaponMod == mod_blast and self.blastCharge < 60 and not self.blastMasteryDmg then
					self.blastCharge = self.blastCharge + self.blastChargeIncrease
					if self.blastCharge == 20 or self.blastCharge == 40 or self.blastCharge == 60 then
						sm.audio.play( "Blueprint - Open" )
					end
				end
			else
				sm.audio.play( "PotatoRifle - NoAmmo" )
			end
		end

		if self.fireCounter > 0.2 then
			self.fireCounter = 0
		end
	else
		self.fireCounter = 0
	end

	--mod_beam
	--print(self.beamCD)
	if self.beamCD then
		self.beamActivateCD = self.beamActivateCD + increase
		if self.beamActivateCD >= self.beamActivateMax then
			self.beamActivateCD = 0
			self.beamCD = false
		end
	end

	if self.currentWeaponMod == mod_beam and self.usingMod and not self.beamCD and not self.afterModCD then
		if self.beamTargets.target1 == nil then
			local hit, result = sm.localPlayer.getRaycast( self.beamRange )
			if result.type == "character" then
				self.beamTargets.target1 = result:getCharacter()
			end
		elseif sm.exists(self.beamTargets.target1) then
			local targetPos = self.beamTargets.target1:getWorldPosition()
			local delta = (self:calculateFirePosition() - targetPos)
			local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta)
			local distance = sm.vec3.new(0.01, 0.01, delta:length())

			if distance.z <= 15 then
				self.beamEffect:setPosition(targetPos + delta * 0.5)
				self.beamEffect:setScale(distance)
				self.beamEffect:setRotation(rot)
				self.beamEffect:start()

				--try to find any other enemies that the beam intercepts
				local hit, result = sm.physics.raycast( self.playerPos, targetPos )
				if result.type == "character" then
					self.beamTargets.target2 = result:getCharacter()
				end

				self.beamDmgCounter = self.beamDmgCounter + increase

				if self.beamDmgCounter >= 0.15 then
					for pos, target in pairs (self.beamTargets) do
						if sm.exists(target) then
							self.network:sendToServer("sv_beamAttack", { target = target, damage = 10, impact = self.lookDir, hitPos = target:getWorldPosition(), attacker = self.player } )
						else
							self.beamTargets[pos] = nil
						end
					end
					self.beamDmgCounter = 0
				end
			else
				self.beamCD = true
				self.beamTargets = {}
				self.beamEffect:stop()
			end
		elseif not sm.exists(self.beamTargets.target1) and self.beamTargets.target1 ~= nil then
			self.targetData = nil
			self.beamCD = true
			self.beamTargets = { target1 = nil, target2 = nil }
			self.beamEffect:stop()
		end
	end


	--mod_blast
	--print(self.blastCharge)
	--print(self.blastChargeLevel)
	self.blastChargeLevel = math.min(self.blastCharge/20)

	if self.blastFireDelay then
		self.blastFireDelayCD = self.blastFireDelayCD + increase
		if self.blastFireDelayCD >= self.blastFireDelayCDMax then
			self.blastFireDelay = false
			self.blastFireDelayCD = 0
		end
	end

	if self.triggerDestroycd then
		self.triggerDestroyCD = self.triggerDestroyCD - dt
		if self.triggerDestroyCD <= 0 then
			self.triggerDestroyCD = 0.3
			self.triggerDestroycd = false
			if sm.exists(self.blastTrigger) then
				self.network:sendToServer("sv_destroyTrigger")
			end
		end
	end

	--Mod switch cooldown
	if self.afterModCD then
		if self.afterModCDCount < 1 then
			self.afterModCDCount = self.afterModCDCount + increase*1.75
		elseif self.afterModCDCount >= 1 then
			self.afterModCDCount = 1
			self.afterModCD = false
		end
	end
end

function PRifle:sv_beamAttack( args )
	sm.container.beginTransaction()
	sm.container.spend( self.player:getInventory(), se_ammo_plasma, 1, 1 )
	sm.container.endTransaction()

	if sm.exists(args.target) then
		if args.target:getCharacterType() ~= unit_mechanic then
			sm.event.sendToUnit( args.target:getUnit(), "sv_se_takeDamage", { damage = args.damage, impact = args.impact, hitPos = args.hitPos, attacker = args.attacker } )
			sm.event.sendToUnit( args.target:getUnit(), "sv_addStagger", 10 )
		end
	end
end

function PRifle:sv_blast( args )
	self.keepLevel = self.blastChargeLevel
	self.blastChargeLevel = 0
	self.blastCharge = 0
	--sm.physics.explode( pos, 3, 5, 6, 10, "PropaneTank - ExplosionSmall" )
	self.blastTrigger = sm.areaTrigger.createBox( args.size, args.pos, sm.quat.identity(), sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody )
	self.blastTrigger:bindOnStay( "sv_applyBlast" )
	self.triggerDestroycd = true
	self.network:sendToClients("cl_stopFX")
end

function PRifle:cl_stopFX()
	self.effect:stop()
end

function PRifle:sv_applyBlast( trigger, result )
	local damageMultiplier = 1
	for _, object in pairs(result) do
		local mass = object:getMass()/75
		local force
		if type(object) == "Body" then
			force = sm.vec3.new(1000, 1000, 1000) * self.lookDir * mass * self.keepLevel
			sm.physics.applyImpulse( object, force/mass )
		elseif object:getId() ~= self.playerChar:getId() then
			force = sm.vec3.new(1000 * self.lookDir.x, 1000 * self.lookDir.y, 450) * mass * self.keepLevel
			if object:getCharacterType() ~= sm.uuid.new("9f4fde94-312f-4417-b13b-84029c5d6b52") then
				damageMultiplier = 1
				sm.physics.applyImpulse( object, force )
			else
				damageMultiplier = 5
			end

			if object:getCharacterType() ~= unit_mechanic then
				sm.event.sendToUnit( object:getUnit(), "sv_se_takeDamage", { damage = blastDamage * self.keepLevel * damageMultiplier, impact = force / 1000, hitPos = object:getWorldPosition(), attacker = self.player } )
			end
		end
	end
	self.keepLevel = 0

	self:sv_destroyTrigger()
end

function PRifle:sv_destroyTrigger()
	sm.areaTrigger.destroy( self.blastTrigger )
end

function PRifle.shootProjectile( self, projectileType, projectileDamage)
	if self.tool:getOwner().character == nil then
		return
	end

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

	local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp( self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0 ) or 0.0 spreadFactor = clamp( self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0 )
	local spreadDeg =  fireMode.spreadMinAngle + ( fireMode.spreadMaxAngle - fireMode.spreadMinAngle ) * spreadFactor

	dir = sm.noise.gunSpread( dir, spreadDeg )

	local owner = self.tool:getOwner()
			
	if owner then
		sm.projectile.projectileAttack( projectileType, projectileDamage, firePos, sm.noise.gunSpread( dir, spreadDeg ) * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf )
	end 

	-- Send TP shoot over network and dircly to self
	self:onShoot( dir )
	self.network:sendToServer( "sv_n_onShoot", dir )

	-- Play FP shoot animation
	setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
end

function PRifle.client_onReload( self )
	if self.data.mod1.owned and self.data.mod2.owned then
		self.modSwitchCount = self.modSwitchCount + 1
		if self.modSwitchCount % 2 == 0 then
			self.currentWeaponMod = mod_blast
		else
			self.currentWeaponMod = mod_beam
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

function PRifle:sv_saveCurrentWpnData( data )
	sm.event.sendToPlayer( self.player, "sv_saveWPData", data )
end
--SE

function PRifle.client_onUpdate( self, dt )
	--SE
	self.playerChar = self.player:getCharacter()
	self.lookDir = sm.localPlayer.getDirection()
	self.playerPos = self.playerChar:getWorldPosition()

	local increase = dt * self.spdMult

	if self.beamTargets.target1 then
		--self.network:sendToServer("sv_getEnemyData", self.beamTargets.target1)
		self.targetData = sm.unitData[self.beamTargets.target1:getId()]
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
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0 or self.currentWeaponMod == mod_beam and self.usingMod
	self.tool:setBlockSprint( blockSprint )

	local playerDir = self.tool:getDirection()
	local angle = math.asin( playerDir:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )
	local linareAngle = playerDir:dot( sm.vec3.new( 0, 0, 1 ) )

	local linareAngleDown = clamp( -linareAngle, 0.0, 1.0 )

	down = clamp( -angle, 0.0, 1.0 )
	fwd = ( 1.0 - math.abs( angle ) )
	up = clamp( angle, 0.0, 1.0 )

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

function PRifle.client_onEquip( self, animate )
	--SE
	if self.currentWeaponMod ~= "poor" then
		sm.gui.displayAlertText("Current weapon mod: #ff9d00" .. self.currentWeaponMod, 2.5)
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

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )

	if self.tool:isLocal() then
		-- Sets PRifle renderable, change this to change the mesh
		self.tool:setFpRenderables( currentRenderablesFp )
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function PRifle.client_onUnequip( self, animate )

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

function PRifle.sv_n_onAim( self, aiming )
	self.network:sendToClients( "cl_n_onAim", aiming )
end

function PRifle.cl_n_onAim( self, aiming )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onAim( aiming )
	end
end

function PRifle.onAim( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function PRifle.sv_n_onShoot( self, dir )
	self.network:sendToClients( "cl_n_onShoot", dir )
end

function PRifle.cl_n_onShoot( self, dir )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onShoot( dir )
	end
end

function PRifle.onShoot( self, dir )

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

function PRifle.calculateFirePosition( self )
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

function PRifle.calculateTpMuzzlePos( self )
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

function PRifle.calculateFpMuzzlePos( self )
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

function PRifle.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end

	if state == sm.tool.interactState.start then

		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_plasma, 1 ) then
			local owner = self.tool:getOwner()

			if owner and self.currentWeaponMod == "poor" or owner and not self.usingMod and not self.afterModCD then
				if self.currentWeaponMod == mod_blast and not self.blastFireDelay or self.currentWeaponMod == mod_beam then
					self:shootProjectile( proj_plasma, self.Damage )

					if self.currentWeaponMod == mod_blast and self.blastCharge < 60 and not self.blastMasteryDmg then
						self.blastCharge = self.blastCharge + self.blastChargeIncrease
					end
				end
			end
		end
	end

	if state == sm.tool.interactState.stop then
		self.blastFireDelay = true
	end
end

function PRifle.cl_onSecondaryUse( self, state )
	if state == sm.tool.interactState.start and not self.usingMod --[[self.aiming]] then
		--SE
		self.usingMod = true

		if self.currentWeaponMod == mod_blast then
			if self.blastChargeLevel >= 1 then
				self.network:sendToServer("sv_blast", { pos = self.playerPos + (self.lookDir * 2.5), size = sm.vec3.new(2,2,2) })
				sm.audio.play( "Phaser" )
				self.effect:setPosition( self:calculateFirePosition())
				self.effect:setRotation( sm.vec3.getRotation( sm.vec3.new(0,0,1), self.lookDir ) )
				self.effect:start()

				if self.data.mod1.mastery.owned then
					self.blastMasteryDmg = true
					self.Damage = self.Damage + self.blastChargeLevel * 10
				end
			else
				sm.audio.play( "RaftShark" )
			end
		elseif self.currentWeaponMod == mod_beam then
			self.tool:setMovementSlowDown( true )
			self.beamCD = true
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

		self.tool:setMovementSlowDown( false )
		self.beamActivateCD = 0
		self.beamActivate = false
		self.beamCD = false
		self.beamTargets = { target1 = nil, target2 = nil }
		self.beamEffect:stop()
		--SE

		--[[self.aiming = false
		self.tpAnimations.animations.idle.time = 0

		self:onAim( self.aiming )
		self.tool:setMovementSlowDown( self.aiming )
		self.network:sendToServer( "sv_n_onAim", self.aiming )]]
	end
end

function PRifle.client_onEquippedUpdate( self, primaryState, secondaryState )
	--SE
	local data = {
		mod = self.currentWeaponMod,
		using = self.usingMod,
		ammo = 0,
		recharge = 0
	}
	self.network:sendToServer( "sv_saveCurrentWpnData", data )

    if self.afterModCD then
		sm.gui.setProgressFraction(self.afterModCDCount/1)
	end

	if self.currentWeaponMod == mod_blast and not self.afterModCD then
		sm.gui.setProgressFraction(self.blastChargeLevel/3)
	end

	if self.currentWeaponMod == mod_beam and self.usingMod and not self.beamTargets.target1 then
		sm.gui.setProgressFraction(self.beamActivateCD/self.beamActivateMax)
	elseif self.currentWeaponMod == mod_beam and self.usingMod and self.beamTargets.target1 then
		sm.gui.setProgressFraction(self.targetData.data.stats.hp/self.targetData.data.stats.maxhp)
	end

	self.isFiring = (primaryState == sm.tool.interactState.start or primaryState == sm.tool.interactState.hold) and true or false
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
