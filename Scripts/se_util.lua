--constants
freezeColour = sm.color.new("#0c97c9")
camPosDifference = sm.vec3.new(0,0,0.575)
up = sm.vec3.new(0,0,1)
bloodFueledSpeedFraction = 1.5
airControlSpeed = 20
projectileSaveKey = "DOOM_Projectiles"

--se_util.lua
se = {}
se.vec3 = {}
se.unit = {}
se.physics = {}
se.player = {}

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
    local attackerCharId = attacker:getCharacter():getId()

    local explodeTrigger = sm.areaTrigger.createSphere( destructionRadius, position, sm.quat.identity(), sm.areaTrigger.filter.character )
    for v, unit in pairs(explodeTrigger:getContents()) do
        local unitChar = unit:getCharacter()
        if unitChar:getId() ~= attackerCharId then
            local unitPos = unitChar:getWorldPosition()
            sm.event.sendToUnit(unit, "sv_se_onExplosion",
                {
                    damage = level * 2,
                    impact = position - unitPos,
                    hitPos = unitPos,
                    attacker = attacker,
                    falter = falter
                }
            )
        end
    end
    sm.areaTrigger.destroy( explodeTrigger )


    local impulseTrigger = sm.areaTrigger.createSphere( impulseRadius, position, sm.quat.identity(), sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody )
    for v, obj in pairs(impulseTrigger:getContents()) do
        sm.physics.applyImpulse(
            obj,
            (obj:getWorldPosition() - position):length() * magnitude,
            true
        )
    end
    sm.areaTrigger.destroy( impulseTrigger )

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

--Other
function copyTable( table )
    local returned = {}
    for v, k in pairs(table) do
        returned[v] = k
    end

    return returned
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