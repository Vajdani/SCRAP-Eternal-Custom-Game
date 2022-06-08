dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

local mod_sticky = "Sticky Bombs"
local mod_auto = "Full Auto"
local bombVel = sm.vec3.new(0.6,0.6,0.6)
local effectRot = sm.vec3.new( 0, 1, 0 )

PotatoShotgun = class()

local renderables = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_frier/char_spudgun_barrel_frier.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
}

local renderablesTp = {"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend", "$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"}
local renderablesFp = {"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function PotatoShotgun.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunFrier - FrierMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunFrier - FPFrierMuzzel" )

	--SE

	--General stuff
	self.windupEffect = sm.effect.createEffect( "SpudgunSpinner - Windup" )
	self.player = sm.localPlayer.getPlayer()
	self.playerChar = self.player:getCharacter()

	self.data = sm.playerInfo[self.player:getId()].weaponData.shotgun

	self.Damage = 24
	self.ammoCost = 1
	self.isFiring = false
	self.usingMod = false

	--Mod switch
	if self.data.mod1.owned then
		self.currentWeaponMod = mod_sticky
	elseif self.data.mod2.owned then
		self.currentWeaponMod = mod_auto
	else
		self.currentWeaponMod = "poor"
	end

	self.modSwitchCount = 0
	self.afterModCD = false
	self.afterModCDCount = 1

	--mod_sticky
	self.stickyBombAmmo = 3
	self.stickyBombAmmoMax = 3
	self.stickyReCharge = 8
	self.stickyReChargeMax = 8
	self.explosionRadius = 5

	self.bombs = {}

	--mod_auto
	self.fullAutoCounter = 0
	self.faMobility = false
	self.faWindUp = 1
	self.faWindUpMax = 1
	self.faWindDown = 1.25
	self.faWindDownMax = 1.25
	self.canUseFA = false
	--SE
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

--SE
function PotatoShotgun.client_onFixedUpdate( self, dt )
	self.playerChar = self.player:getCharacter()

	local playerData = sm.playerInfo[self.player:getId()].playerData
	self.data = sm.playerInfo[self.player:getId()].weaponData.shotgun
	self.dmgMult = playerData.damageMultiplier
	self.spdMult = playerData.speedMultiplier

	--fuck off
	if self.fireCooldownTimer == nil then
		self.fireCooldownTimer = 0
	end

	--upgrades
	self.stickyReChargeMax = self.data.mod1.up1.owned and 6.4 or 8
	self.explosionRadius = self.data.mod1.up2.owned and 7.25 or 5
	self.stickyBombAmmoMax = self.data.mod1.mastery.owned and 5 or 3
	self.faWindUpMax = self.data.mod2.up1.owned and 0.75 or 1
	self.faWindDownMax = self.data.mod2.up2.owned and 0.9 or 1.25
	self.faMobility = self.data.mod2.up3.owned and true or false

	--powerup
	local increase = dt * self.spdMult
	self.Damage = 24 --nice fix there bro
	local multVal = self.berserk and self.dmgMult * 4 or self.dmgMult
	self.Damage = self.Damage * multVal

	if self.afterModCD then
		self.afterModCDCount = self.afterModCDCount + increase*1.75

		if self.afterModCDCount >= 1 then
			self.afterModCDCount = 1
			self.afterModCD = false
		end
	end

	if self.usingMod and self.currentWeaponMod == mod_auto and not self.afterModCD and self.canUseFA and self.isFiring and not self.playerChar:isSwimming() and not self.playerChar:isDiving() and self.tool:isEquipped() then
		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_shells, 1 ) then
			self.fullAutoCounter = self.fullAutoCounter + increase
			if (self.fullAutoCounter/0.25) > 1 then
				self:shootProjectile("CSGFries", self.Damage)
			end
			if self.fullAutoCounter > 0.25 then
				self.aimFireMode.fireCooldown = 0.5
				self.fullAutoCounter = 0
			end
		else
			sm.audio.play( "PotatoRifle - NoAmmo" )
		end
	else
		self.fullAutoCounter = 0
	end

	if self.currentWeaponMod == mod_auto and self.usingMod and not self.afterModCD then
		if self.faWindUp < self.faWindUpMax then
			self.faWindUp = self.faWindUp + increase*2
		end

		if self.faWindUp >= self.faWindUpMax then
			self.faWindUp = self.faWindUpMax
			self.canUseFA = true
		end
	else
		self.canUseFA = false
	end

	if self.usingMod and self.currentWeaponMod == mod_sticky then
		self.ammoCost = 5
	else
		self.ammoCost = 1
	end

	if self.stickyBombAmmo < self.stickyBombAmmoMax or self.stickyBombAmmo < self.stickyBombAmmoMax and self.currentWeaponMod == mod_auto then
		if self.fireCooldownTimer <= 0.0 or self.fireCooldownTimer > 0.0 and self.stickyBombAmmo == 0 then
			if self.stickyReCharge < self.stickyReChargeMax and self.stickyBombAmmo < 5 then
				self.stickyReCharge = self.stickyReCharge + increase
			end

			if (self.stickyReCharge/self.stickyReChargeMax) > 1 then
				self.stickyBombAmmo = self.stickyBombAmmo + 1
			end

			if self.stickyBombAmmo < self.stickyBombAmmoMax and self.stickyReCharge >= self.stickyReChargeMax then
				self.stickyReCharge = 0
			end
		end
	end
