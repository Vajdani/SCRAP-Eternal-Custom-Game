dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

dofile "$CONTENT_DATA/Scripts/se_util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"

PRifle = class()

PRifle.mod1 = "Heat Blast"
PRifle.mod2 = "Microwave Beam"
PRifle.renderables = {
	poor = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_basic/char_spudgun_barrel_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	["Heat Blast"] = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_basic/char_spudgun_barrel_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	["Microwave Beam"] = {
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_basic/char_spudgun_barrel_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	}
}
PRifle.renderablesTp = {
	"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"
}
PRifle.renderablesFp = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"
}
PRifle.blastColours = {
	sm.color.new("#0000ff"),
	sm.color.new("#00aaff"),
	sm.color.new("#ff0000")
}
PRifle.beamRange = 10
PRifle.baseDamage = 26
PRifle.blastDamage = 50
PRifle.bindDefaultFuncs = true

for k, v in pairs(PRifle.renderables) do
	sm.tool.preloadRenderables( v )
end
sm.tool.preloadRenderables( PRifle.renderablesTp )
sm.tool.preloadRenderables( PRifle.renderablesFp )

function PRifle:server_onCreate()
	self.sv = {}
	self.sv.owner = self.tool:getOwner()
	self.sv.blastTrigger = sm.areaTrigger.createBox(
		sm.vec3.new(2,2,2),
		self.sv.owner.character.worldPosition,
		sm.quat.identity(),
		sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody
	)
end

function PRifle:server_onFixedUpdate()
	local char = self.sv.owner.character
	if not char then return end

	self.sv.blastTrigger:setWorldPosition( char.worldPosition + char.direction * 2 )
end

function PRifle:sv_updateBeamTarget( char )
	self.network:sendToClients("cl_updateBeamTarget", char)
end

function PRifle:sv_damageBeamTargets( targets )
	sm.container.beginTransaction()
	sm.container.spend( self.sv.owner:getInventory(), se_ammo_plasma, 1, true )
	sm.container.endTransaction()

	for k, char in pairs(targets) do
		if sm.exists(char) then
			if char:getCharacterType() ~= unit_mechanic then
				local unit = char:getUnit()
				sm.event.sendToUnit( unit, "sv_se_takeDamage",
					{
						damage = 15,
						impact = sm.vec3.one(),
						hitPos = char.worldPosition,
						attacker = self.sv.owner
					}
				)

				sm.event.sendToUnit( unit, "sv_addStagger", 1 )
			end
		end
	end
end

function PRifle:sv_blast( args )
	local level = args.level
	local dir = self.sv.owner.character:getDirection()

	local damageMultiplier = 1
	for _, object in pairs(self.sv.blastTrigger:getContents()) do
		local mass = object:getMass()/75
		local force
		if type(object) == "Body" then
			force = sm.vec3.one() * 1000 * dir * mass * level
			sm.physics.applyImpulse( object, force/mass )
		elseif not object:isPlayer() then
			force = sm.vec3.new(1000 * dir.x, 1000 * dir.y, 450) * mass * level
			if object:getCharacterType() ~= unit_farmbot then
				damageMultiplier = 1
				sm.physics.applyImpulse( object, force )
			else
				damageMultiplier = 5
			end

			if object:getCharacterType() ~= unit_mechanic then
				sm.event.sendToUnit( object:getUnit(), "sv_se_takeDamage", { damage = self.blastDamage * level * damageMultiplier, impact = force / 1000, hitPos = object:getWorldPosition(), attacker = self.cl.owner } )
			end
		end
	end

	self.network:sendToClients("cl_blast", level)
end



function PRifle:cl_updateBeamTarget( char )
	self.cl.beam.effectTarget = char

	if not self.tool:isLocal() then return end
	--[[if not char then
		self.cl.beam.hud:close()
	else
		self.cl.beam.hud:open()
	end]]
end

