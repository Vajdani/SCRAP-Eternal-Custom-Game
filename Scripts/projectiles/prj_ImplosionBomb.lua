dofile "$CONTENT_DATA/Scripts/se_util.lua"

ImploBomb = class()

function ImploBomb:server_onCreate()
	self.grenadeID = self.shape:getId()
	self.countdownActive = false
	self.countdown = 2.5
	self.multiplier = 1

	local data = sm.interactable.getPublicData( self.interactable )
	if data ~= nil then
		self.player = data.player
	else
		self:sv_destroy()
	end

	sm.interactable.setPublicData( self.interactable, { player = self.player, multiplier = self.multiplier } )
end

function ImploBomb:client_onCreate()
	self.effects = {}
    for i = 1, 6 do
        self.effects[i] = sm.effect.createEffect("Vacuumpipe - Suction", self.interactable)
    end
end

function ImploBomb:server_onFixedUpdate( dt )
	self.multiplier = sm.interactable.getPublicData( self.interactable ).multiplier
	self.pos = self.shape:getWorldPosition()

	if self.countdownActive then
		for v, unit in pairs(sm.unit.getAllUnits()) do
			local char = unit:getCharacter()
			local dir = self.pos - char:getWorldPosition()
			if dir:length() <= 10 * self.multiplier then
				sm.physics.applyImpulse( char, se.vec3.num(250) * char:getMass() / 150 * self.multiplier * dir )
			end
		end

		self.countdown = self.countdown - dt
		if self.countdown <= 0 or self.multiplier > 1 then
			self:sv_destroy()
		end
	end
end

function ImploBomb:client_onFixedUpdate( dt )
    local dirs = {
        sm.shape.getAt( self.shape ),
        sm.shape.getAt( self.shape ) * -1,
        sm.shape.getRight( self.shape ),
        sm.shape.getRight( self.shape ) * -1,
        sm.shape.getUp( self.shape ),
        sm.shape.getUp( self.shape ) * -1
    }

    if self.countdownActive then
        for v, effect in pairs(self.effects) do
			if not effect:isPlaying() then
				effect:start()
			end

            effect:setOffsetRotation( sm.vec3.getRotation( se.vec3.up(), dirs[v] ) )
        end
    end
end

function ImploBomb:server_onCollision( other, pos, velocity, otherVelocity, normal )
	self.countdownActive = true
end

function ImploBomb:sv_destroy()
	print("ImploBomb", self.grenadeID, "destroyed.")
	self.shape:destroyPart()
end

function ImploBomb:client_onDestroy()
    for v, effect in pairs(self.effects) do
        effect:stopImmediate()
        effect:destroy()
    end
end