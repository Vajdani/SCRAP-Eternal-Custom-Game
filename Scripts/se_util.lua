dofile "$CONTENT_DATA/Scripts/se_items.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

--constants
freezeColour = sm.color.new("#0c97c9")
camPosDifference = sm.vec3.new(0,0,0.575)
up = sm.vec3.new(0,0,1)
bloodFueledSpeedFraction = 1.5
airControlSpeed = 20
projectileSaveKey = "DOOM_Projectiles"
grenades = {
	{ throwable = grn_grenade, name = "Frag Grenade" },
	{ throwable = grn_icebomb, name = "Ice Bomb" },
	{ throwable = grn_imploGrenade, name = "Implosion Bomb" }
}
dashImpulse = sm.vec3.new(2500, 2500, 0)
gkMinSpeed = 2
gkDistanceDivider = 2
bloodFueledDuration = 5 * 40
gkAnims = {
	--front
	{
		[tostring(unit_totebot_green)] = {
			normal = {
				{
					name = "parry",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}--[[,
				{
					name = "kick",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}]]
			},
			chainsaw = {
				{
					name = "parry",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}
			}
		},
		[tostring(unit_haybot)] = {

		},
		[tostring(unit_tapebot)] = {

		},
		[tostring(unit_farmbot)] = {

		}
	},
	--back
	{
		[tostring(unit_totebot_green)] = {
			normal = {
				{
					name = "parry",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}--[[,
				{
					name = "kick",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}]]
			},
			chainsaw = {
				{
					name = "parry",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}
			}
		},
		[tostring(unit_haybot)] = {

		},
		[tostring(unit_tapebot)] = {

		},
		[tostring(unit_farmbot)] = {

		}
	},
	--left
	{
		[tostring(unit_totebot_green)] = {
			normal = {
				{
					name = "parry",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}--[[,
				{
					name = "kick",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}]]
			},
			chainsaw = {
				{
					name = "parry",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}
			}
		},
		[tostring(unit_haybot)] = {

		},
		[tostring(unit_tapebot)] = {

		},
		[tostring(unit_farmbot)] = {

		}
	},
	--right
	{
		[tostring(unit_totebot_green)] = {
			normal = {
				{
					name = "parry",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}--[[,
				{
					name = "kick",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}]]
			},
			chainsaw = {
				{
					name = "parry",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}
			}
		},
		[tostring(unit_haybot)] = {

		},
		[tostring(unit_tapebot)] = {

		},
		[tostring(unit_farmbot)] = {

		}
	},
	--up
	{
		[tostring(unit_totebot_green)] = {
			normal = {
				{
					name = "parry",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}--[[,
				{
					name = "kick",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}]]
			},
			chainsaw = {
				{
					name = "parry",
					sound = "Sledgehammer - Swing",
					endSound = "",
					effect = "",
					endEffect = "Sledgehammer - Hit",
					action = "throw",
					divide = 2
				}
			}
		},
		[tostring(unit_haybot)] = {

		},
		[tostring(unit_tapebot)] = {

		},
		[tostring(unit_farmbot)] = {

		}
	}
}
punchDuration = 0.833333
grenadeThrowCoolDown = 1 * 40
mmOPDuration = 5 * 40
defaultPrpDuration = 30 * 40
rocketExplosionLevels = {
    big = {
        level = 30,
        desRad = 10,
        impRad = 15,
        mag = 100,
        effect = "PropaneTank - ExplosionBig"
    },
    small = {
        level = 10,
        desRad = 2.5,
        impRad = 5,
        mag = 50,
        effect = "PropaneTank - ExplosionSmall"
    },
    normal = {
        level = 20,
        desRad = 5,
        impRad = 10,
        mag = 75,
        effect = "PropaneTank - ExplosionSmall"
    }
}
implosionBombImpulse = sm.vec3.one() * 500
meathookMaxHorizontalAngle = 0.3
meathookMaxVerticalAngle = 0.2
beamMaxHorizontalAngle = 0.25
beamMaxVerticalAngle = 0.1

--se_util.lua
se = {}
se.vec3 = {}
se.unit = {}
se.physics = {}
se.player = {}
se.unitData = {}
se.quat = {}

--Vec3
se.vec3.strip = function( vec, axis )
  	vec[axis] = 0

    return vec
end

se.vec3.abs = function( vector )
    return sm.vec3.new(math.abs(vector.x), math.abs(vector.y), math.abs(vector.z))
