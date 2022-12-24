---@class Shield_cl
---@field pos Vec3
---@field dir Vec3
---@field effect Effect

---@class Shield : ScriptableObjectClass
---@field cl Shield_cl
Shield = class()
Shield.damage = 150
Shield.speed = 0.6
Shield.maxLifeTime = 10 * 40

function Shield:server_onCreate()
    self.sv = {}
    self.sv.trigger = sm.areaTrigger.createBox(
        sm.vec3.new(2, 0.25, 1.5),
        self.params.pos,
        self.params.rot,
        sm.areaTrigger.filter.character
    )
	self.sv.trigger:bindOnEnter( "sv_damageUnits" )
end

function Shield:server_onFixedUpdate()
    if not sm.exists(self.scriptableObject) then return end

    local tick = sm.game.getServerTick()
    local hit, result = sm.physics.raycast( self.cl.pos, self.cl.pos + self.cl.dir )

    if (hit and result:getCharacter() == nil) or tick - self.params.spawnTick >= self.maxLifeTime then
        self.scriptableObject:destroy()
        return
    end

    self.sv.trigger:setWorldPosition( self.cl.pos )
end

function Shield:sv_damageUnits( trigger, result )
    for pos, char in pairs(result) do
        if sm.exists(char) and not char:isPlayer() then
            local unit = char:getUnit()
            sm.event.sendToUnit( unit, "sv_se_takeDamage",
                {
                    damage = self.damage,
                    impact = self.cl.dir,
                    hitPos = char:getWorldPosition(),
                    attacker = self.params.owner 
                }
            )
            sm.event.sendToUnit( unit, "sv_addStagger", 1 )
        end
    end
end



function Shield:client_onCreate()
    self.cl = {}
    self.cl.pos = self.params.pos
    self.cl.dir = self.params.dir
    self.cl.effect = sm.effect.createEffect("Energy Shield")

    self.cl.effect:setPosition( self.cl.pos )
    self.cl.effect:setRotation( self.params.rot )

    local minColor = sm.color.new( 0.0, 0.0, 0.25, 0.1 )
	local maxColor = sm.color.new( 0.0, 0.3, 0.75, 0.6 )
	self.cl.effect:setParameter( "minColor", minColor )
	self.cl.effect:setParameter( "maxColor", maxColor )

    self.cl.effect:start()
end

function Shield:client_onUpdate( dt )
    if self.cl == nil or not sm.exists(self.scriptableObject) then return end

    self.cl.pos = self.cl.pos + self.cl.dir * self.speed * ( dt / (1/40) )
    self.cl.effect:setPosition(self.cl.pos)
end

function Shield:client_onDestroy()
    self.cl.effect:destroy()
end