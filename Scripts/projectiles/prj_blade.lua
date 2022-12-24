dofile "$CONTENT_DATA/Scripts/se_util.lua"

---@class Blade_cl
---@field pos Vec3
---@field dir Vec3
---@field effect Effect

---@class Blade_params
---@field pos Vec3
---@field dir Vec3
---@field rot Quat
---@field level number
---@field owner Player
---@field spawnTick number

---@class Blade : ScriptableObjectClass
---@field params Blade_params
---@field cl Blade_cl
Blade = class()
Blade.damage = 100
Blade.speed = 1
Blade.maxLifeTime = 15 * 40
Blade.triggerSizes = {
	sm.vec3.new(1,1,1),
	sm.vec3.new(2,1,1),
	sm.vec3.new(3,1,1)
}

function Blade:server_onCreate()
    self.sv = {}
    self.sv.trigger =  sm.areaTrigger.createBox(
        self.triggerSizes[self.params.level],
        self.params.pos,
        self.params.rot,
        sm.areaTrigger.filter.character
    )

	self.sv.trigger:bindOnEnter( "sv_damageUnits" )
end

function Blade:sv_damageUnits( trigger, result )
    for i, obj in pairs(result) do
		if sm.exists(obj) and type(obj) == "Character" and not obj:isPlayer() then
			sm.event.sendToUnit(
                obj:getUnit(),
                "sv_se_takeDamage",
                {
                    damage = self.damage * self.params.level,
                    impact = self.cl.dir * self.params.level,
                    hitPos = self.cl.pos,
                    attacker = self.params.owner
                }
            )
		end
	end
end

function Blade:server_onFixedUpdate(dt)
    if not sm.exists(self.scriptableObject) then return end

    local tick = sm.game.getServerTick()
    local hit, result = sm.physics.raycast( self.cl.pos, self.cl.pos + self.cl.dir )

    if (hit and result:getCharacter() == nil) or tick - self.params.spawnTick >= self.maxLifeTime then
		sm.effect.playEffect( "PropaneTank - ExplosionSmall", self.cl.pos )
        self.scriptableObject:destroy()
		sm.areaTrigger.destroy( self.sv.trigger )
        return
    end

    self.sv.trigger:setWorldPosition(self.cl.pos)
end



function Blade:client_onCreate()
    self.cl = {}
    self.cl.pos = self.params.pos
    self.cl.dir = self.params.dir
    self.cl.effect = sm.effect.createEffect("Destroyer Blade")

    self.cl.effect:setRotation( self.params.rot )
	self.cl.effect:setScale( self.triggerSizes[self.params.level]/2 )
    self.cl.effect:setPosition(self.cl.pos)
    self.cl.effect:start()
end

function Blade:client_onUpdate( dt )
    if self.cl == nil or not sm.exists(self.scriptableObject) then return end

    self.cl.pos = self.cl.pos + self.cl.dir * self.speed * ( dt / (1/40) )
    self.cl.effect:setPosition(self.cl.pos)
end

function Blade:client_onDestroy()
    self.cl.effect:destroy()
end