end

se.vec3.add = function( vector, axis, value )
    if axis == "x" then
        vector.x = vector.x + value
    elseif axis == "y" then
        vector.y = vector.y + value
    elseif axis == "z" then
        vector.z = vector.z + value
    end

    return vector
end

se.vec3.redirectVel = function( axis, value, char )
    if axis == "x" then
        return sm.vec3.new( char:getVelocity().x * -1 * char:getMass() + value, 0, 0 )
    elseif axis == "y" then
        return sm.vec3.new( 0, char:getVelocity().y * -1 * char:getMass() + value, 0 )
    elseif axis == "z" then
        return sm.vec3.new( 0, 0, char:getVelocity().z * -1 * char:getMass() + value )
    end
end

se.vec3.num = function( num )
    return sm.vec3.new(num, num, num)
end

se.vec3.up = function()
    return sm.vec3.new(0,0,1)
end

se.vec3.right = function()
    return sm.vec3.new(0,1,0)
end

--Unit
se.unit.spawnDroplets = function( type, origin, worldPosition, ringAngle )
    if worldPosition == nil then
        local character = origin:getCharacter()
        if character then
            worldPosition = character.worldPosition
        end
    end

    ringAngle = ringAngle or math.pi / 18

    if worldPosition then
        local dir = sm.vec3.new( 0.0, 1.0, 0.0 )
        local up = sm.vec3.new( 0, 0, 1 )

        dir = dir:rotate( math.random() * 2 * math.pi, up )
        local right = dir:cross( up )
        dir = dir:rotate( math.pi / 2 - ringAngle - math.random() * ( 3 * ringAngle ), right )

        local vel = dir * (4+math.random()*2)

        sm.projectile.projectileAttack( type, 0, worldPosition, vel, origin, worldPosition, worldPosition, 0 )
    end
end

--Physics
se.physics.explode = function( position, level, destructionRadius, impulseRadius, magnitude, effect, ignoreShape, attacker, falter )
    local explodeContacts = sm.physics.getSphereContacts( position, destructionRadius )
    for v, char in pairs(explodeContacts.characters) do
        local charPos = char:getWorldPosition()
        local unit = char:getUnit()
        if unit ~= nil then
            sm.event.sendToUnit(unit, "sv_se_onExplosion",
                {
                    damage = level * 2,
                    impact = position - charPos,
                    hitPos = charPos,
                    attacker = attacker,
                    falter = falter
                }
            )
        else
            sm.event.sendToPlayer(char:getPlayer(), "sv_se_onExplosion",
                {
                    damage = level * 2,
                    impact = position - charPos,
                    hitPos = charPos,
                    attacker = attacker,
                    falter = falter
                }
            )
        end
    end

    local impulseContacts = sm.physics.getSphereContacts( position, impulseRadius )
    for v, obj in pairs( addTables({ impulseContacts.characters, impulseContacts.bodies }) ) do
        --local adjust = type(obj) == "Character" and obj:getHeight() / 2 or 0

        if type(obj) ~= "Body" or not isAnyOf(obj:getShapes()[1].uuid, { grn_grenade, grn_icebomb, grn_imploGrenade }) then
            local dir = obj:getWorldPosition() - position
            sm.physics.applyImpulse(
                obj,
                dir:normalize() * magnitude * (impulseRadius - dir:length()),
                true
            )
        end
    end

    sm.effect.playEffect(effect, position)
end

function se_raycast_getHitObj(raycastResult)
	return raycastResult:getShape() or raycastResult:getBody() or raycastResult:getCharacter() or raycastResult:getHarvestable() or raycastResult:getJoint() or raycastResult.type
end



--Player
se.player.isEquippedRune = function ( player, name )
    for v, rune in pairs(player:getPublicData().data.suitData.runes.equipped) do
        if name == rune.name then
            return true, rune
        end
    end

    return false, nil
end

se.player.reduceRecharge = function( player, type )
    local equipped, rune = se.player.isEquippedRune( player, "Equipment Fiend" )
    if equipped and rune ~= nil then
        sm.event.sendToPlayer( player, "sv_reduceRecharge", { equipment = type, reduction = rune.buff.cdReduction } )
    end
end

