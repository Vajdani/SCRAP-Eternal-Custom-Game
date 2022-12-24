dofile "$CONTENT_DATA/Scripts/se_util.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

---@class Sticky_cl
---@field pos Vec3
---@field dir Vec3
---@field effect Effect
---@field attachedTarget Character|Body
---@field localAttachedPos Vec3
---@field attachDir Vec3
---@field attached boolean
---@field speed number

---@class Sticky : ScriptableObjectClass
---@field cl Sticky_cl
Sticky = class()
Sticky.speed = 0.75
Sticky.damage = 10
Sticky.maxLifeTime = 5 * 40
Sticky.dropLifeTime = Sticky.maxLifeTime * 0.1
Sticky.explodeTicks = 2 * 40

function Sticky:server_onCreate()
    self.sv = {}
	self.sv.attachTick = nil
end

function Sticky:server_onFixedUpdate(dt)
    if not sm.exists(self.scriptableObject) then return end

    local tick = sm.game.getServerTick()
    if not self.cl.attached and tick - self.params.spawnTick >= self.maxLifeTime or self.sv.attachTick and tick - self.sv.attachTick >= self.explodeTicks then
        sm.physics.explode( self.cl.pos, 5, (self.params.owner:getPublicData().data.weaponData.shotgun.mod1.up2.owned and 7.25 or 5)/2, 4.0, 15.0, "PropaneTank - ExplosionSmall" )
        self.scriptableObject:destroy()
        return
    end

	if not self.cl.attached then
        local hit, result = sm.physics.raycast( self.cl.pos, self.cl.pos + self.cl.dir )
        if not hit then return end

		local hitThing = result:getCharacter() or result:getBody()
        if isAnyOf(hitThing, {"terrainSurface", "terrainAsset"}) then
            self.network:setClientData(
                {
                    attached = true
                }
            )
            self.sv.attachTick = tick

            return
        end

        if not sm.exists(hitThing) or type(hitThing) == "Character" and hitThing:isPlayer() then return end

        if type(hitThing) == "Character" then
            local unit = hitThing:getUnit()
            if not sm.exists(unit) then return end

            sm.event.sendToUnit(
                unit,
                "sv_se_onProjectile",
                {
                    damage = self.damage,
                    impact = self.cl.dir,
                    hitPos = self.cl.pos,
                    attacker = self.params.owner
                }
            )
        end

        self.network:setClientData(
            {
                attached = true,
                target = hitThing,
                pos = result.pointLocal,
                dir = self.cl.dir
            }
        )

        self.sv.attachTick = tick
    end
end


function Sticky:client_onCreate()
    self.cl = {}
    self.cl.pos = self.params.pos
    self.cl.dir = self.params.dir
    self.cl.speed = self.speed
    self.cl.attached = false
    self.cl.attachedTarget = nil
    self.cl.localAttachedPos = nil
    self.cl.attachDir = nil
    self.cl.effect = sm.effect.createEffect("Rocket")

    self.cl.effect:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.cl.dir ) )
    self.cl.effect:setPosition(self.cl.pos)
    self.cl.effect:start()
end

function Sticky:client_onUpdate( dt )
    if self.cl == nil or not sm.exists(self.scriptableObject) then return end

    if self.cl.attached and self.cl.attachedTarget and sm.exists(self.cl.attachedTarget) then
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
    else
        local minus = sm.util.lerp( 0.1, 0.4, (sm.game.getCurrentTick() - self.params.spawnTick) / self.dropLifeTime  )
        self.cl.dir.z = sm.util.clamp( self.cl.dir.z - minus * dt, -1, 1 )

        self.cl.pos = self.cl.pos + self.cl.dir * self.speed * ( dt / (1/40) )
        self.cl.effect:setPosition(self.cl.pos)

        --[[sm.camera.setCameraState(sm.camera.state.cutsceneFP)
        sm.camera.setPosition( self.cl.pos )
        sm.camera.setDirection( self.cl.dir )]]
    end
end

function Sticky:client_onClientDataUpdate( data, channel )
    self.cl.attached = data.attached
    self.cl.attachedTarget = data.target
    self.cl.localAttachedPos = data.pos
    self.cl.attachDir = data.dir
end

function Sticky:client_onDestroy()
    self.cl.effect:destroy()
    sm.camera.setCameraState(sm.camera.state.default)
end