dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

Ballista = class()

local mod_arbalest = "Arbalest"
local mod_blade = "Destroyer Blade"
local vel = sm.vec3.new(1,1,1)
local bladeImpact = sm.vec3.new(5,5,5)
local triggerSizes = {
	sm.vec3.new(1,1,1),
	sm.vec3.new(1,2,1),
	sm.vec3.new(1,3,1)
}

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

function Ballista.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunBasic - BasicMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunBasic - FPBasicMuzzel" )

	--SE

	--General stuff
	self.player = sm.localPlayer.getPlayer()
	self.playerChar = self.player:getCharacter()

	self.data = sm.playerInfo[self.player:getId()].weaponData.ballista

	self.ammoCost = 25
	self.Damage = 100
	self.isFiring = false
	self.usingMod = false

	--Mod switch
	self.currentWeaponMod = mod_arbalest
	self.afterModCD = false
	self.afterModCDCount = 1
	self.modSwitchCount = 0

	--mod_arbalest
	self.arbMobility = false
	self.arbBigExp = false
	self.arbalestCharge = 0
	self.darts = {}

	--mod_blade
	self.bladeFalterTrigger = nil
	self.bladeTriggerCDcount = 0
	self.bladeBlast = false
	self.bladeChargeMax = 1.5
	self.bladeMastery = false
	self.bladeCharge = 0
	self.bladeChargeLevel = 0
	self.blades = {}
	--SE
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

--SE
function Ballista:server_onFixedUpdate( dt )
	if self.bladeTriggerCD then
		self.bladeTriggerCDcount = self.bladeTriggerCDcount + dt
		if self.bladeTriggerCDcount >= 0.3 then
			self.bladeTriggerCDcount = 0
			self.bladeTriggerCD = false
			if sm.exists(self.bladeFalterTrigger) then
				sm.areaTrigger.destroy( self.bladeFalterTrigger )
			end
		end
	end
end

function Ballista:client_onFixedUpdate( dt )
	local playerData = sm.playerInfo[self.player:getId()].playerData
	self.data = sm.playerInfo[self.player:getId()].weaponData.ballista
	self.dmgMult = playerData.damageMultiplier
	self.spdMult = playerData.speedMultiplier

	--upgrades
	if self.data.mod1.up1.owned then
		self.arbMobility = true
	end

	if self.data.mod1.up2.owned then
		self.arbBigExp = true
	end


	if self.data.mod2.up1.owned then
		self.bladeBlast = true
	end

	if self.data.mod2.up2.owned then
		self.bladeChargeMax = 1
	end

	if self.data.mod2.mastery.owned then
		self.bladeMastery = true
	end

	--powerup
	local increase = dt * self.spdMult

	--main
	if self.afterModCD then
		self.afterModCDCount = self.afterModCDCount + increase*1.75

		if self.afterModCDCount >= 1 then
			self.afterModCDCount = 1
			self.afterModCD = false
		end
	end

	--mod_arbalest
	if not self.afterModCD and self.usingMod and self.fireCooldownTimer <= 0.0 and self.currentWeaponMod == mod_arbalest then
		self.arbalestCharge = self.arbalestCharge + increase
		if self.arbalestCharge >= 3 then
			self.arbalestCharge = 3
		end

		self.Damage = math.ceil(100 + self.arbalestCharge * 100)
	end

	--mod_blade
	if not self.afterModCD and self.usingMod and self.fireCooldownTimer <= 0.0 and self.currentWeaponMod == mod_blade then
		if self.bladeChargeLevel < 3 then
			self.bladeCharge = self.bladeCharge + increase
		end

		if self.bladeMastery then
			if self.bladeCharge >= self.bladeChargeMax and self.bladeChargeLevel < 3 then
				self.bladeCharge = 0
				self.bladeChargeLevel = self.bladeChargeLevel + 1
				self.Damage = self.Damage + self.bladeChargeLevel * 50
				sm.audio.play("Blueprint - Open")

				if self.bladeChargeLevel == 3 then
					self.network:sendToServer("sv_bladeFalterCreate")
				end
			elseif self.bladeCharge >= self.bladeChargeMax then
				self.bladeCharge = self.bladeChargeMax
			end
		else
			self.Damage = self.Damage + self.bladeCharge * 50
			if self.bladeCharge >= self.bladeChargeMax*3 and self.bladeChargeLevel < 3 then
				self.bladeCharge = self.bladeChargeMax*3
				self.bladeChargeLevel = 3
				if self.bladeBlast then
					self.network:sendToServer("sv_bladeFalterCreate")
				end
			end
		end
	end

	if not self.usingMod then
		self.Damage = 100
		self.ammoCost = 25
		self.bladeCharge = 0
		self.bladeChargeLevel = 0
		self.arbalestCharge = 0
	end

	if self.bladeChargeLevel == 1 then
		self.ammoCost = 16
	elseif self.bladeChargeLevel == 2 then
		self.ammoCost = 33
	elseif self.bladeChargeLevel == 3 then
		self.ammoCost = 50
	else
		self.ammoCost = 25
	end
