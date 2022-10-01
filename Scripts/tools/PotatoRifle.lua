dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

dofile "$CONTENT_DATA/Scripts/se_util.lua"

HCannon = class()

local effectRot = sm.vec3.new( 0, 1, 0 )
HCannon.mod1 = "Precision Bolt"
HCannon.mod2 = "Micro Missiles"
HCannon.renderables = {
	poor = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_basic/char_spudgun_barrel_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	["Precision Bolt"] = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_basic/char_spudgun_barrel_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	["Micro Missiles"] = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_basic/char_spudgun_barrel_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	}
}
HCannon.renderablesTp = {
	"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"
}
HCannon.renderablesFp = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"
}
HCannon.baseDamage = 20
HCannon.pbDamage = 168
HCannon.pbRange = 250

for k, v in pairs(HCannon.renderables) do
	sm.tool.preloadRenderables( v )
end
sm.tool.preloadRenderables( HCannon.renderablesTp )
sm.tool.preloadRenderables( HCannon.renderablesFp )

function HCannon:server_onCreate()
	self.sv = {}
	self.sv.owner = self.tool:getOwner()
	self.sv.data = self.sv.owner:getPublicData()
end

function HCannon.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunBasic - BasicMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunBasic - FPBasicMuzzel" )

	self.cl = {}
	self.cl.baseWeapon = BaseWeapon()
	self.cl.baseWeapon.cl_onCreate( self, "hcannon" )

	if not self.tool:isLocal() then return end

	self.cl.fireCounter = 0

	--mod1
	self.cl.fireCharge = 2

	--mod2
	self.cl.missiles = {}
	self.cl.microMissileCounter = 0
	self.cl.missileRecharge = 2.5
	self.cl.missileRechargeMax = 2.5
	self.cl.microMissileAmmo = 0
	self.cl.mmOP = nil
	self.cl.explosionDamage = 3
	self.cl.mmActiavteCD = 1
	self.cl.canFireMM = false

	self.cl.mmMasteryStick = 0
	self.cl.mmMCanProgress = true
end

function HCannon.loadAnimations( self )

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

function HCannon:server_onFixedUpdate()

end