se.player.isOnGround = function( player )
    local charPos = player:getCharacter():getWorldPosition()
    return sm.physics.sphereContactCount( charPos - sm.vec3.new(0,0,0.72), 0.3 ) > 1 or sm.physics.raycast( charPos, charPos - sm.vec3.new(0,0,0.78) )
end

se.player.getMoveDir = function( player, data )
    local moveDir = sm.vec3.zero()

	local dir = player.character:getDirection()
	local camUp = dir:rotate(math.rad(90), dir:cross(up))

	local left = camUp:cross(dir)
	local right = left * -1
	local fwd = up:cross(right)
	local bwd = fwd * -1

	local moveDirs = {
		{ id = sm.interactable.actions.forward,         dir = fwd   },
		{ id = sm.interactable.actions.backward,        dir = bwd   },
		{ id = sm.interactable.actions.left,            dir = left  },
		{ id = sm.interactable.actions.right,           dir = right },
	}

	for v, k in pairs(moveDirs) do
		if data.input[k.id] then
			moveDir = moveDir + k.dir
		end
	end

	return moveDir, moveDirs
end

se.player.getRaycast = function( player, range, body, mask )
    local char = player.character
    local pos = char.worldPosition + camPosDifference

    local hit, result = sm.physics.raycast(pos, pos + char.direction * range, body, mask)
    return hit, result
end


--Quat
--Thanks to 00Fant for this function
--https://discord.com/channels/722093268095205406/971007192545255464/980055810417754143 (in his discord server https://discord.gg/C7dUD8npzP)
se.quat.lookRot = function( forward, up )
    local vector = sm.vec3.normalize( forward )
    local vector2 = sm.vec3.normalize( sm.vec3.cross( up, vector ) )
    local vector3 = sm.vec3.cross( vector, vector2 )
    local m00 = vector2.x
    local m01 = vector2.y
    local m02 = vector2.z
    local m10 = vector3.x
    local m11 = vector3.y
    local m12 = vector3.z
    local m20 = vector.x
    local m21 = vector.y
    local m22 = vector.z
    local num8 = (m00 + m11) + m22
	local quaternion = sm.quat.identity()
    if num8 > 0 then
        local num = math.sqrt(num8 + 1)
        quaternion.w = num * 0.5
        num = 0.5 / num
        quaternion.x = (m12 - m21) * num
        quaternion.y = (m20 - m02) * num
        quaternion.z = (m01 - m10) * num
        return quaternion
    end
    if (m00 >= m11) and (m00 >= m22) then
        local num7 = math.sqrt(((1 + m00) - m11) - m22)
        local num4 = 0.5 / num7
        quaternion.x = 0.5 * num7
        quaternion.y = (m01 + m10) * num4
        quaternion.z = (m02 + m20) * num4
        quaternion.w = (m12 - m21) * num4
        return quaternion
    end
    if m11 > m22 then
        local num6 = math.sqrt(((1 + m11) - m00) - m22)
		local num3 = 0.5 / num6
        quaternion.x = (m10+ m01) * num3
        quaternion.y = 0.5 * num6
        quaternion.z = (m21 + m12) * num3
        quaternion.w = (m20 - m02) * num3
        return quaternion
    end
    local num5 = math.sqrt(((1 + m22) - m00) - m11)
    local num2 = 0.5 / num5
    quaternion.x = (m20 + m02) * num2
    quaternion.y = (m21 + m12) * num2
    quaternion.z = 0.5 * num5;
    quaternion.w = (m01 - m10) * num2
    return quaternion
end


--Weapon
function se_weapon_isInvalidMeathookDir( dir )
	return math.abs(dir.z) > meathookMaxHorizontalAngle or math.abs(dir.x) > meathookMaxVerticalAngle
end

function se_weapon_isInvalidBeamDir( dir )
	return math.abs(dir.z) > beamMaxHorizontalAngle or math.abs(dir.x) > beamMaxVerticalAngle
end



--Classes
Line = class()
function Line:init( thickness, colour )
    self.effect = sm.effect.createEffect("ShapeRenderable")
	self.effect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
    self.effect:setParameter("color", colour)
    self.effect:setScale( se.vec3.num(thickness) )

    self.thickness = thickness
	self.spinTime = 0
end

