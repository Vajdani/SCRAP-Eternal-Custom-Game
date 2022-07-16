dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

dofile "$CONTENT_DATA/Scripts/se_util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"

PotatoShotgun = class()

PotatoShotgun.mod1 = "Sticky Bombs"
PotatoShotgun.mod2 = "Full Auto"
PotatoShotgun.renderables = {
	poor = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_frier/char_spudgun_barrel_frier.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	["Sticky Bombs"] = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_frier/char_spudgun_barrel_frier.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	["Full Auto"] = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_frier/char_spudgun_barrel_frier.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	}
}
PotatoShotgun.renderablesTp = {
	"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"
}
PotatoShotgun.renderablesFp = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"
}
PotatoShotgun.baseDamage = 24

for k, v in pairs(PotatoShotgun.renderables) do
	sm.tool.preloadRenderables( v )
end
sm.tool.preloadRenderables( PotatoShotgun.renderablesTp )
sm.tool.preloadRenderables( PotatoShotgun.renderablesFp )

function PotatoShotgun.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunFrier - FrierMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunFrier - FPFrierMuzzel" )

	self.cl = {}
	self.cl.baseWeapon = BaseWeapon()
	self.cl.baseWeapon.cl_onCreate( self, "shotgun" )

	if not self.tool:isLocal() then return end

	--mod1
	self.cl.sticky = {}
	self.cl.sticky.ammo = 3
	self.cl.sticky.ammoMax = 3
	self.cl.sticky.recharge = 5
	self.cl.sticky.rechargeMax = 8

	--mod2
	self.cl.auto = {}
	self.cl.auto.counter = 0
	self.cl.auto.windUp = 1
	self.cl.auto.windUpMax = 1
	self.cl.auto.windingDown = false
	self.cl.auto.windDown = 1.25
	self.cl.auto.windDownMax = 1.25
	self.cl.auto.canUse = false
end



function PotatoShotgun.client_onRefresh( self )
	self:loadAnimations()
end

function PotatoShotgun.loadAnimations( self )

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
		fireCooldown = 0.5,
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
		fireCooldown = 0.5,
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


function PotatoShotgun.client_onFixedUpdate( self, dt )
	if not self.tool:isLocal() or not self.tool:isEquipped() then return end

	self.cl.baseWeapon.cl_onFixed( self )

	--upgrades
	self.cl.sticky.rechargeMax = self.cl.weaponData.mod1.up1.owned and 6.4 or 8
	self.cl.sticky.ammoMax = self.cl.weaponData.mod1.mastery.owned and 5 or 3
	self.cl.auto.windUpMax = self.cl.weaponData.mod2.up1.owned and 0.75 or 1
	self.cl.auto.windDownMax = self.cl.weaponData.mod2.up2.owned and 0.9 or 1.25

	--powerup
	local increase = dt * self.cl.powerups.speedMultiplier.current

	local playerChar = self.cl.owner.character
	if self.cl.currentWeaponMod == self.mod2 and self.cl.usingMod and not self.cl.modSwitch.active and self.cl.auto.canUse and not self.cl.auto.windingDown and self.cl.isFiring and not playerChar:isSwimming() and not playerChar:isDiving() and self.tool:isEquipped() then
		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_shells, 1 ) then
			self.cl.auto.counter = self.cl.auto.counter + increase
			if (self.cl.auto.counter/0.25) > 1 then
				self:shootProjectile(proj_csg, self.baseDamage * self.cl.powerups.damageMultiplier.current)
			end

			if self.cl.auto.counter > 0.25 then
				self.cl.auto.counter = 0
			end
		else
			sm.audio.play( "PotatoRifle - NoAmmo" )
		end
	else
		self.cl.auto.counter = 0
	end

	if self.cl.currentWeaponMod == self.mod2 then
		if self.cl.usingMod and not self.cl.modSwitch.active then
			if self.cl.auto.windUp < self.cl.auto.windUpMax then
				self.cl.auto.windUp = self.cl.auto.windUp + increase*2
			else
				self.cl.auto.windUp = self.cl.auto.windUpMax
				self.cl.auto.canUse = true
			end
		else
			self.cl.auto.canUse = false
		end

		if self.cl.auto.windingDown then
			if self.cl.auto.windDown < self.cl.auto.windDownMax then
				self.cl.auto.windDown = self.cl.auto.windDown + increase*2
			else
				self.cl.auto.windDown = self.cl.auto.windDownMax
				self.cl.auto.windingDown = false
				sm.tool.forceTool( nil )
			end
		end
	end

	if self.cl.sticky.ammo < self.cl.sticky.ammoMax or self.cl.sticky.ammo < self.cl.sticky.ammoMax and self.cl.currentWeaponMod == self.mod2 then
		if self.fireCooldownTimer <= 0.0 or self.cl.sticky.ammo == 0 then
			if self.cl.sticky.recharge < self.cl.sticky.rechargeMax and self.cl.sticky.ammo < 5 then
				self.cl.sticky.recharge = self.cl.sticky.recharge + increase
			end

			if (self.cl.sticky.recharge/self.cl.sticky.rechargeMax) >= 1 then
				self.cl.sticky.ammo = self.cl.sticky.ammo + 1
				self.cl.sticky.recharge = 0
			end
		end
	end