function HCannon.client_onFixedUpdate( self, dt )
	if not self.tool:isLocal() then return end

	self.cl.baseWeapon.cl_onFixed( self )
	self.cl.mmOP = self.cl.ownerData.data.playerData.mmOP

	--upgrades

	self.cl.missileRechargeMax = self.cl.weaponData.mod2.up1.owned and 1.5 or 2.5
	self.cl.canFireMM = self.cl.weaponData.mod2.up2.owned or self.cl.mmActiavteCD >= 1
	self.cl.explosionDamage = self.cl.mmOP and 5 or 3

	local increase = dt * self.cl.powerups.speedMultiplier.current

	local char = self.cl.owner.character
	local inWater = char:isSwimming() or char:isDiving()
	if self.cl.isFiring and (self.cl.currentWeaponMod == "poor" or not self.cl.usingMod and not self.cl.modSwitch.active) and not inWater and self.tool:isEquipped() then
		self.cl.fireCounter = self.cl.fireCounter + increase
		if (self.cl.fireCounter/0.25) > 1 then
			if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), obj_plantables_potato, 1 ) then
				self:shootProjectile( projectile_potato, self.baseDamage * self.cl.powerups.damageMultiplier.current )
			else
				sm.audio.play( "PotatoRifle - NoAmmo" )
			end

			self.cl.fireCounter = 0
		end
	else
		self.cl.fireCounter = 0
	end

	if self.cl.currentWeaponMod == self.mod2 and self.cl.usingMod and not self.cl.modSwitch.active then
		self.cl.mmActiavteCD = sm.util.clamp(self.cl.mmActiavteCD + increase*2, 0, 1)
	else
		self.cl.mmActiavteCD = 0
	end

	if self.cl.currentWeaponMod == self.mod2 and self.cl.usingMod and not self.cl.modSwitch.active and self.cl.isFiring and self.cl.canFireMM and not inWater and self.tool:isEquipped()  then
		self.cl.microMissileCounter = self.cl.microMissileCounter + increase
		if (self.cl.microMissileCounter/0.25) > 1 then
			if (not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), obj_plantables_potato, 3 )) and self.cl.microMissileAmmo > 0 then
				local spreadAngleZ = math.random(-5,5)
				local spreadAngleY = math.random(-4,4)
				local aimDir = sm.localPlayer.getDirection()
				local dir = sm.vec3.rotate( aimDir, math.rad(spreadAngleZ), sm.camera.getUp() )
				dir = sm.vec3.rotate( dir, math.rad(spreadAngleY), sm.camera.getRight() )

				self:cl_shootMissile({ pos = self:calculateFirePosition() + aimDir * 0.5, dir = dir })
				if not self.cl.weaponData.mod2.mastery.owned then
					self.cl.microMissileAmmo = self.cl.microMissileAmmo - 1
				end

				self:onShoot( dir )
				self.network:sendToServer( "sv_n_onShoot", dir )
				setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
			else
				sm.audio.play( "PotatoRifle - NoAmmo" )
			end

			self.cl.microMissileCounter = 0
		end
	else
		self.cl.microMissileCounter = 0
	end

	if sm.container.canSpend( sm.localPlayer.getInventory(), obj_plantables_potato, 3 * (self.cl.microMissileAmmo + 1) ) then
		if self.cl.microMissileAmmo < 12 and (self.cl.currentWeaponMod ~= self.mod2 or not self.cl.isFiring) then
			if self.cl.missileRecharge < self.cl.missileRechargeMax then
				self.cl.missileRecharge = self.cl.missileRecharge + increase
			else
				self.cl.microMissileAmmo = self.cl.microMissileAmmo + 1
				self.cl.missileRecharge = 0
			end
		end
	end

	--Volley recharged, can progress
	if self.cl.microMissileAmmo == 12 then
		self.cl.mmMCanProgress = true
	end

	if self.cl.weaponData.mod2.up1.owned and self.cl.weaponData.mod2.up2.owned and self.cl.weaponData.mod2.up3.owned and not self.cl.weaponData.mod2.mastery.owned and self.cl.mmMCanProgress then
		if self.cl.microMissileAmmo > 0 then
			if self.cl.mmMasteryStick >= 3 then
				self.cl.mmMasteryStick = 0
				self.cl.mmMCanProgress = false
				self.network:sendToServer("sv_saveMMMastery")
			end
		else
			self.cl.mmMCanProgress = false
			self.cl.mmMasteryStick = 0
		end
	end

	if self.cl.fireCharge < 2 then
		local mult = self.cl.weaponData.mod1.up2.owned and 2 or 1
		self.cl.fireCharge = sm.util.clamp(self.cl.fireCharge + increase * mult, 0, 2)
	end
end

function HCannon:cl_shootMissile( args )
	local missile = {}

	missile = {effect = sm.effect.createEffect("Rocket"), pos = args.pos, dir = args.dir, lifeTime = 0, explodeCD = 0, exploded = false, attached = false, attachedTarget = nil, attachPos = sm.vec3.zero(), attachDir = sm.vec3.zero()}

	missile.effect:setPosition( args.pos )
	missile.effect:setRotation( sm.vec3.getRotation( effectRot, args.dir ) )
	missile.effect:start()

	table.insert(self.cl.missiles, missile)
	self.network:sendToServer("sv_shootMissile")
end

function HCannon:sv_shootMissile()
	sm.container.beginTransaction()
	sm.container.spend( self.cl.owner:getInventory(), obj_plantables_potato, 3, true )
	sm.container.endTransaction()
end

function HCannon.client_onReload( self )
	self.cl.baseWeapon.onModSwitch( self )

	return true
end

function HCannon.shootProjectile( self, projectileType, projectileDamage)
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

    self:onShoot( dir )
    self.network:sendToServer( "sv_n_onShoot", dir )
    setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
end

function HCannon:sv_missileExplode( pos )
	sm.physics.explode( pos, self.cl.explosionDamage, 2.5, 2.0, 7.5, "PropaneTank - ExplosionSmall" )
end

function HCannon:sv_onPBHit( args )
	local unit = args.char:getUnit()

	sm.event.sendToUnit(
		unit,
		"sv_se_takeDamage",
		{
			damage = self.pbDamage,
			impact = sm.vec3.one(),
			hitPos = args.hitPos,
			attacker = self.sv.owner
		}
	)
	sm.event.sendToUnit(
		unit,
		"sv_checkWeakPoints",
		{
			hitPos = args.hitPos,
			attacker = self.sv.owner
		}
	)
end