function Line:update( startPos, endPos, dt, spinSpeed )
	local delta = endPos - startPos
    local length = delta:length()

    if length < 0.0001 then
        sm.log.warning("Line:update() | Length of 'endPos - startPos' must be longer than 0.")
        return
	end

	local rot = sm.vec3.getRotation(up, delta)
	local speed = spinSpeed or 1
	self.spinTime = self.spinTime + dt * speed
	rot = rot * sm.quat.angleAxis( math.rad(self.spinTime), up )

	local distance = sm.vec3.new(self.thickness, self.thickness, length)

	self.effect:setPosition(startPos + delta * 0.5)
	self.effect:setScale(distance)
	self.effect:setRotation(rot)

    if not self.effect:isPlaying() then
        self.effect:start()
    end
end


CurvedLine = class()
function CurvedLine:init( thickness, colours, steps, bendStart, soundEffect )
	self.effects = {}
	for i = 1, steps do
		self.effects[#self.effects+1] = Line()
		self.effects[i]:init( thickness, type(colours) == "table" and colours[i] or colours )
	end

	self.thickness = thickness
	self.colours = colours
	self.steps = steps
	self.bendStart = bendStart or 1
	self.activeTime = 0

	if soundEffect then
		self.sound = sm.effect.createEffect( soundEffect )
	end
end

function CurvedLine:update( p1, p2, p3, p4, dt, sizes, freqs, sineSpeed, spinSpeed )
	self.activeTime = self.activeTime + dt * sineSpeed

	if self.sound then
		self.sound:setPosition( p1 )
		if not self.sound:isPlaying() then
			self.sound:start()
		end
	end

	local positions = {}
	for i = 1, self.steps do
		--[[if i <= self.bendStart then
			positions[#positions+1] = {
				startPos = sm.vec3.bezier3( p1, p2, p3, p4, (i-1) / self.steps ),
				endPos = sm.vec3.bezier3( p1, p2, p3, p4, i / self.steps )
			}
		else]]
			local prev = positions[i-1]
			positions[#positions+1] = {
				startPos = prev and prev.endPos or p1,
				endPos = sm.vec3.bezier3( p1, p2, p3, p4, i / self.steps )
			}

			local current = positions[i]
			local size = not isAnyOf(type(sizes), {"table", "Vec3"}) and { x = sizes, y = sizes, z = sizes } or sizes
			local frequency = not isAnyOf(type(freqs), {"table", "Vec3"}) and { x = freqs, y = freqs, z = freqs } or freqs
			current.endPos = current.endPos + (i == self.steps and
				sm.vec3.zero() or
				sm.vec3.new(
					size.x * math.cos(self.activeTime - i * frequency.x),
					size.y * math.cos(self.activeTime - i * frequency.y),
					size.z * math.sin(self.activeTime - i * frequency.z)
				) * (i <= self.bendStart and sm.util.clamp(0.1 * i, 0, 1) or 1 )
			)
		--end
	end

	for k, v in pairs(positions) do
		local beam = self.effects[k]
		beam:update(
			v.startPos,
			v.endPos,
			dt,
			spinSpeed
		)
	end
end



--Other
function copyTable( table )
    local returned = {}
    for v, k in pairs(table) do
        returned[v] = k
    end

    return returned
end

function addTables( tables )
    local returned = {}
    for k, table in pairs(tables) do
        for k2, value in pairs(table) do
            local key = k2
            local valuesByKey = countValuesByKey(returned, k2)
            if valuesByKey > 0 then
                key = type(key) == "number" and key + 1 or key..tostring(valuesByKey + 1)
            end
            returned[key] = value
        end
    end

    return returned
end

function countValuesByKey( table, key )
    local count = 0
    for k, v in pairs(table) do
        if k == key then
            count = count + 1
        end
    end

    return count
end

function unlockMsgWrap( msg )
    return "#ff9d00"..msg.." #ffffffunlocked!"
end

function colourLerp(c1, c2, t)
    local r = sm.util.lerp(c1.r, c2.r, t)
    local g = sm.util.lerp(c1.g, c2.g, t)
    local b = sm.util.lerp(c1.b, c2.b, t)
    return sm.color.new(r,g,b)
end

function getGui_RunesIndexByRuneName( name )
    for k, rune in pairs(gui_runes) do
        if rune.name == name then
            return rune
        end
    end

    return nil
end

function enemiesInTrigger( trigger )
    local enemies = {}
    for k, char in pairs(trigger:getContents()) do
        if sm.exists(char) and not char:isPlayer() then
            enemies[#enemies+1] = char
        end
    end

    return enemies
end