function PRifle.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunBasic - BasicMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunBasic - FPBasicMuzzel" )

	self.cl = {}
	self.cl.baseWeapon = BaseWeapon()
	self.cl.baseWeapon.cl_onCreate( self, "plasma" )

	self.cl.blast = {}
	self.cl.blast.effect = sm.effect.createEffect( "Plasma Blast" )

	self.cl.beam = {}
	self.cl.beam.targets = {}
	self.cl.beam.effectTarget = nil
	--[[self.cl.beam.effect = Line()
	self.cl.beam.effect:init( 0.05, sm.color.new(0, 1, 1) )
	
	self.cl.beam.beamTest = {}
	for i = 1, 9 do
		self.cl.beam.beamTest[#self.cl.beam.beamTest+1] = Line()
		self.cl.beam.beamTest[i]:init( 0.05, sm.color.new(0, 1, 1) )
	end]]

	self.cl.beam.curvedTest = CurvedLine()
	self.cl.beam.curvedTest:init( 0.05, sm.color.new(0, 1, 1), 99, 5, "Plasma Beam_sound" )

	if not self.tool:isLocal() then return end

	self.cl.Damage = self.baseDamage

	--mod1
	self.cl.blastChargeIncrease = 1
	self.cl.blastCharge = 0
	self.cl.blast.fireDelay = {
		active = false,
		timer = Timer()
	}
	self.cl.blast.fireDelay.timer:start( 30 )
	self.cl.blast.masteryEffect = {
		active = false,
		timer = Timer()
	}
	self.cl.blast.masteryEffect.timer:start( 200 )

	--mod2
	self.cl.beam.targetIndicator = sm.gui.createWorldIconGui( 50, 50 )
	self.cl.beam.targetIndicator:setImage("Icon", "$CONTENT_DATA/Gui/susshake.png")
	self.cl.beam.cd = {
		active = false,
		timer = Timer()
	}
	self.cl.beam.cd.timer:start( 30 )
	self.cl.beam.targets = {}
	self.cl.beam.dmgTimer = Timer()
	self.cl.beam.dmgTimer:start( 5 )

	--[[self.cl.beam.hud = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/weapons/plasma/charge.layout", false,
		{
			isHud = true,
			isInteractive = false,
			needsCursor = false,
			hidesHotbar = false,
			isOverlapped = false,
			backgroundAlpha = 0,
		}
	)
	self.cl.beam.hud:createHorizontalSlider("chargeSlider", 1600, 0, "", false)]]
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


