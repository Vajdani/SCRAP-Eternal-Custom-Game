dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

dofile "$CONTENT_DATA/Scripts/tools/BaseWeapon.lua"

Ballista = class()
Ballista.mod1 = "Arbalest"
Ballista.mod2 = "Destroyer Blade"
Ballista.renderables = {
	poor = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_basic/char_spudgun_barrel_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	Arbalest = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_frier/char_spudgun_barrel_frier.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	["Destroyer Blade"] = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_spinner/char_spudgun_barrel_spinner.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_spinner/char_spudgun_sight_spinner.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	}
}
Ballista.renderablesTp = {
	"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"
}
Ballista.renderablesFp = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"
}
Ballista.visualiseFireCooldown = true
Ballista.baseDamage = 100
Ballista.ammoCosts = {
	[0] = 25,
	[1] = 16,
	[2] = 33,
	[3] = 50,
}

for k, v in pairs(Ballista.renderables) do
	sm.tool.preloadRenderables( v )
end
sm.tool.preloadRenderables( Ballista.renderablesTp )
sm.tool.preloadRenderables( Ballista.renderablesFp )

function Ballista:server_onCreate()
	self.sv = {}
	self.sv.owner = self.tool:getOwner()
	self.sv.bladeFalterTrigger = sm.areaTrigger.createSphere( 2.5, self.sv.owner.character.worldPosition, sm.quat.identity(), sm.areaTrigger.filter.character )
end

function Ballista:server_onFixedUpdate( dt )
	self.sv.bladeFalterTrigger:setWorldPosition( self.sv.owner.character.worldPosition )
end

function Ballista:sv_shootBlade( args )
	sm.container.beginTransaction()
	sm.container.spend( args.owner:getInventory(), se_ammo_plasma, args.ammoCost, true )
	sm.container.endTransaction()

	args.spawnTick = sm.game.getServerTick()
	sm.scriptableObject.createScriptableObject(
		proj_blade_sob,
		args,
		args.owner:getCharacter():getWorld()
	)
end

function Ballista:sv_bladeFalter()
	for pos, char in pairs(self.sv.bladeFalterTrigger:getContents()) do
		if sm.exists(char) and not char:isPlayer() then
			local unit = char:getUnit()
			if sm.exists(unit) then
				sm.event.sendToUnit( char:getUnit(), "sv_addStagger", 1 )
			end
		end
	end
end

function Ballista:sv_shootDart( args )
	sm.container.beginTransaction()
	sm.container.spend( args.owner:getInventory(), se_ammo_plasma, args.ammoCost, true )
	sm.container.endTransaction()

	args.spawnTick = sm.game.getServerTick()
	sm.scriptableObject.createScriptableObject(
		proj_arbalest_sob,
		args,
		args.owner:getCharacter():getWorld()
	)
end

function Ballista:sv_knockback()
	local char = self.sv.owner.character
	sm.physics.applyImpulse( char, -char.direction * 300 )
end



function Ballista.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunBasic - BasicMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunBasic - FPBasicMuzzel" )

	self.cl = {}
	self.cl.baseWeapon = BaseWeapon()
	self.cl.baseWeapon.cl_onCreate( self, "ballista" )

	if not self.tool:isLocal() then return end

	--mod1
	self.cl.arbalestCharge = 0

	--mod2
	self.cl.bladeMastery = false
	self.cl.bladeChargeMax = 3.6
	self.cl.bladeCharge = 0
end

function Ballista.client_onRefresh( self )
	self:loadAnimations()
end