function HCannon:sv_saveMMMastery()
	self.sv.data.weaponData.hcannon.mod2.mastery.progress = self.sv.data.weaponData.hcannon.mod2.mastery.progress + 1

	local mastery = self.sv.data.weaponData.hcannon.mod2.mastery
	if mastery.progress >= mastery.max then
		sm.event.sendToPlayer( self.sv.owner, "sv_displayMsg", "#ff9d00"..mastery.name.." #ffffffunlocked!" )
		self.sv.data.weaponData.hcannon.mod2.mastery = true
	end

	sm.event.sendToPlayer(self.sv.owner, "sv_save")
end

function HCannon.client_onUpdate( self, dt )
	local missileInc = self.cl.mmOP and dt * 2 or dt
	local increase = dt * self.tool:getOwner():getClientPublicData().powerup.speedMultiplier.current
	local fpsAdjust = dt * 50

	for tablePos, missile in pairs(self.cl.missiles) do
		if missile.lifeTime >= 15 or missile.exploded then
			missile.effect:stop()
			if missile.exploded then
				self.network:sendToServer("sv_missileExplode", missile.pos)
			end

			table.remove(self.cl.missiles,tablePos)
		elseif missile.attached then
			missile.explodeCD = missile.explodeCD + missileInc

			if missile.explodeCD >= 2 then
				missile.exploded = true
			end

			if missile.attachedTarget and sm.exists(missile.attachedTarget) then
				local newPos
				local rot
				if type(missile.attachedTarget) == "Shape" then
					rot = missile.attachedTarget.worldRotation
				elseif type(missile.attachedTarget) == "Character" then
					rot = missile.attachedTarget:getDirection()
				end

				newPos = missile.attachedTarget:getWorldPosition() + rot * missile.attachPos
				missile.effect:setRotation( sm.vec3.getRotation( effectRot, rot * missile.attachDir ) )
				missile.pos = newPos
				missile.effect:setPosition( newPos )
			elseif missile.attachedTarget and not sm.exists(missile.attachedTarget) then
				missile.attached = false
				missile.attachedTarget = nil
				--missile.explodeCD = 69420 --explodes the missile
			end
		else
			if missile.dir.z > -1 then
				missile.dir = missile.dir - sm.vec3.new(0, 0, 0.005)
			end
			local hit, result = sm.physics.raycast( missile.pos, missile.pos + missile.dir * 0.6 * fpsAdjust )
			if hit then
				local object 
				local type = result.type
				if type == "character" then
					object = result:getCharacter()
					missile.attachedTarget = object
					missile.attachPos = missile.pos - object:getWorldPosition()

					self.cl.mmMasteryStick = self.cl.mmMasteryStick + 1
				elseif type == "body" then
					object = result:getShape()
					missile.attachedTarget = object
					missile.attachPos = missile.pos - object:getWorldPosition()
				end
				missile.attachDir = missile.dir
				missile.attached = true
			end

			missile.lifeTime = missile.lifeTime + dt
			local newPos = missile.pos + sm.vec3.new(0.5,0.5,0.5) * missile.dir * fpsAdjust
			missile.pos = newPos
			missile.effect:setPosition( newPos )
			missile.effect:setRotation( sm.vec3.getRotation(effectRot, missile.dir) )
		end
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

function HCannon.client_onEquip( self, animate )
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

function HCannon.client_onUnequip( self, animate )
	if animate then
		sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
	end

	self.cl.fireCharge = 2
	self.wantEquipped = false
	self.equipped = false
	setTpAnimation( self.tpAnimations, "putdown" )
	if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
		swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
	end
end

function HCannon.sv_n_onAim( self, aiming )
	self.network:sendToClients( "cl_n_onAim", aiming )
end

function HCannon.cl_n_onAim( self, aiming )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onAim( aiming )
	end
end

