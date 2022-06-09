dofile "$CONTENT_DATA/Scripts/se_util.lua"

BBall = class()
BBall.damageFrequency = 4
BBall.damage = 25
BBall.speed = 0.35

function BBall:server_onCreate()
    self.sv = {}
    self.sv.damageCounter = Timer()
    self.sv.damageCounter:start(self.damageFrequency)
    self.network:setClientData( { params = self.params, units = {} } )
end

function BBall:server_onFixedUpdate(dt)
    self.sv.damageCounter:tick()
    self.params.pos = self.params.pos + self.params.dir * self.speed

    local hit, result = sm.physics.raycast( self.params.pos, self.params.pos + self.params.dir * self.speed )
    if hit or sm.game.getServerTick() - self.params.spawnTick == self.params.maxLifeTime then
        self.scriptableObject:destroy()
    else
        local reachableUnits = {}

        for _, unit in ipairs(sm.unit.getAllUnits()) do
            local unitPos = unit.character.worldPosition
            local hit, result = sm.physics.raycast(self.params.pos, unitPos)

            if hit and result:getCharacter() == unit:getCharacter() then
                table.insert(reachableUnits, unit)
            end
        end

        if self.sv.damageCounter:done() then
            self.sv.damageCounter:start(self.damageFrequency)
            for _, unit in ipairs(reachableUnits) do
                local unitPos = unit.character.worldPosition
                sm.event.sendToUnit(
                    unit,
                    "sv_se_takeDamage",
                    {
                        damage = self.damage,
                        impact = unitPos - self.params.pos,
                        hitPos = unitPos,
                        attacker = self.params.attacker
                    }
                )
            end
        end

        self.network:setClientData({ params = self.params, units = reachableUnits })
    end
end

--Client
function BBall:client_onCreate()
    self.cl = {}
    self.cl.effect = sm.effect.createEffect("BFG Ball")
    self.cl.effect:setPosition(self.cl.pos)
    self.cl.beams = {}
end

function BBall:client_onClientDataUpdate(data, channel)
    self.params = data.params
    self.cl.units = data.units
end

function BBall:client_onFixedUpdate()
    if not self.params or #self.params == 0 then
        return
    end

    print(self.params)
    self.cl.effect:setPosition(self.params.pos)
    local deltaUnitBeam = #self.cl.units - #self.cl.beams

    -- Only runs if #unity > #beams
    for i = 1, deltaUnitBeam do
        local effect = sm.effect.createEffect("ShapeRenderable")
        effect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
        effect:setParameter("color", sm.color.new(0, 1, 0, 1))
        table.insert(self.cl.beams, { unit = self.cl.units[#self.cl.beams + 1], effect = effect })
    end

    -- Only runs if #units < #beams
    for i = 1, -deltaUnitBeam do
        local beam = table.remove(self.cl.beams)
        beam:destroy()
    end

    for _, beam in pairs(self.cl.beams) do
        local char = beam.unit:getCharacter()

        if not (char and beam.effect) then
            goto continue
        end

        local charPos = char:getWorldPosition()
        local delta = self.cl.pos - charPos
        beam.effect:setPosition((charPos + self.cl.pos) / 2)
        beam.effect:setScale(sm.vec3.new(0.05, 0.05, delta:length()))
        beam.effect:setRotation(sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta))

        if not beam.effect:isPlaying() then
            beam.effect:start()
        end

        ::continue::
    end
end

function BBall:client_onDestroy()
    for k, beam in pairs(self.cl.beams) do
        beam.effect:destroy()
    end

    self.cl.effect:destroy()
    sm.effect.playEffect("PropaneTank - ExplosionSmall", self.params.pos)
end