end

function PotatoShotgun:sv_shootBomb( args )
	sm.container.beginTransaction()
	sm.container.spend( args.owner:getInventory(), se_ammo_shells, 1, true )
	sm.container.endTransaction()

	args.spawnTick = sm.game.getServerTick()
	sm.scriptableObject.createScriptableObject(
		proj_stickyBomb_sob,
		args,
		args.owner:getCharacter():getWorld()
	)
end

function PotatoShotgun.client_onReload( self )
	if self.cl.auto.windingDown then return true end
	self.cl.baseWeapon.onModSwitch( self )

	return true
end

function PotatoShotgun:shootProjectile( projectileType, projectileDamage )
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
		sm.projectile.projectileAttack( projectileType, projectileDamage, firePos, dir * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf )
	end

	-- Send TP shoot over network and dircly to self
	self:onShoot( dir )
	self.network:sendToServer( "sv_n_onShoot", dir )

	-- Play FP shoot animation
	setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
end

function PotatoShotgun:sv_farmbotCannonCheck( args )
	sm.event.sendToUnit(args.unit, "sv_checkBombPos", { pos = args.pos, attacker = args.attacker } )
end


function PotatoShotgun.client_onUpdate( self, dt )
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

function PotatoShotgun.client_onEquip( self, animate )
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
		-- Sets PotatoRifle renderable, change this to change the mesh
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function PotatoShotgun.client_onUnequip( self, animate )
	if animate then
		sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
	end

	self.cl.usingMod = false
	self.wantEquipped = false
	self.equipped = false
	setTpAnimation( self.tpAnimations, "putdown" )
	if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
		swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
	end
end

function PotatoShotgun.sv_n_onAim( self, aiming )
	self.network:sendToClients( "cl_n_onAim", aiming )
end

function PotatoShotgun.cl_n_onAim( self, aiming )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onAim( aiming )
	end
end