function Ballista.loadAnimations( self )

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
		fireCooldown = 2,
		spreadCooldown = 0.18,
		spreadIncrement = 2.6,
		spreadMinAngle = .25,
		spreadMaxAngle = 8,
		fireVelocity = 250.0,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.aimFireMode = {
		fireCooldown = 2,
		spreadCooldown = 0.18,
		spreadIncrement = 1.3,
		spreadMinAngle = 0,
		spreadMaxAngle = 8,
		fireVelocity =  250.0,

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

function Ballista:client_onFixedUpdate( dt )
	if not self.tool:isLocal() then return end

	self.cl.baseWeapon.cl_onFixed( self )

	self.dmgMult = 1 --playerData.damageMultiplier

	--upgrades
	self.cl.bladeChargeMax = self.cl.weaponData.mod2.up2.owned and 3 or 3.6
	self.cl.bladeMastery = self.cl.weaponData.mod2.mastery.owned

	local increase = dt * self.cl.powerups.speedMultiplier.current

	--self.mod1
	if not self.cl.modSwitch.active and self.cl.usingMod and self.fireCooldownTimer <= 0.0 then
		if self.cl.currentWeaponMod == self.mod1 then
			self.cl.arbalestCharge = self.cl.arbalestCharge + increase
			if self.cl.arbalestCharge >= 3 then
				self.cl.arbalestCharge = 3
			end
		elseif self.cl.currentWeaponMod == self.mod2 and self.cl.bladeCharge ~= self.cl.bladeChargeMax then
			self.cl.bladeCharge = sm.util.clamp(self.cl.bladeCharge + increase, 0, self.cl.bladeChargeMax)

			if self.cl.bladeCharge == self.cl.bladeChargeMax and self.cl.weaponData.mod2.up1.owned then
				self.network:sendToServer("sv_bladeFalter")
			end
		end
	elseif not self.cl.usingMod then
		self.cl.bladeCharge = 0
		self.cl.arbalestCharge = 0
	end

end

function Ballista:cl_resetFireCooldown()
	self.fireCooldownTimer = 0
	self.spreadCooldownTimer = 0
	self.sprintCooldownTimer = 0
end

function Ballista:client_onReload()
	self.cl.baseWeapon.onModSwitch( self )

	return true
end

function Ballista.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil or self.cl.modSwitch.active then
		return
	end

	if self.fireCooldownTimer <= 0.0 and state == sm.tool.interactState.start then
		local bladeLevel = math.floor(self.cl.bladeCharge)
		local ammoCost = self.ammoCosts[bladeLevel]

		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_plasma, ammoCost ) then
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
				local validBlade = (self.cl.bladeMastery and bladeLevel > 0 or bladeLevel == 3 ) or not self.cl.usingMod
				if not self.cl.usingMod then
					sm.projectile.projectileAttack(
						proj_ballista,
						self.baseDamage * self.dmgMult,
						firePos,
						dir * fireMode.fireVelocity,
						owner,
						fakePosition,
						fakePositionSelf
					)
					self.network:sendToServer("sv_knockback")
				elseif self.cl.currentWeaponMod == self.mod1 then
					self.network:sendToServer("sv_shootDart",
						{
							pos = firePos,
							dir = dir,
							owner = owner,
							ownerTool = self.tool,
							ammoCost = ammoCost,
							rot = sm.camera.getRotation()
						}
					)

					self.cl.arbalestCharge = 0
				elseif self.cl.currentWeaponMod == self.mod2 and validBlade then
					self.network:sendToServer("sv_shootBlade",
						{
							pos = firePos,
							dir = dir,
							owner = owner,
							level = bladeLevel,
							ammoCost = ammoCost,
							rot = sm.camera.getRotation()
						}
					)

					self.cl.bladeCharge = 0
				end

				if self.cl.currentWeaponMod ~= self.mod2 or validBlade then
					self.fireCooldownTimer = fireMode.fireCooldown
					self.spreadCooldownTimer = math.min( self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown )
					self.sprintCooldownTimer = self.sprintCooldown

					-- Send TP shoot over network and dircly to self
					self:onShoot( dir )
					self.network:sendToServer( "sv_n_onShoot", dir )

					-- Play FP shoot animation
					setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
				end
			end
		else
			local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
			self.fireCooldownTimer = fireMode.fireCooldown
			sm.audio.play( "PotatoRifle - NoAmmo" )
		end
	end
end


function Ballista.client_onUpdate( self, dt )
	local increase = dt * self.cl.powerups.speedMultiplier.current

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

function Ballista.client_onEquip( self, animate )
	if self.cl.currentWeaponMod ~= "poor" then
		sm.gui.displayAlertText("Current weapon mod: #ff9d00" .. self.cl.currentWeaponMod, 2.5)
	end

	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

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

function Ballista.client_onUnequip( self, animate )

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

function Ballista.cl_onSecondaryUse( self, state )
	local prevAim = self.aiming
	self.aiming = state == sm.tool.interactState.start or state == sm.tool.interactState.hold

	if prevAim ~= self.aiming then
		self.tpAnimations.animations.idle.time = 0

		self:onAim( self.aiming )
		if self.cl.currentWeaponMod == self.mod2 or not self.cl.weaponData.mod1.up1.owned then
			self.tool:setMovementSlowDown( self.aiming )
		end
		self.network:sendToServer( "sv_n_onAim", self.aiming )
	end
end

function Ballista.client_onEquippedUpdate( self, primaryState, secondaryState )
	self.cl.baseWeapon.onEquipped( self, primaryState, secondaryState )

	if self.cl.usingMod and self.cl.currentWeaponMod == self.mod1 then
		sm.gui.setProgressFraction(self.cl.arbalestCharge/3)
	elseif self.cl.usingMod and self.cl.currentWeaponMod == self.mod2 then
		local percent = self.cl.bladeCharge/self.cl.bladeChargeMax
		sm.gui.setProgressFraction(self.cl.bladeMastery and math.floor(percent*3) / 3 or percent)
	end

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
