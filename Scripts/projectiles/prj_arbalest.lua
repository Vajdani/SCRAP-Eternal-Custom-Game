dofile "$CONTENT_DATA/Scripts/se_util.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

Arb = class()
Arb.damage = 100
Arb.speed = 1
Arb.maxLifeTime = 15 * 40
Arb.explodeTicks = 2 * 40
Arb.maxHits = 2

function Arb:server_onCreate()
    self.sv = {}
    self.sv.hitChars = {}
    self.sv.attachTick = nil
end

function Arb:server_onFixedUpdate(dt)
    if not sm.exists(self.scriptableObject) then return end

    local tick = sm.game.getServerTick()

    if  tick - self.params.spawnTick >= self.maxLifeTime or
        self.sv.attachTick and tick - self.sv.attachTick >= self.explodeTicks or
        self.cl.attachedTarget and not sm.exists(self.cl.attachedTarget) then

		local multiplier = self.params.owner:getPublicData().data.weaponData.ballista.mod1.up2.owned and 1.6 or 1
        sm.physics.explode( self.cl.pos, 6 * multiplier, 2.5 * multiplier, 3 * multiplier, 10 * multiplier, "PropaneTank - ExplosionSmall" )
        self.scriptableObject:destroy()
        return
    end

    if not self.cl.attached then
        local hit, result = sm.physics.raycast( self.cl.pos, self.cl.pos + self.cl.dir )
        if not hit then return end

        if result.type == "terrainSurface" or result.type == "terrainAsset" then
            self.network:setClientData(
                {
                    attached = true
                }
            )
            self.sv.attachTick = tick

            return
        end

        local target = result:getCharacter() or result:getBody()
        if not target or not sm.exists(target) or type(target) == "Character" and target:isPlayer() or isAnyOf(target, self.sv.hitChars) then return end

        if type(target) == "Character" then
            local unit = target:getUnit()
            if not sm.exists(unit) then return end

            local unitData = se.unitData[unit.id]

            sm.event.sendToUnit(
                unit,
                "sv_se_takeDamage",
                {
                    damage = self.damage,
                    impact = self.cl.dir,
                    hitPos = self.cl.pos,
                    attacker = self.params.owner
                }
            )

            self.sv.hitChars[#self.sv.hitChars + 1] = target
            if #self.sv.hitChars <= self.maxHits then
                self.network:sendToClients("cl_reduceSpeed")
            else
                self.sv.attachTick = tick - self.explodeTicks
            end

            if unitData.data.stats.hp - self.damage <= 0 then return end --hit char died, no need to attach
        end

        self.network:setClientData(
            {
                attached = true,
                target = target,
                pos = result.pointLocal,
                dir = self.cl.dir
            }
        )

        self.sv.attachTick = tick
    end
end

function Arb:client_onCreate()
    self.cl = {}
    self.cl.pos = self.params.pos
    self.cl.dir = self.params.dir
    self.cl.speed = self.speed
    self.cl.attached = false
    self.cl.attachedTarget = nil
    self.cl.localAttachedPos = nil
    self.cl.attachDir = nil
    self.cl.effect = sm.effect.createEffect("Arbalest Dart")

    self.cl.effect:setRotation( self.params.rot )
    self.cl.effect:setPosition(self.cl.pos)
    self.cl.effect:start()
end

function Arb:client_onUpdate( dt )
    if self.cl == nil or not sm.exists(self.scriptableObject) then return end

    if self.cl.attached then
        if self.cl.attachedTarget and sm.exists(self.cl.attachedTarget) then
            local newPos
            if type(self.cl.attachedTarget) == "Body" then
                newPos = self.cl.attachedTarget:transformPoint( self.cl.localAttachedPos )
                self.cl.effect:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.cl.attachedTarget.worldRotation * self.cl.attachDir ) )
            elseif type(self.cl.attachedTarget) == "Character" then
                newPos = self.cl.attachedTarget:getWorldPosition()
                self.cl.effect:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.cl.attachedTarget:getDirection() * self.cl.attachDir ) )
            end

            self.cl.pos = newPos
            self.cl.effect:setPosition( self.cl.pos )
        end
    else
        self.cl.pos = self.cl.pos + self.cl.dir * self.cl.speed * ( dt / (1/40) )
        self.cl.effect:setPosition(self.cl.pos)
    end
end

function Arb:client_onClientDataUpdate( data, channel )
    self.cl.attached = data.attached
    self.cl.attachedTarget = data.target
    self.cl.localAttachedPos = data.pos
    self.cl.attachDir = data.dir
end

function Arb:cl_reduceSpeed()
    self.cl.speed = self.cl.speed / 2
    if self.params.owner ~= sm.localPlayer.getPlayer() then return end

    sm.event.sendToTool( self.params.ownerTool, "cl_resetFireCooldown" )
end

function Arb:client_onDestroy()
    self.cl.effect:destroy()
end