end

function Ballista.client_onReload( self )
	if self.data.mod1.owned and self.data.mod2.owned then
		self.modSwitchCount = self.modSwitchCount + 1
		if self.modSwitchCount % 2 == 0 then
			self.currentWeaponMod = mod_arbalest
		else
			self.currentWeaponMod = mod_blade
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

function Ballista:sv_saveCurrentWpnData( data )
	sm.event.sendToPlayer( self.player, "sv_saveWPData", data )
end

function Ballista:sv_knockback()
	sm.physics.applyImpulse( self.playerChar, self.playerChar:getVelocity() * self.playerChar:getMass() / 50 + self.lookDir * -7.5 * self.playerChar:getMass() )
end

--mod_blade
function Ballista:cl_shootBlade( args )
	local blade = {}

	--old effects by level
	--1. Fire - lowburn
	--2. Fire -medium01
	--3. Fire - large01
	blade = {effect = sm.effect.createEffect("Destroyer Blade"), trigger = nil, pos = args.pos, dir = args.dir, level = args.level, lifeTime = 0, dmg = args.dmg}

	blade.effect:setPosition( args.pos )

	--fix the rotation on the x axis some time
	blade.effect:setRotation( sm.vec3.getRotation( sm.vec3.new( -1, 0, 0 ), args.dir ) )
	--sm.vec3.rotate( args.dir, math.rad(somehow figure out how the fuck to calculate the degrees), sm.camera.getRight())

	blade.effect:setScale( triggerSizes[args.level]/2 )
	blade.effect:start()
	table.insert(self.blades, blade)

	self.network:sendToServer("sv_shootBlade")
end

function Ballista:sv_shootBlade()
	local blade = self.blades[table.maxn(self.blades)]

	blade.trigger = sm.areaTrigger.createBox( triggerSizes[blade.level], blade.pos, blade.rot, sm.areaTrigger.filter.character )
	blade.trigger:bindOnEnter( "sv_bladeDamageUnits" )
end

function Ballista:sv_bladeDamageUnits( trigger, result )
	local parentBlade = {}
	for tablePos, blade in pairs(self.blades) do
		if blade.trigger == trigger then
			parentBlade = blade
		end
	end

	for i, object in pairs(result) do
		if type(object) == "Character" and object:getId() ~= self.playerChar:getId() and sm.exists(object) then
			sm.event.sendToUnit( object:getUnit(), "sv_se_takeDamage", { damage = parentBlade.dmg, impact = bladeImpact * parentBlade.level, hitPos = parentBlade.pos, attacker = self.player } )
		end
	end
end

function Ballista:sv_bladeUpdateTriggers()
	for tablePos, blade in pairs(self.blades) do
		if blade.lifeTime < 15 and sm.exists(blade.trigger) then
			blade.trigger:setWorldPosition( blade.pos )
		elseif sm.exists(blade.trigger) then
			sm.areaTrigger.destroy( blade.trigger )
		end
	end
end

function Ballista:sv_bladeFalterCreate()
	self.bladeFalterTrigger = sm.areaTrigger.createBox( sm.vec3.new(2.5,2.5,2.5), self.playerPos, sm.quat.identity(), sm.areaTrigger.filter.character )
	self.bladeFalterTrigger:bindOnStay( "sv_bladeFalter" )
	self.bladeTriggerCD = true
end

function Ballista:sv_bladeFalter( trigger, result )
	for pos, unit in pairs(result) do
		if unit:getId() ~= self.playerChar:getId() and sm.exist(unit) then
			sm.event.sendToUnit( unit:getUnit(), "sv_addStagger", 10)
		end
	end
end

--mod_arbalest
function Ballista:cl_shootDart( args )
	local dart = {effect = sm.effect.createEffect("Arbalest Dart"), pos = args.pos, dir = args.dir, lifeTime = 0, explodeCD = 0, targetsHit = 0, attached = false, exploded = false, attachedTarget = nil, attachPos = sm.vec3.zero(), attachDir = sm.vec3.zero(), dmg = args.dmg}

	dart.effect:setPosition( args.pos )
	dart.effect:setRotation( sm.vec3.getRotation( sm.vec3.new( -1, 0, 0 ), args.dir ) )
	dart.effect:start()
	table.insert(self.darts, dart)

	--self.network:sendToServer("sv_shootDart")
