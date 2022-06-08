BBall = class()

dofile "$CONTENT_DATA/Scripts/se_util.lua"

BBall.damageFrequency = 40 / 10
BBall.damage = 25
BBall.speed = 0.35

function BBall.sv_onCreate( self, args )
    self.sv = {}
    self.sv.pos = args.pos
    self.sv.dir = args.dir
    self.sv.spawnTick = args.tick
    self.sv.maxLifeTime = args.maxLifeTime
    self.sv.owner = args.owner
    self.sv.damageCounter = Timer()
    self.sv.damageCounter:start(self.damageFrequency)

    self.network:sendToClients("cl_onCreate", args)
end

function BBall.sv_onFixedUpdate( self, dt )
    self.sv.pos = self.sv.pos + self.sv.dir * self.speed

    local reachableUnits = {}
    self.sv.damageCounter:tick()
    if self.sv.damageCounter:done() then
        self.sv.damageCounter:start(self.damageFrequency)
        for k, unit in pairs(sm.unit.getAllUnits()) do
            local unitPos = unit.character.worldPosition

            local hit, result = sm.physics.raycast(self.sv.pos, unitPos)
            if hit and result:getCharacter() == unit:getCharacter() then
                sm.event.sendToUnit(unit, "sv_se_takeDamage",
                    {
                        damage = self.damage,
                        impact = unitPos - self.sv.pos,
                        hitPos = unitPos,
                        attacker = self.sv.owner
                    }
                )

                reachableUnits[#reachableUnits+1] = unit
            end
        end
    end

    local sent = copyTable(self.sv)
    sent.units = reachableUnits
    self.network:sendToClients("cl_onFixedUpdate", sent)
end

function BBall.sv_onDestroy( self )
    sm.effect.playEffect("PropaneTank - ExplosionSmall", self.sv.pos)
    self.network:sendToClients("cl_onDestroy")
end



--Client
function BBall.cl_onCreate( self, args )
    self.cl = {}
    self.cl.pos = args.pos
    self.cl.dir = args.dir
    self.cl.effect = sm.effect.createEffect("BFG Ball")
    self.cl.effect:setPosition(self.cl.pos)

    self.cl.beams = {}
end

function BBall.cl_onFixedUpdate( self, args )
    self.cl.pos = args.pos
    self.cl.dir = args.dir
    self.cl.effect:setPosition(self.cl.pos)

    local unitCount = #args.units
    local beamCount = #self.cl.beams
    if unitCount > beamCount then
        for i = 1, unitCount - beamCount do
            local effect = sm.effect.createEffect("ShapeRenderable")
            effect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
            effect:setParameter("color", sm.color.new(0, 1, 0, 1))
            self.cl.beams[#self.cl.beams+1] = { unit = args.units[beamCount + i], effect = effect }
        end
    elseif unitCount < beamCount then
        for i = 1, beamCount - unitCount do
            local index = beamCount - 1
            self.cl.beams[index].effect:stop()
            self.cl.beams[index].effect = nil
        end
    end

    for k, beam in pairs(self.cl.beams) do
        local char = beam.unit:getCharacter()

        if char then
            local charPos = char:getWorldPosition()
            local delta = (self.cl.pos - charPos)
            local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta)
            local distance = sm.vec3.new(0.05, 0.05, delta:length())

            if beam.effect then
                beam.effect:setPosition(charPos + delta * 0.5)
                beam.effect:setScale(distance)
                beam.effect:setRotation(rot)

                if not beam.effect:isPlaying() then
                    beam.effect:start()
                end
            end
        end
    end
end

function BBall.cl_onDestroy( self )
    for k, beam in pairs(self.cl.beams) do
        beam.effect:stop()
        beam.effect = nil
    end

    self.cl.effect:stop()
    self.cl.effect = nil
end