end

function PotatoShotgun:cl_shootBomb( args )
	local bomb = {effect = sm.effect.createEffect("Rocket"), leakfx = sm.effect.createEffect("PropaneTank - ActivateBig"), pos = args.pos, dir = args.dir, lifeTime = 0, explodeCD = 0, exploded = false, attached = false, attachedTarget = nil, attachPos = sm.vec3.zero(), attachDir = sm.vec3.zero()}

	bomb.effect:setPosition( args.pos )
	bomb.effect:setRotation( sm.vec3.getRotation( effectRot, args.dir ) )
	bomb.effect:start()

	table.insert(self.bombs, bomb)
	self.network:sendToServer("sv_shootBomb")
end

function PotatoShotgun:sv_shootBomb()
	sm.container.beginTransaction()
	sm.container.spend( self.player:getInventory(), se_ammo_shells, 1, true )
	sm.container.endTransaction()
end

function PotatoShotgun:sv_bombExplode( pos )
	sm.physics.explode( pos, 5, self.explosionRadius/2, 4.0, 15.0, "PropaneTank - ExplosionSmall" )
end

function PotatoShotgun.client_onReload( self )
	if self.data.mod1.owned and self.data.mod2.owned then
		self.modSwitchCount = self.modSwitchCount + 1
		if self.modSwitchCount % 2 == 0 then
			self.currentWeaponMod = mod_sticky
		else
			self.currentWeaponMod = mod_auto
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

function PotatoShotgun:sv_saveCurrentWpnData( data )
	sm.event.sendToPlayer( self.player, "sv_saveWPData", data )
end

function PotatoShotgun:server_onFixedUpdate( dt )
	gravity = sm.vec3.new(0, 0, sm.physics.getGravity()) * 0.0005
end

function PotatoShotgun:sv_farmbotCannonCheck( args )
	sm.event.sendToUnit(args.unit, "sv_checkBombPos", { pos = args.pos, attacker = args.attacker } )
end
--SE