end

function Ballista:sv_dartExplode( pos )
	local multiplier = 1
	if self.arbBigExp then
		multiplier = 1.6
	end
	sm.physics.explode( pos, 6 * multiplier, 2.5 * multiplier, 3 * multiplier, 10 * multiplier, "PropaneTank - ExplosionSmall" )
end

function Ballista:sv_dartCharDamage( args )
	sm.event.sendToUnit( args.unit, "sv_se_takeDamage", { damage = args.damage, impact = args.impact, hitPos = args.hitPos, attacker = args.attacker } )
end

function Ballista.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end

	if self.fireCooldownTimer <= 0.0 and state == sm.tool.interactState.start then

		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_plasma, self.ammoCost ) then
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

			--SE
			if not self.afterModCD then
				local valid = false
				self.Damage = self.Damage * self.dmgMult
				if owner and not self.usingMod then
					sm.projectile.projectileAttack( proj_ballista, self.Damage, firePos, dir * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf )
					self.network:sendToServer("sv_knockback")
					valid = true
				elseif owner and self.usingMod and self.currentWeaponMod == mod_arbalest then
					--sm.projectile.projectileAttack( "arbalest", self.Damage, firePos, dir * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf )
					self:cl_shootDart({ pos = firePos --[[self.playerPos]], dir = self.lookDir, dmg = self.Damage })
					self.arbalestCharge = 0
					valid = true
				elseif owner and self.usingMod and self.currentWeaponMod == mod_blade and (self.bladeMastery and self.bladeChargeLevel > 0 or not self.bladeMastery and self.bladeCharge == self.bladeChargeMax*3 ) then
					self:cl_shootBlade({ pos = firePos --[[self.playerPos]], dir = self.lookDir, level = self.bladeChargeLevel, dmg = self.Damage })

					self.bladeCharge = 0
					self.bladeChargeLevel = 0
					valid = true
				end
				--SE

				if valid then
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
--SE

function Ballista.client_onUpdate( self, dt )
	--SE
	self.playerChar = self.player:getCharacter()
	self.lookDir = self.playerChar:getDirection()
	self.playerPos = self.playerChar:getWorldPosition()

	local increase = dt * self.spdMult
	local fpsAdjust = dt * 50

	--mod_arbalest
	for tablePos, dart in pairs(self.darts) do
		if dart.lifeTime >= 15 or dart.exploded then
			dart.effect:stop()
			--sm.effect.playEffect( "PropaneTank - ExplosionSmall", dart.pos )
			if dart.exploded then
				self.network:sendToServer("sv_dartExplode", dart.pos + dart.dir)
			end

			table.remove(self.darts,tablePos)
		elseif dart.attached then
			dart.explodeCD = dart.explodeCD + dt

			if dart.explodeCD >= 3 then
				dart.exploded = true
			end

			if dart.attachedTarget and sm.exists(dart.attachedTarget) then
				local newPos
				if type(dart.attachedTarget) == "Shape" then
					local rot = dart.attachedTarget.worldRotation
					newPos = dart.attachedTarget:getWorldPosition() + rot * dart.attachPos
					dart.effect:setRotation( sm.vec3.getRotation( sm.vec3.new( -1, 0, 0 ), rot * dart.attachDir ) )
				elseif type(dart.attachedTarget) == "Character" then
					local dir = dart.attachedTarget:getDirection()
					newPos = dart.attachedTarget:getWorldPosition() + dir * dart.attachPos
					dart.effect:setRotation( sm.vec3.getRotation( sm.vec3.new( -1, 0, 0 ), dir * dart.attachDir ) )
				end

				dart.pos = newPos
				dart.effect:setPosition( newPos )
			elseif dart.attachedTarget and not sm.exists(dart.attachedTarget) then
				dart.attached = false
				dart.attachedTarget = nil
				dart.explodeCD = 69420 --explodes the dart
			end
		else
			local hit, result = sm.physics.raycast( dart.pos, dart.pos + dart.dir * 0.6 * fpsAdjust )
			if hit then
				local uuidStr
				local object 
				local type = result.type
				print(type)
				if type == "terrainSurface" then
					dart.attached = true
				elseif type == "character" then
					object = result:getCharacter()
					uuidStr = tostring(object:getCharacterType())
					if dart.targetsHit < 1 and uuidStr ~= unit_farmbot then
						if object:getId() ~= self.playerChar:getId() and sm.exists(object) then
							self.network:sendToServer("sv_dartCharDamage", { unit = object:getUnit(), damage = dart.dmg, impact = self.lookDir, hitPos = object:getWorldPosition(), attacker = self.player } )
						end
						dart.targetsHit = dart.targetsHit + 1
						if self.currentWeaponMod == mod_arbalest and self.data.mod1.mastery.owned then
							self.fireCooldownTimer = 0
						end
						dart.explodeCD = 0
					elseif dart.targetsHit >= 1 or uuidStr == unit_farmbot then
						dart.targetsHit = dart.targetsHit + 1
						if self.currentWeaponMod == mod_arbalest and self.data.mod1.mastery.owned then
							self.fireCooldownTimer = 0
						end
						dart.explodeCD = 0
						dart.attachedTarget = object
						dart.attachPos = dart.pos - object:getWorldPosition()
						dart.attachDir = dart.dir
						dart.attached = true
					end
				elseif type == "body" then
					object = result:getShape()
					dart.attachedTarget = object
					dart.attachPos = dart.pos - object:getWorldPosition()
					dart.attachDir = dart.dir
					dart.attached = true
				end
			end

			dart.lifeTime = dart.lifeTime + dt
			local newPos = dart.pos + vel * dart.dir * fpsAdjust
			dart.pos = newPos
			dart.effect:setPosition( newPos )
		end
	end

	--mod_blade
	for tablePos, blade in pairs(self.blades) do
		local hit, result = sm.physics.raycast( blade.pos, blade.pos + blade.dir * fpsAdjust )

		if blade.lifeTime > 15 or hit then
			blade.effect:stop()
			sm.effect.playEffect( "PropaneTank - ExplosionSmall", blade.pos )
			table.remove(self.blades,tablePos)
		else
			local newPos = blade.pos + vel * blade.dir * fpsAdjust
			blade.lifeTime = blade.lifeTime + dt
			blade.pos = newPos
			blade.effect:setPosition( newPos )
		end
	end
	self.network:sendToServer("sv_bladeUpdateTriggers")
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

