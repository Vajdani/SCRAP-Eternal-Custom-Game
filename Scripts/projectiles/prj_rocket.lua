dofile "$CONTENT_DATA/Scripts/se_util.lua"

Rocket = class()
Rocket.speed = 0.5
Rocket.maxLifeTime = 15 * 40
Rocket.turnSpeed = 7.5

function Rocket:server_onCreate()
    self.sv = {}
    self.sv.pos = self.params.pos
    self.sv.dir = self.params.dir
    self.params.target = self.params.target
    self.sv.trigger = sm.areaTrigger.createSphere( 7.5, self.params.pos, sm.quat.identity(), sm.areaTrigger.filter.character )
end

function Rocket:server_onFixedUpdate(dt)
    if not sm.exists(self.scriptableObject) then return end

    local tick = sm.game.getServerTick()
    self.sv.pos = self.sv.pos + self.sv.dir * self.speed
    self.sv.trigger:setWorldPosition(self.sv.pos)
    local hit, result = sm.physics.raycast( self.sv.pos, self.sv.pos + self.sv.dir * self.speed )
    local hitChar = result:getCharacter()
    local shouldExplode = hit and (hitChar == nil or not hitChar:isPlayer() or hitChar:getPlayer() ~= self.params.owner)

    if shouldExplode or tick - self.params.spawnTick == self.maxLifeTime then
        self:sv_doRocketExplosion()
    elseif self.params.tracking and tick - self.params.spawnTick > 10 then
        if sm.exists(self.params.target) then
            local targetPos = self.params.target:getWorldPosition()
            local targetDir = targetPos + (self.params.target:getVelocity() / 2) - self.sv.pos

            local rot = self.sv.dir:cross( targetDir )
            self.sv.dir = sm.vec3.rotate(self.sv.dir, math.rad(rot.y * self.turnSpeed), se.vec3.right())
            self.sv.dir = sm.vec3.rotate(self.sv.dir, math.rad(rot.z * self.turnSpeed), se.vec3.up())

            --[[local rot = sm.vec3.getRotation( self.sv.dir, self.params.target:getWorldPosition() - self.sv.pos )
            local newRot = rot * self.sv.dir
            self.sv.dir = self.sv.dir * 0.8 + newRot * 0.3]]
        end
    end
end

function Rocket:sv_onDetonate()
    self:sv_doRocketExplosion( true )
end

function Rocket:sv_doRocketExplosion( det )
    local index = "normal"
    if self.params.target ~= nil then
        index = "small"
    elseif self.params.flare and det ~= nil and det == true and #enemiesInTrigger( self.sv.trigger ) > 0 and self.params.type == "detonate" then
        index = "big"
    end

    local params = rocketExplosionLevels[index]
    local rawMult = self.params.owner:getPublicData().data.playerData.damageMultiplier
    se.physics.explode(self.sv.pos, params.level * (rawMult > 1 and rawMult / 2 or rawMult), params.desRad, params.impRad, params.mag, params.effect, nil, self.params.owner, self.params.falter)
    self.scriptableObject:destroy()
end



--Client
function Rocket:client_onCreate()
    self.cl = {}
    self.cl.pos = self.params.pos
    self.cl.dir = self.params.dir
    self.cl.effect = sm.effect.createEffect("Rocket")
    self.cl.thrust = sm.effect.createEffect("Thruster - Level 5")
    self.cl.flare = sm.effect.createEffect("Rocket Flair")
    self.cl.trigger = sm.areaTrigger.createSphere( 7.5, self.params.pos, sm.quat.identity(), sm.areaTrigger.filter.character )

    self.cl.effect:setPosition(self.cl.pos)
    self.cl.effect:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.params.dir ) )
    self.cl.effect:start()

    self.cl.thrust:setPosition(self.cl.pos)
    self.cl.thrust:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 0, -1 ), self.params.dir ) )
    self.cl.thrust:start()

    self.cl.flare:setPosition(self.cl.pos)
end

function Rocket:client_onUpdate( dt )
    if self.cl == nil or not sm.exists(self.scriptableObject) then return end

    local smooth = dt / (1/40)
    self.cl.pos = self.cl.pos + self.cl.dir * self.speed * smooth
    if self.params.flare and self.params.type == "detonate" and #enemiesInTrigger(self.cl.trigger) > 0 then
        self.cl.flare:setPosition(self.cl.pos)
        if not self.cl.flare:isPlaying() then
            self.cl.flare:start()
        end
    elseif self.cl.flare:isPlaying() then
        self.cl.flare:stop()
    end

    if self.params.tracking and sm.game.getCurrentTick() - self.params.spawnTick > 10 then
        if sm.exists(self.params.target) then
            local targetPos = self.params.target:getWorldPosition()
            local targetDir = targetPos + (self.params.target:getVelocity() / 2) - self.cl.pos

            local rot = self.cl.dir:cross( targetDir )
            self.cl.dir = sm.vec3.rotate(self.cl.dir, math.rad(rot.y * self.turnSpeed * smooth), se.vec3.right())
            self.cl.dir = sm.vec3.rotate(self.cl.dir, math.rad(rot.z * self.turnSpeed * smooth), se.vec3.up())

            --[[local rot = sm.vec3.getRotation( self.cl.dir, self.params.target:getWorldPosition() - self.cl.pos )
            local newRot = rot * self.cl.dir
            self.cl.dir = self.cl.dir * 0.8 + newRot * 0.3]]
        end
    end

    self.cl.effect:setPosition(self.cl.pos)
    self.cl.effect:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), self.cl.dir ) )

    self.cl.thrust:setPosition(self.cl.pos)
    self.cl.thrust:setRotation( sm.vec3.getRotation( sm.vec3.new( 0, 0, -1 ), self.cl.dir ) )

    self.cl.trigger:setWorldPosition(self.cl.pos)
end

function Rocket:client_onDestroy()
    self.cl.effect:destroy()
    self.cl.thrust:destroy()
    self.cl.flare:destroy()
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