--[[
    Thanks to Brent Batch for the homing missile direction code(line 104)
    I am too big of a dumbass to figure it out myself
    https://steamcommunity.com/sharedfiles/filedetails/?id=1995094956, found in skull.lua at line 82
]]

dofile "$CONTENT_DATA/Scripts/se_util.lua"

Rocket = class()
Rocket.speed = 0.5
Rocket.maxLifeTime = 15 * 40

function Rocket:server_onFixedUpdate(dt)
    if not sm.exists(self.scriptableObject) then return end

    local tick = sm.game.getServerTick()
    local hit, result = sm.physics.raycast( self.cl.pos, self.cl.pos + self.cl.dir * self.speed )
    local hitChar = result:getCharacter()
    local shouldExplode = hit and (hitChar == nil or not hitChar:isPlayer() or hitChar:getPlayer() ~= self.params.owner)

    if shouldExplode or tick - self.params.spawnTick == self.maxLifeTime then
        self:sv_doRocketExplosion()
    end
end

function Rocket:sv_doRocketExplosion( det )
    local index = "normal"
    if self.params.target ~= nil and sm.exists(self.params.target) then
        index = "small"
    elseif self.params.flare and det and #enemiesInTrigger( self.cl.trigger ) > 0 and self.params.type == "detonate" then
        index = "big"
    end

    local params = rocketExplosionLevels[index]
    local rawMult = self.params.owner:getPublicData().data.playerData.damageMultiplier
    se.physics.explode(self.cl.pos, params.level * (rawMult > 1 and rawMult / 2 or rawMult), params.desRad, params.impRad, params.mag, params.effect, nil, self.params.owner, self.params.falter)
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

            self.cl.dir = ((self.cl.dir*0.7 + targetDir:normalize()*(0.125 + self.cl.dir:length()*0.3) )*0.995):normalize()
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