function Ballista.client_onEquip( self, animate )
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
		-- Sets Ballista renderable, change this to change the mesh
		self.tool:setFpRenderables( currentRenderablesFp )
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

function Ballista.sv_n_onAim( self, aiming )
	self.network:sendToClients( "cl_n_onAim", aiming )
end

function Ballista.cl_n_onAim( self, aiming )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onAim( aiming )
	end
end

function Ballista.onAim( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function Ballista.sv_n_onShoot( self, dir )
	self.network:sendToClients( "cl_n_onShoot", dir )
end

function Ballista.cl_n_onShoot( self, dir )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onShoot( dir )
	end
end

function Ballista.onShoot( self, dir )

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

function Ballista.calculateFirePosition( self )
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

function Ballista.calculateTpMuzzlePos( self )
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

function Ballista.calculateFpMuzzlePos( self )
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

function Ballista.cl_onSecondaryUse( self, state )
	if state == sm.tool.interactState.start and not self.aiming then
		--SE
		self.usingMod = true
		--SE
		self.aiming = true
		self.tpAnimations.animations.idle.time = 0

		self:onAim( self.aiming )
		if self.currentWeaponMod == mod_blade or not self.arbMobility then
			self.tool:setMovementSlowDown( self.aiming )
		end
		self.network:sendToServer( "sv_n_onAim", self.aiming )
	end

	if self.aiming and (state == sm.tool.interactState.stop or state == sm.tool.interactState.null) then
		--SE
		self.usingMod = false
		--SE
		self.aiming = false
		self.tpAnimations.animations.idle.time = 0

		self:onAim( self.aiming )
		self.tool:setMovementSlowDown( self.aiming )
		self.network:sendToServer( "sv_n_onAim", self.aiming )
	end
end

function Ballista.client_onEquippedUpdate( self, primaryState, secondaryState )
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

	if self.usingMod and self.currentWeaponMod == mod_arbalest then
		sm.gui.setProgressFraction(self.arbalestCharge/3)
	elseif self.usingMod and self.currentWeaponMod == mod_blade then
		if self.bladeMastery then
			sm.gui.setProgressFraction(self.bladeChargeLevel/3)
		else
			sm.gui.setProgressFraction(self.bladeCharge/(self.bladeChargeMax*3))
		end
	end

	if self.fireCooldownTimer > 0 then
		sm.gui.setProgressFraction(self.fireCooldownTimer/2)
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