function PotatoShotgun.onAim( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function PotatoShotgun.sv_n_onShoot( self, dir )
	self.network:sendToClients( "cl_n_onShoot", dir )
end

function PotatoShotgun.cl_n_onShoot( self, dir )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onShoot( dir )
	end
end

function PotatoShotgun.onShoot( self, dir )
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0
	self.tpAnimations.animations.aimShoot.time = 0

	setTpAnimation( self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0 )

	if self.tool:isInFirstPersonView() then
		if self.cl.usingMod and self.cl.sticky.ammo == 0 and self.cl.currentWeaponMod == self.mod1 or self.cl.modSwitch.active or self.cl.usingMod and self.cl.currentWeaponMod == self.mod2 and not self.cl.auto.canUse then
			sm.audio.play( "PotatoRifle - NoAmmo" )
		else
			self.shootEffectFP:start()
		end
	else
		if self.cl.usingMod and self.cl.sticky.ammo == 0 and self.cl.currentWeaponMod == self.mod1 or self.cl.modSwitch.active or self.cl.usingMod and self.cl.currentWeaponMod == self.mod2 and not self.cl.auto.canUse then
			sm.audio.play( "PotatoRifle - NoAmmo" )
		else
			self.shootEffect:start()
		end
	end
end

function PotatoShotgun.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil or self.cl.modSwitch.active or (self.cl.currentWeaponMod == self.mod2 and self.cl.usingMod and not self.cl.auto.canUse) or self.cl.auto.windingDown then
		return
	end

	if self.fireCooldownTimer <= 0.0 and state == sm.tool.interactState.start then
		local cost = self.cl.usingMod and self.cl.currentWeaponMod == self.mod1 and 5 or 1
		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_shells, cost ) then

			local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
			local dir = sm.localPlayer.getDirection()
			local owner = self.tool:getOwner()

			if not owner then return end

			if not self.cl.usingMod or isAnyOf(self.cl.currentWeaponMod, { "poor", self.mod2 }) then
				self:shootProjectile( proj_csg, self.baseDamage * self.cl.powerups.damageMultiplier.current )
			elseif self.cl.currentWeaponMod == self.mod1 and self.cl.sticky.ammo > 0 then
				self.network:sendToServer("sv_shootBomb",
						{
							pos = self:calculateFirePosition(),
							dir = dir,
							owner = owner
						}
					)

				self.cl.sticky.ammo = self.cl.sticky.ammo - 1

				-- Send TP shoot over network and dircly to self
				self:onShoot( dir )
				self.network:sendToServer( "sv_n_onShoot", dir )

				-- Play FP shoot animation
				setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
			end

			-- Timers
			self.fireCooldownTimer = fireMode.fireCooldown
			self.spreadCooldownTimer = math.min( self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown )
			self.sprintCooldownTimer = self.sprintCooldown
		else
			local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
			self.fireCooldownTimer = fireMode.fireCooldown
			sm.audio.play( "PotatoRifle - NoAmmo" )
		end
	end
end

function PotatoShotgun.cl_onSecondaryUse( self, state )
	--self.aiming = state == sm.tool.interactState.start or state == sm.tool.interactState.hold
	--self.tpAnimations.animations.idle.time = 0
	--self:onAim( self.cl.usingMod )
	if self.cl.currentWeaponMod == self.mod2 then
		if not self.cl.weaponData.mod2.up3.owned then
			self.tool:setMovementSlowDown( self.cl.usingMod )
		end

		if state == sm.tool.interactState.stop then
			self.cl.auto.windDown = 0
			self.cl.auto.windingDown = true
			sm.tool.forceTool( self.tool )
		end
	end
	--self.network:sendToServer( "sv_n_onAim", self.cl.usingMod )

	if self.cl.currentWeaponMod == self.mod2 then
		self.cl.auto.windUp = 0
	end
end

function PotatoShotgun.client_onEquippedUpdate( self, primaryState, secondaryState )
	self.cl.baseWeapon.onEquipped( self, primaryState, secondaryState )

	if self.cl.currentWeaponMod == self.mod1 then
		if not self.cl.modSwitch.active then
			sm.gui.setProgressFraction(self.cl.sticky.ammo/self.cl.sticky.ammoMax)
		end
	else
		if not self.cl.auto.canUse and self.cl.usingMod then
			sm.gui.setProgressFraction(self.cl.auto.windUp/self.cl.auto.windUpMax)
		elseif self.cl.auto.windingDown then
			sm.gui.setProgressFraction(self.cl.auto.windDown/self.cl.auto.windDownMax)
		end
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
