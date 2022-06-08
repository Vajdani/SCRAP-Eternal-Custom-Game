Pickup = class( nil )

dofile "$CONTENT_DATA/Scripts/se_util.lua"

local ammoTypes = {
    { ammo = obj_plantables_potato, min = 15, max = 25 },
    { ammo = se_ammo_shells, min = 3, max = 6 },
    { ammo = se_ammo_plasma, min = 25, max = 40 },
    { ammo = se_ammo_rocket, min = 1, max = 3 }
}

function Pickup:client_onCreate()
	self.effect = sm.effect.createEffect( self.data.effect )
	self.effect:setPosition( self.harvestable.worldPosition )
	self.effect:setRotation( self.harvestable.worldRotation )
    self.effect:setScale(se.vec3.num(0.25))
	self.effect:start()
end

function Pickup:client_onDestroy()
	self.effect:stop()
	self.effect:destroy()
end

function Pickup:server_onCreate()
    self.type = self.data.type
    self.min = self.data.min
    self.max = self.data.max

    self.trigger = sm.areaTrigger.createBox( se.vec3.num(0.5), self.harvestable:getPosition(), sm.quat.identity(), sm.areaTrigger.filter.character )
    self.trigger:bindOnStay("sv_checkTrigger")

    self.lifeTime = 0
    self.destroyed = false
end

function Pickup:server_onFixedUpdate( dt )
    self.lifeTime = self.lifeTime + dt
    if self.lifeTime >= 50 or self.destroyed then
        if sm.exists(self.trigger) then
            sm.areaTrigger.destroy( self.trigger )
        end
        sm.harvestable.destroy( self.harvestable )
    end
end

function Pickup:sv_checkTrigger( trigger, result )
    for v, char in pairs(result) do
        if sm.exists(char) and char:isPlayer() and not self.destroyed then
            local player = char:getPlayer()
            --[[local maxStatCheckType = "ammo"
            if self.data.type == "Health" then
                maxStatCheckType = "hp"
            elseif self.data.type == "Armour" then
                maxStatCheckType = "armour"
            end

            local current = sm.playerSats[player:getId()][maxStatCheckType]
            local max = sm.playerSats[player:getId()]["max"..maxStatCheckType]

            if current < max or maxStatCheckType == "ammo" then]]
                local cycles = self.type == "Ammo" and 4 or 1

                for i = 1, cycles do
                    local quantity
                    local item

                    if cycles > 1 then
                        item = ammoTypes[i].ammo
                        quantity = math.random(ammoTypes[i].min, ammoTypes[i].max)
                    else
                        quantity = math.random(self.min, self.max)
                    end

                    sm.event.sendToPlayer( player, "sv_add"..self.data.type, { item = item, quantity = quantity } )
                end
                self.destroyed = true
                break
            --end
        end
    end
end