function PRifle:client_onFixedUpdate( dt )
	if not self.tool:isLocal() or not self.tool:isEquipped() then return end

	self.cl.baseWeapon.cl_onFixed( self )

	--fuck off
	if self.fireCooldownTimer == nil then
		self.fireCooldownTimer = 0
	end

	if self.cl.currentWeaponMod == "poor" then
		if self.cl.weaponData.mod1.owned then
			self.cl.currentWeaponMod = self.mod1
		elseif self.cl.weaponData.mod2.owned then
			self.cl.currentWeaponMod = self.mod2
		end

		return
	end

	--upgrades
	self.cl.blastChargeIncrease = self.cl.weaponData.mod1.up2.owned and 2 or 1
	self.cl.beamRange = self.cl.weaponData.mod2.up2.owned and 15 or 10

	if self.cl.blast.masteryEffect.active then
		self.cl.blast.masteryEffect.timer:tick()
		if self.cl.blast.masteryEffect.timer:done() then
			self.cl.blast.masteryEffect.active = false
			self.cl.blast.masteryEffect.timer:reset()
			self.cl.Damage = self.baseDamage
		end
	end

	--powerup
	local increase = dt * self.cl.powerups.speedMultiplier.current

	--main and some mod1
	local ownerChar = self.cl.owner.character
	if self.cl.isFiring and (self.cl.currentWeaponMod == "poor" or not self.cl.modSwitch.active and (self.cl.currentWeaponMod == self.mod1 and not self.cl.blast.fireDelay.active or self.cl.currentWeaponMod == self.mod2 and not self.cl.usingMod) ) and not ownerChar:isSwimming() and not ownerChar:isDiving() then
		self.fireCounter = self.fireCounter + increase
		if (self.fireCounter/0.2) >= 1 then
			if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_plasma, 1 ) then
				self:shootProjectile( proj_plasma, self.cl.Damage * self.cl.powerups.damageMultiplier.current )
				if self.cl.blast.masteryEffect.active then
					sm.audio.play( "Retrofmblip" )
				end

				if self.cl.currentWeaponMod == self.mod1 and self.cl.blastCharge < 60 and not self.cl.blast.masteryEffect.active then
					self.cl.blastCharge = self.cl.blastCharge + self.cl.blastChargeIncrease

					--very good solution
					if isAnyOf(self.cl.blastCharge, { 20, 40, 60 }) or self.cl.blastChargeIncrease > 1 and isAnyOf(self.cl.blastCharge, { 21, 41, 61 }) then
						sm.audio.play( "Blueprint - Open" )
					end
				end
			else
				sm.audio.play( "PotatoRifle - NoAmmo" )
			end

			self.fireCounter = 0
		end
	else
		self.fireCounter = 0
	end

	--mod2
	if self.cl.beam.cd.active then
		for i = 1, (self.cl.weaponData.mod2.up1.owned and 2 or 1) do
			self.cl.beam.cd.timer:tick()
		end

		if self.cl.beam.cd.timer:done() then
			self.cl.beam.cd.active = false
			self.cl.beam.cd.timer:reset()
		end
	end

	if self.cl.currentWeaponMod == self.mod2 and self.cl.usingMod and not self.cl.beam.cd.active and not self.cl.modSwitch.active then
		if #self.cl.beam.targets == 0 then
			local hit, result = sm.localPlayer.getRaycast( self.cl.beamRange )
			if hit and result.type == "character" then
				local char = result:getCharacter()
				if not sm.exists(char) then return end

				self.cl.beam.targetIndicator:setWorldPosition( char.worldPosition )
				if not self.cl.beam.targetIndicator:isActive() then
					self.cl.beam.targetIndicator:open()
				end

				if self.cl.isFiring then
					self.cl.beam.targets[#self.cl.beam.targets+1] = char
					self.network:sendToServer("sv_updateBeamTarget", char)
					self.cl.beam.targetIndicator:close()
				end
			elseif self.cl.beam.targetIndicator:isActive() then
				self.network:sendToServer("sv_updateBeamTarget", nil)
				self.cl.beam.targetIndicator:close()
			end
		elseif sm.exists(self.cl.beam.targets[1]) then
			local playerChar = self.cl.owner.character
			local playerPos = playerChar.worldPosition
			local dir = self.cl.beam.targets[1].worldPosition - (playerPos + camPosDifference)
			local distance = dir:length()

			if not self.cl.isFiring or distance > 15 --[[or se_weapon_isInvalidBeamDir(playerChar:getDirection() - dir:normalize())]] then
				self.cl.beam.targets = {}
				self.network:sendToServer("sv_updateBeamTarget", nil)
				self.cl.beam.cd.active = true
				return
			end

			if not self.cl.beamTrigger or not sm.exists(self.cl.beamTrigger) then
				self.cl.beamTrigger = sm.areaTrigger.createBox( sm.vec3.one(), playerPos, sm.quat.identity(), sm.areaTrigger.filter.character )
			end

			self.cl.beamTrigger:setWorldPosition( playerPos + dir * 0.5 )
			self.cl.beamTrigger:setWorldRotation( sm.vec3.getRotation( sm.vec3.new(0,0,1), dir:normalize() ) )
			self.cl.beamTrigger:setSize( sm.vec3.new( 0.25, 0.25, distance  ) )

			for k, char in pairs(self.cl.beamTrigger:getContents()) do
				if sm.exists(char) and not isAnyOf(char, self.cl.beam.targets) then
					self.cl.beam.targets[#self.cl.beam.targets+1] = char
				end
			end

			self.cl.beam.dmgTimer:tick()
			if self.cl.beam.dmgTimer:done() then
				self.cl.beam.dmgTimer:reset()
				self.network:sendToServer("sv_damageBeamTargets", self.cl.beam.targets)
			end
		else
			self.cl.beam.targets = {}
			self.cl.beam.dmgTimer:reset()
			self.network:sendToServer("sv_updateBeamTarget", nil)
			self.cl.beam.cd.active = true
		end
	elseif self.cl.beam.targetIndicator:isActive() or #self.cl.beam.targets > 0 then
		self.cl.beam.targets = {}
		self.network:sendToServer("sv_updateBeamTarget", nil)
		self.cl.beam.targetIndicator:close()
	end


	--mod1
	if self.cl.blast.fireDelay.active then
		for i = 1, (self.cl.weaponData.mod1.up1.owned and 2 or 1) do
			self.cl.blast.fireDelay.timer:tick()
		end

		if self.cl.blast.fireDelay.timer:done() then
			self.cl.blast.fireDelay.active = false
			self.cl.blast.fireDelay.timer:reset()
		end
	end
end

function PRifle:cl_blast( level )
	self.cl.blast.effect:setParameter("color", self.blastColours[math.floor(level)])
	self.cl.blast.effect:start()
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
	self.cl.baseWeapon.onModSwitch( self )
	self.network:sendToServer("sv_updateBeamTarget", nil)

	return true
end

function PRifle.client_onUpdate( self, dt )
	if self.cl.beam.effectTarget and sm.exists(self.cl.beam.effectTarget) then
		--[[self.cl.beam.effect:update(
			self.tool:isInFirstPersonView() and self.tool:getFpBonePos( "pejnt_barrel" ) - self.cl.owner.character.direction * 0.15 or self.tool:getTpBonePos( "pejnt_barrel" ),
			self.cl.beam.effectTarget.worldPosition,
			dt,
			250
		)]]

		local char = self.cl.owner.character
		local p1 = self.tool:isInFirstPersonView() and self.tool:getFpBonePos( "pejnt_barrel" ) - self.cl.owner.character.direction * 0.15 or self.tool:getTpBonePos( "pejnt_barrel" )
		local toTarget = (self.cl.beam.effectTarget.worldPosition - p1)
		local p2 = p1 + char:getDirection() * 5
		local p3 = p1 + toTarget * 0.5
		local p4 = self.cl.beam.effectTarget.worldPosition

		local hit, result = sm.physics.raycast( p1, p2 )
		if hit and result:getCharacter() == nil then p2 = result.pointWorld + sm.vec3.new(0,0,0.1) end

		local hit, result = sm.physics.raycast( p2, p3 )
		if hit and result:getCharacter() == nil then p3 = result.pointWorld + sm.vec3.new(0,0,0.1) end

		local data = se.unitData[self.cl.beam.effectTarget.id]
		local multiplier = data and sm.util.clamp(data.data.stats.maxhp/sm.util.clamp(data.data.stats.hp + 0.001, 0, data.data.stats.maxhp), 0, 10) or 1

		self.cl.beam.curvedTest:update(
			p1,
			p2,
			p3,
			p4,
			dt,
			{ x = 0, y = 0, z = 0.25 },
			{ x = 0, y = 0, z = 0.25 },
			10 * multiplier / 2,
			250
		)

		--[[for i = 1, 10 do
			sm.particle.createParticle( "construct_welding", sm.vec3.bezier3( p1, p2, p3, p4, i / 10 ) )
		end]]

		--[[local steps = #self.cl.beam.beamTest
		local positions = {}
		for i = 1, steps do
			if i < 3 then
				positions[#positions+1] = {
					startPos = sm.vec3.bezier3( p1, p2, p3, p4, (i-1) / steps ),
					endPos = sm.vec3.bezier3( p1, p2, p3, p4, i / steps )
				}
			else
				local prev = positions[i-1]
				positions[#positions+1] = {
					startPos = prev.endPos,
					endPos = sm.vec3.bezier3( p1, p2, p3, p4, i / steps ) --sm.noise.gunSpread( sm.vec3.bezier3( p1, p2, p3, p4, i / steps ), 2 )
				}
			end
		end

		for k, v in pairs(positions) do
			local beam = self.cl.beam.beamTest[k]

			beam:update(
				v.startPos,
				v.endPos,
				true,
				dt,
				250
			)
		end]]
	elseif self.cl.beam.curvedTest.effects[1].effect:isPlaying() then
		for k, v in pairs(self.cl.beam.curvedTest.effects) do
			v.effect:stopImmediate()
		end

		self.cl.beam.curvedTest.sound:stopImmediate()
	end
	--[[elseif self.cl.beam.beamTest[1].effect:isPlaying() then
		for i = 1, #self.cl.beam.beamTest do
			self.cl.beam.beamTest[i].effect:stopImmediate()
		end
	end]]
	--[[elseif self.cl.beam.effect.effect:isPlaying() then
		self.cl.beam.effect.effect:stopImmediate()
	end]]

	local increase = dt * self.cl.powerups.speedMultiplier.current

	-- First person animation
	local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()
	local isLocal = self.tool:isLocal()

	if isLocal then
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

	if isLocal then

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

		self.cl.blast.effect:setPosition( effectPos )
		self.cl.blast.effect:setRotation( rot )
	end
	local pos = self.tool:getTpBonePos( "pejnt_barrel" )
	local dir = self.tool:getTpBoneDir( "pejnt_barrel" )

	effectPos = pos + dir * 0.2

	rot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), dir )


	self.shootEffect:setPosition( effectPos )
	self.shootEffect:setVelocity( self.tool:getMovementVelocity() )
	self.shootEffect:setRotation( rot )

	if not isLocal then
		self.cl.blast.effect:setPosition( effectPos )
		self.cl.blast.effect:setRotation( rot )
	end

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
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0 or self.cl.currentWeaponMod == self.mod2 and self.cl.usingMod
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