function PotatoShotgun.client_onUpdate( self, dt )
	--SE
	self.playerChar = self.player:getCharacter()
	self.lookDir = sm.localPlayer.getDirection()
	self.playerPos = self.playerChar:getWorldPosition()

	local increase = dt * self.spdMult
	local fpsAdjust = dt * 50

	for tablePos, bomb in pairs(self.bombs) do
		if bomb.lifeTime >= 15 or bomb.exploded then
			bomb.effect:stop()
			bomb.leakfx:stop()
			if bomb.exploded then
				self.network:sendToServer("sv_bombExplode", bomb.pos)
			end

			table.remove(self.bombs,tablePos)
		elseif bomb.attached then
			if not bomb.leakfx:isPlaying() then
				bomb.leakfx:start()
			end

			bomb.explodeCD = bomb.explodeCD + dt

			if bomb.explodeCD >= 2.5 then
				bomb.exploded = true
			end

			if bomb.attachedTarget and sm.exists(bomb.attachedTarget) then
				local newPos
				if type(bomb.attachedTarget) == "Shape" then
					local rot = bomb.attachedTarget.worldRotation
					newPos = bomb.attachedTarget:getWorldPosition() + rot * bomb.attachPos
					bomb.effect:setRotation( sm.vec3.getRotation( effectRot, rot * bomb.attachDir ) )
					bomb.leakfx:setRotation( sm.vec3.getRotation( effectRot, rot * bomb.attachDir ) )
				elseif type(bomb.attachedTarget) == "Character" then
					local dir = bomb.attachedTarget:getDirection()
					newPos = bomb.attachedTarget:getWorldPosition() + dir * bomb.attachPos
					bomb.effect:setRotation( sm.vec3.getRotation( effectRot, dir * bomb.attachDir ) )
					bomb.leakfx:setRotation( sm.vec3.getRotation( effectRot, dir * bomb.attachDir ) )
				end

				bomb.pos = newPos
				bomb.effect:setPosition( newPos )
				bomb.leakfx:setPosition( newPos - sm.vec3.new(0,0,0.5) )
			elseif bomb.attachedTarget and not sm.exists(bomb.attachedTarget) then
				bomb.attached = false
				bomb.attachedTarget = nil
				--bomb.explodeCD = 69420 --explodes the bomb
			end
		else
			local hit, result = sm.physics.raycast( bomb.pos, bomb.pos + bomb.dir * 0.5 * fpsAdjust )
			if hit then
				local object 
				local type = result.type
				if type == "terrainSurface" then
					bomb.attached = true
				elseif type == "character" then
					object = result:getCharacter()

					bomb.attachedTarget = object
					bomb.attachPos = bomb.pos - object:getWorldPosition()
					if object:getCharacterType() == sm.uuid.new("9f4fde94-312f-4417-b13b-84029c5d6b52") then
						self.network:sendToServer("sv_farmbotCannonCheck", { unit = object:getUnit(), pos = bomb.attachPos, attacker = self.player } )
					end

					bomb.attachDir = bomb.dir
					bomb.attached = true
				elseif type == "body" then
					object = result:getShape()
					bomb.attachedTarget = object
					bomb.attachPos = bomb.pos - object:getWorldPosition()
					bomb.attachDir = bomb.dir
					bomb.attached = true
				end
			end

			if bomb.dir.z > -1 then
				bomb.dir = bomb.dir - gravity * fpsAdjust
			end
			bomb.lifeTime = bomb.lifeTime + dt
			local newPos = bomb.pos + bombVel * bomb.dir * fpsAdjust
			bomb.pos = newPos
			bomb.effect:setPosition( newPos )
			bomb.effect:setRotation( sm.vec3.getRotation(effectRot, bomb.dir) )
		end
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
		fireMode = self.aiming and self.aimFireMode or self.normalFireMode
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
		-- Sets PotatoRifle renderable, change this to change the mesh
		self.tool:setFpRenderables( currentRenderablesFp )
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function PotatoShotgun.client_onUnequip( self, animate )
	if animate then
		sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
	end

	--SE
	self.usingMod = false
	--SE
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

	--SE
	if self.tool:isInFirstPersonView() then
		if self.usingMod and self.stickyBombAmmo == 0 and self.currentWeaponMod == mod_sticky or self.afterModCD or self.usingMod and self.currentWeaponMod == mod_auto and not self.canUseFA then
			sm.audio.play( "PotatoRifle - NoAmmo" )
		else
			self.shootEffectFP:start()
		end
	else
		if self.usingMod and self.stickyBombAmmo == 0 and self.currentWeaponMod == mod_sticky or self.afterModCD or self.usingMod and self.currentWeaponMod == mod_auto and not self.canUseFA then
			sm.audio.play( "PotatoRifle - NoAmmo" )
		else
			self.shootEffect:start()
		end
	end
	--SE
