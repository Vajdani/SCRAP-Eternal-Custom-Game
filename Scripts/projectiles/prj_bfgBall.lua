dofile "$CONTENT_DATA/Scripts/se_util.lua"

BBall = class()
BBall.damageFrequency = 4
BBall.damage = 25
BBall.speed = 0.2
BBall.maxLifeTime = 8 * 40

function BBall:server_onCreate()
    self.sv = {}
    self.sv.damageCounter = Timer()
    self.sv.damageCounter:start(self.damageFrequency)
end

function BBall:server_onFixedUpdate(dt)
    if not sm.exists(self.scriptableObject) then return end

    local tick = sm.game.getServerTick()
    local hit, result = sm.physics.raycast( self.cl.pos, self.cl.pos + self.cl.dir )

    if hit or tick - self.params.spawnTick >= self.maxLifeTime then
        sm.physics.explode( self.cl.pos, 10, 2.5, 5, 100, "BFG Explode" )
        self.scriptableObject:destroy()
        return
    end

    self.sv.damageCounter:tick()
    if self.sv.damageCounter:done() then
        self.sv.damageCounter:reset()
        for k, char in pairs(self.cl.trigger:getContents()) do
            if sm.exists(char) and not char:isPlayer() and sm.exists(char:getUnit()) then
                local charPos = char.worldPosition
                local hit, result = sm.physics.raycast(self.cl.pos, charPos, sm.areaTrigger.filter.character)
                if hit and result:getCharacter() == char then
                    sm.event.sendToUnit(char:getUnit(), "sv_se_takeDamage",
                        {
                            damage = self.damage,
                            impact = charPos - self.cl.pos,
                            hitPos = charPos,
                            attacker = self.params.owner
                        }
                    )
                end
            end
        end
    end
end

--Client
function BBall:client_onCreate()
    self.cl = {}
    self.cl.pos = self.params.pos
    self.cl.dir = self.params.dir
    self.cl.effect = sm.effect.createEffect("BFG Ball")
    self.cl.trigger = sm.areaTrigger.createSphere( 50, self.params.pos, sm.quat.identity(), sm.areaTrigger.filter.character )
    self.cl.beams = {}

    self.cl.effect:setPosition(self.cl.pos)
    self.cl.effect:start()
end

function BBall:client_onUpdate( dt )
    if self.cl == nil or not sm.exists(self.scriptableObject) then return end

    self.cl.pos = self.cl.pos + self.cl.dir * self.speed * ( dt / (1/40) )
    self.cl.effect:setPosition(self.cl.pos)
    self.cl.trigger:setWorldPosition(self.cl.pos)

    local triggerContents = self.cl.trigger:getContents()
    for k, char in pairs(triggerContents) do
        if sm.exists(char) and not char:isPlayer() and self.cl.beams[k] == nil then
            self.cl.beams[k] = {
                char = char,
                effect = Line()
            }

            self.cl.beams[k].effect:init( 0.05, sm.color.new(0, 1, 0) )
        end
    end

    for k, beam in pairs(self.cl.beams) do
        if sm.exists(beam.char) then
            local charPos = beam.char:getWorldPosition()
            local hit, result = sm.physics.raycast(self.cl.pos, charPos, sm.areaTrigger.filter.character)
            if isAnyOf(beam.char, triggerContents) and hit and result:getCharacter() == beam.char then
                beam.effect:update( self.cl.pos, charPos, dt, 100 )
            else
                beam.effect:stop()
            end
        else
            beam.effect:stop()
            self.cl.beams[k] = nil
        end
    end
end

function BBall:client_onDestroy()
    for k, beam in pairs(self.cl.beams) do
        beam.effect:stop()
    end

    self.cl.effect:destroy()
end