function PRifle.client_onEquip( self, animate )
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

function PRifle.client_onUnequip( self, animate )
	self.cl.beam.effectTarget = nil

	if animate then
		sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
	end

	self.wantEquipped = false
	self.equipped = false
	setTpAnimation( self.tpAnimations, "putdown" )
	if self.tool:isLocal() then
		self.cl.beam.targets = {}

		if self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	end
end

function PRifle.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end

	if state == sm.tool.interactState.start then

		if not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), se_ammo_plasma, 1 ) then
			local owner = self.tool:getOwner()

			if owner and self.cl.currentWeaponMod == "poor" or owner and not self.cl.usingMod and not self.cl.modSwitch.active then
				if self.cl.currentWeaponMod == self.mod1 and not self.cl.blast.fireDelay.active or self.cl.currentWeaponMod == self.mod2 then
					self:shootProjectile( proj_plasma, self.cl.Damage * self.cl.powerups.damageMultiplier.current )

					if self.cl.currentWeaponMod == self.mod1 and self.cl.blastCharge < 60 and not self.cl.blast.masteryEffect.active then
						self.cl.blastCharge = self.cl.blastCharge + self.cl.blastChargeIncrease
					end
				end
			end
		end
	end

	if state == sm.tool.interactState.stop then
		self.cl.blast.fireDelay.active = true
	end
