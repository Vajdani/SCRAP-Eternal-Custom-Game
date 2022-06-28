dofile "$CONTENT_DATA/Scripts/se_items.lua"

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
meathookMaxHorizontalAngle = 30 / 4
meathookMaxVerticalAngle = 20 / 4

--se_util.lua
se = {}
se.vec3 = {}
se.unit = {}
se.physics = {}
se.player = {}
se.unitData = {}

--Vec3
se.vec3.strip = function( vector, axis )
    if axis == "x" then
        vector.x = 0
    elseif axis == "y" then
        vector.y = 0
    elseif axis == "z" then
        vector.z = 0
    end

    return vector
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

se.player.getRaycast = function ( player, range, body, mask )
    local char = player.character
    local pos = char.worldPosition + camPosDifference

    local hit, result = sm.physics.raycast(pos, pos + char.direction * range, body, mask)
    return hit, result
end

--Weapon
se_weapon_isInvalidMeathookDir = function( dir )
	return math.abs(dir.z) > meathookMaxHorizontalAngle or math.abs(dir.x) > meathookMaxVerticalAngle
end



--Classes
Line = class()
Line.init = function( self, thickness, colour )
    self.effect = sm.effect.createEffect("ShapeRenderable")
	self.effect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
    self.effect:setParameter("color", colour)
    self.effect:setScale( se.vec3.num(thickness) )

    self.thickness = thickness
end

Line.update = function( self, startPos, endPos )
	local delta = (startPos - endPos)
    local length = delta:length()

    if length < 0.0001 then
        sm.log.warning("Line:update() | Length of 'startPos - endPos' must be longer than 0.")
        return
	end

	local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta)
	local distance = sm.vec3.new(self.thickness, self.thickness, length)

	self.effect:setPosition(startPos + delta * 0.5)
	self.effect:setScale(distance)
	self.effect:setRotation(rot)

    if not self.effect:isPlaying() then
        self.effect:start()
    end
end

Line.destroy = function( self )
    self.effect:destroy()
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