end

function PotatoShotgun.calculateFirePosition( self )
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

function PotatoShotgun.calculateTpMuzzlePos( self )
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

function PotatoShotgun.calculateFpMuzzlePos( self )
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

function PotatoShotgun.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end
	if self.fireCooldownTimer <= 0.0 and state == sm.tool.interactState.start then

		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_shells, self.ammoCost ) then

			local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
			local owner = self.tool:getOwner()

			if owner and not self.usingMod and not self.afterModCD or owner and self.usingMod and not self.afterModCD and self.currentWeaponMod == mod_auto or owner and self.currentWeaponMod == "poor" then
				self.aimFireMode.fireCooldown = 0.5
				self:shootProjectile( "CSGFries", self.Damage )
			elseif owner and self.usingMod and self.currentWeaponMod == mod_sticky and self.stickyBombAmmo > 0 and not self.afterModCD then
				--self:shootProjectile( "stickybomb", self.Damage )

				--self:shootProjectile( "explosivetape", self.Damage )

				self:cl_shootBomb({ pos = self:calculateFirePosition() + self.lookDir, dir = self.lookDir })

				self.stickyBombAmmo = self.stickyBombAmmo - 1
				--if self.stickyBombAmmo == 5 then
					--self.stickyReCharge = self.stickyReCharge - 30
					self.stickyReCharge = 0
				--end

				-- Send TP shoot over network and dircly to self
				self:onShoot( self.lookDir )
				self.network:sendToServer( "sv_n_onShoot", self.lookDir )

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
	if state == sm.tool.interactState.start and not self.usingMod --[[self.aiming]] then
		--SE
		self.usingMod = true
		self.aiming = true
		--if self.currentWeaponMod == mod_auto or self.currentWeaponMod == "poor" then
			self.tpAnimations.animations.idle.time = 0
			self:onAim( self.usingMod )
			if self.currentWeaponMod == mod_auto and not self.faMobility or self.currentWeaponMod == "poor" then
				self.tool:setMovementSlowDown( self.usingMod )
			end
			self.network:sendToServer( "sv_n_onAim", self.usingMod )
		--end
		--SE
	end

	if self.usingMod --[[self.aiming]] and (state == sm.tool.interactState.stop or state == sm.tool.interactState.null) then
		--SE
		self.usingMod = false
		self.aiming = false
		--if self.currentWeaponMod == mod_auto or self.currentWeaponMod == "poor" then
			self.tpAnimations.animations.idle.time = 0
			self:onAim( self.usingMod )
			if self.currentWeaponMod == mod_auto and not self.faMobility or self.currentWeaponMod == "poor" then
				self.tool:setMovementSlowDown( self.usingMod )
			end
			self.network:sendToServer( "sv_n_onAim", self.usingMod )
		--end
		--SE
	end

	--SE
	if self.currentWeaponMod == mod_auto then
		self.faWindUp = 0
	end
	--SE
end

function PotatoShotgun.client_onEquippedUpdate( self, primaryState, secondaryState )
	--SE
	local data = {
		mod = self.currentWeaponMod,
		using = self.usingMod,
		ammo = 0,
		recharge = 0
	}
	self.network:sendToServer( "sv_saveCurrentWpnData", data )

	if self.currentWeaponMod == mod_sticky then
		sm.gui.setProgressFraction(self.stickyBombAmmo/self.stickyBombAmmoMax)
	end

	if not self.canUseFA and self.currentWeaponMod == mod_auto and self.usingMod then
		sm.gui.setProgressFraction(self.faWindUp/self.faWindUpMax)
	end

	if self.afterModCD then
		sm.gui.setProgressFraction(self.afterModCDCount/1)
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
