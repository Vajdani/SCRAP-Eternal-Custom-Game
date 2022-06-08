World = class( nil )
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -2
World.cellMaxX = 1
World.cellMinY = -2
World.cellMaxY = 1
World.worldBorder = true

g_allUnits = g_allUnits or {}

dofile "$CONTENT_DATA/Scripts/se_util.lua"
dofile "$CONTENT_DATA/Scripts/projectiles/prj_bfgBall.lua"

function World.server_onCreate( self )
    print("World.server_onCreate")

    self.sv = {}
    self.sv.data = {}
    self.sv.projectiles = {
        bballs = {}
    } --sm.storage.load( projectileSaveKey ) or {}
end

function World:server_onFixedUpdate( dt )
    g_allUnits = sm.unit.getAllUnits()
    local currentTick = sm.game.getServerTick()

    self:sv_handleBBalls( currentTick )
end

function World:sv_handleBBalls( tick )
    for v, projectile in pairs(self.sv.projectiles.bballs) do
        projectile.pos = projectile.pos + projectile.dir * projectile.speed
        projectile.trigger:setWorldPosition(projectile.pos)
        local hit, result = sm.physics.raycast( projectile.pos, projectile.pos + projectile.dir * projectile.speed )

        if hit or tick - projectile.spawnTick == projectile.maxLifeTime then
            sm.effect.playEffect("PropaneTank - ExplosionSmall", projectile.pos)
            self.sv.projectiles.bballs[v] = nil
            self.network:sendToClients("cl_destroyBBall", v)
        else
            projectile.damageCounter:tick()
            if projectile.damageCounter:done() then
                projectile.damageCounter:start(projectile.damageFrequency)
                for k, char in pairs(projectile.trigger:getContents()) do
                    if sm.exists(char) and not char:isPlayer() and sm.exists(char:getUnit()) then
                        local charPos = char.worldPosition
                        local hit, result = sm.physics.raycast(projectile.pos, charPos, sm.areaTrigger.filter.character)
                        if hit and result:getCharacter() == char then
                            sm.event.sendToUnit(char:getUnit(), "sv_se_takeDamage",
                                {
                                    damage = projectile.damage,
                                    impact = charPos - projectile.pos,
                                    hitPos = charPos,
                                    attacker = projectile.owner
                                }
                            )
                        end
                    end
                end
            end
        end
    end
end

function World:sv_addBBall( args )
    --[[local projectile = BBall()
    local sent = args
    sent.tick = sm.game.getServerTick()
    projectile:sv_onCreate( sent )

    self.network:sendToClients("cl_addProjectile", { projectile = projectile, sent = sent })
    self.sv.projectiles[#self.sv.projectiles+1] = projectile]]

    local projectile = {
        pos = args.pos,
        dir = args.dir,
        spawnTick = sm.game.getServerTick(),
        maxLifeTime = 10000000, --7.5 * 40,
        owner = args.owner,
        damageFrequency = 10000000, --40 / 4,
        damage = 25,
        speed = 0,
        damageCounter = Timer(),
        trigger = sm.areaTrigger.createSphere( 50, args.pos, sm.quat.identity(), sm.areaTrigger.filter.character )
    }

    projectile.damageCounter:start(projectile.damageFrequency)
    self.sv.projectiles.bballs[#self.sv.projectiles.bballs+1] = projectile
    --sm.storage.save( projectileSaveKey, self.sv.projectiles )

    local sent = args
    sent.speed = projectile.speed
    self.network:sendToClients("cl_addBBall", sent)
end


--Client
function World:client_onCreate()
    self.cl = {}
    self.cl.projectiles = {
        bballs = {}
    }
end

function World:client_onUpdate( dt )
    self:cl_handleBBalls( dt )
end

function World:cl_handleBBalls( dt )
    for v, projectile in pairs(self.cl.projectiles.bballs) do
        projectile.pos = projectile.pos + projectile.dir * projectile.speed * ( dt / (1/40) )
        projectile.effect:setPosition(projectile.pos)
        projectile.trigger:setWorldPosition(projectile.pos)

        local triggerContents = projectile.trigger:getContents()
        for k, char in pairs(triggerContents) do
            if sm.exists(char) and not char:isPlayer() and projectile.beams[k] == nil then
                local effect = sm.effect.createEffect("ShapeRenderable")
                effect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
                effect:setParameter("color", sm.color.new(0, 1, 0, 1))
                projectile.beams[k] = { char = char, effect = effect }
            end
        end

        for k, beam in pairs(projectile.beams) do
            if sm.exists(beam.char) then
                local hit, result = sm.physics.raycast(projectile.pos, beam.char:getWorldPosition(), sm.areaTrigger.filter.character)
                if isAnyOf(beam.char, triggerContents) and hit and result:getCharacter() == beam.char then
                    local charPos = beam.char:getWorldPosition()
                    local delta = (projectile.pos - charPos)
                    local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), delta)
                    local distance = sm.vec3.new(0.05, 0.05, delta:length())

                    beam.effect:setPosition(charPos + delta * 0.5)
                    beam.effect:setScale(distance)
                    beam.effect:setRotation(rot)

                    if not beam.effect:isPlaying() then
                        beam.effect:start()
                    end
                else
                    beam.effect:stop()
                end
            else
                beam.effect:stop()
                projectile.beams[k] = nil
            end
        end
    end
end

function World:cl_addBBall( args )
    local projectile = {
        pos = args.pos,
        dir = args.dir,
        speed = args.speed,
        effect = sm.effect.createEffect("BFG Ball"),
        trigger = sm.areaTrigger.createSphere( 50, args.pos, sm.quat.identity(), sm.areaTrigger.filter.character ),
        beams = {}
    }

    projectile.effect:setPosition(projectile.pos)
    projectile.effect:start()
    self.cl.projectiles.bballs[#self.cl.projectiles.bballs+1] = projectile
end

function World:cl_destroyBBall( index )
    local ball = self.cl.projectiles.bballs[index]
    for k, beam in pairs(ball.beams) do
        beam.effect:stop()
    end

    ball.effect:stop()
    self.cl.projectiles.bballs[index] = nil
end