function HCannon.onAim( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function HCannon.sv_n_onShoot( self, dir )
	self.network:sendToClients( "cl_n_onShoot", dir )
end

function HCannon.cl_n_onShoot( self, dir )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onShoot( dir )
	end
end

function HCannon.onShoot( self, dir )
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0
	self.tpAnimations.animations.aimShoot.time = 0

	setTpAnimation( self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0 )

	if self.tool:isInFirstPersonView() then
		if self.cl.modSwitch.active or self.cl.usingMod and self.cl.fireCharge < 2 and self.cl.currentWeaponMod == self.mod1 or self.cl.usingMod and self.cl.microMissileAmmo == 0 and self.cl.currentWeaponMod == self.mod2 or self.cl.usingMod and not self.cl.canFireMM and self.cl.currentWeaponMod == self.mod2 then
			sm.audio.play( "PotatoRifle - NoAmmo" )
		else
			self.shootEffectFP:start()
		end
	else
		if self.cl.modSwitch.active or self.cl.usingMod and self.cl.fireCharge < 2 and self.cl.currentWeaponMod == self.mod1 or self.cl.usingMod and self.cl.microMissileAmmo == 0 and self.cl.currentWeaponMod == self.mod2 or self.cl.usingMod and not self.cl.canFireMM and self.cl.currentWeaponMod == self.mod2 then
			sm.audio.play( "PotatoRifle - NoAmmo" )
		else
			self.shootEffect:start()
		end
	end
end

function HCannon.calculateFirePosition( self )
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

function HCannon.calculateTpMuzzlePos( self )
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

function HCannon.calculateFpMuzzlePos( self )
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

function HCannon.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end

	if self.fireCooldownTimer <= 0.0 and state == sm.tool.interactState.start then
		local ammoCost = 1
		if self.cl.usingMod and self.cl.currentWeaponMod == self.mod1 then
			ammoCost = 6
		elseif self.cl.usingMod and self.cl.currentWeaponMod == self.mod2 then
			ammoCost = 3
		end

		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), obj_plantables_potato, ammoCost ) then

			local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
			local owner = self.tool:getOwner()

			if owner and not self.cl.usingMod and not self.cl.modSwitch.active or owner and self.cl.currentWeaponMod == "poor" then
				self.aimFireMode.fireVelocity = 130
				self.aimFireMode.spreadIncrement = 1.3
				self.aimFireMode.spreadMinAngle = 0
				self.aimFireMode.spreadMaxAngle = 8

				self:shootProjectile( projectile_potato, self.baseDamage * self.cl.powerups.damageMultiplier.current )
			elseif owner and self.cl.usingMod and self.cl.currentWeaponMod == self.mod1 and not self.cl.modSwitch.active and self.cl.fireCharge == 2  then
				--[[self.aimFireMode.fireVelocity =  130
				self.aimFireMode.spreadIncrement = 0
				self.aimFireMode.spreadMinAngle = 0
				self.aimFireMode.spreadMaxAngle = 0

				self:shootProjectile( proj_pb, self.pbDamage * self.cl.powerups.damageMultiplier.current )]]

				local hit, result = sm.localPlayer.getRaycast(self.pbRange)
				if hit then
					local char = result:getCharacter()
					if char then
						self.network:sendToServer("sv_onPBHit", { char = char, hitPos = result.pointWorld })
					end
				end

				self.cl.fireCharge = 0

				self:onShoot()
				self.network:sendToServer( "sv_n_onShoot" )
				setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )
			elseif owner and self.cl.usingMod and self.cl.currentWeaponMod == self.mod2 and not self.cl.modSwitch.active and self.cl.microMissileAmmo > 0 and self.cl.canFireMM then
				local dir = sm.localPlayer.getDirection()
				self:cl_shootMissile({ pos = self:calculateFirePosition() + dir, dir = dir })

				if not self.cl.weaponData.mod2.mastery.owned then
					self.cl.microMissileAmmo = self.cl.microMissileAmmo - 1
				end
				self.cl.missileRecharge = 0

				self:onShoot()
				self.network:sendToServer( "sv_n_onShoot" )
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

function HCannon.cl_onSecondaryUse( self, state )
	if self.cl.currentWeaponMod == self.mod2 then return end

	self.aiming = state == sm.tool.interactState.start or state == sm.tool.interactState.hold

	self.tpAnimations.animations.idle.time = 0
	self:onAim( self.aiming )
	if not self.cl.weaponData.mod1.up1.owned or self.cl.currentWeaponMod == "poor" then
		self.tool:setMovementSlowDown( self.aiming )
	end
	self.network:sendToServer( "sv_n_onAim", self.aiming )
end

function HCannon.client_onEquippedUpdate( self, primaryState, secondaryState )
	self.cl.baseWeapon.onEquipped( self, primaryState, secondaryState )

	if self.cl.currentWeaponMod == self.mod1 and self.cl.usingMod then
		sm.gui.setProgressFraction(self.cl.fireCharge / 2)
	elseif self.cl.currentWeaponMod == self.mod2 and self.cl.usingMod then
		if self.cl.canFireMM then
			sm.gui.setProgressFraction(self.cl.microMissileAmmo / 12)
		else
			sm.gui.setProgressFraction(self.cl.mmActiavteCD)
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