end

function PRifle.cl_onSecondaryUse( self, state )
	if state == sm.tool.interactState.start then
		if self.cl.currentWeaponMod == self.mod1 then
			local level = self.cl.blastCharge/20
			if level >= 1 then
				self.network:sendToServer("sv_blast",
					{
						pos = self.cl.owner.character.worldPosition + (sm.localPlayer.getDirection() * 2.5),
						level = level
					}
				)

				self.cl.blastCharge = 0

				self:onShoot( false )
				self.network:sendToServer( "sv_n_onShoot", false )
				setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )

				if self.cl.weaponData.mod1.mastery.owned then
					self.cl.blast.masteryEffect.active = true
					self.cl.Damage = self.cl.Damage + level * 10
				end
			else
				sm.audio.play( "RaftShark" )
			end
		elseif self.cl.currentWeaponMod == self.mod2 then
			self.tool:setMovementSlowDown( true )
			self.cl.beam.cd.active = true
		end
	elseif state == sm.tool.interactState.stop or state == sm.tool.interactState.null and self.cl.currentWeaponMod == self.mod2 then
		self.tool:setMovementSlowDown( false )
		self.cl.beam.cd.active = true
		self.cl.beam.targets = {}
		self.network:sendToServer("sv_updateBeamTarget", nil)
	end
end

function PRifle.client_onEquippedUpdate( self, primaryState, secondaryState )
	self.cl.baseWeapon.onEquipped( self, primaryState, secondaryState )

	if self.cl.currentWeaponMod == self.mod1 and not self.cl.modSwitch.active then
		sm.gui.setProgressFraction(self.cl.blastCharge/60)
	end

	if self.cl.currentWeaponMod == self.mod2 and not self.cl.modSwitch.active and not self.cl.beam.targets[1] then
		sm.gui.setProgressFraction(self.cl.beam.cd.timer.count/self.cl.beam.cd.timer.ticks)
	elseif self.cl.currentWeaponMod == self.mod2 and self.cl.usingMod and self.cl.beam.targets[1] then
		local data = se.unitData[self.cl.beam.targets[1].id]
		if data ~= nil then
			--self.cl.beam.hud:setSliderPosition( "chargeSlider", 1600 * (data.data.stats.hp/data.data.stats.maxhp)  )
			sm.gui.setProgressFraction(data.data.stats.hp/data.data.stats.maxhp)
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
