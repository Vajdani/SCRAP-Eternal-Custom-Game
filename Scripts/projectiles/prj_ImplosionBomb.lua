dofile "$CONTENT_DATA/Scripts/se_util.lua"

ImploBomb = class()

function ImploBomb:server_onCreate()
	self.sv = {}
	self.sv.grenadeID = self.shape:getId()
	self.sv.countdownActive = false
	self.sv.countdown = 2.5

	local data = sm.interactable.getPublicData( self.interactable )
	if data == nil then
		self:sv_destroy()
	else
		self.sv.owner = data.player
	end
end

function ImploBomb:server_onFixedUpdate( dt )
	self.sv.multiplier = sm.interactable.getPublicData( self.interactable ).multiplier
	local pos = self.shape:getWorldPosition()

	if self.sv.countdownActive then
		for v, char in pairs(sm.physics.getSphereContacts( pos, 10 * self.sv.multiplier ).characters) do
			if not char:isPlayer() or char:getPlayer() ~= self.sv.owner then
				local dir = pos - char:getWorldPosition()
				sm.physics.applyImpulse( char, implosionBombImpulse * self.sv.multiplier * dir )
			end
		end

		self.sv.countdown = self.sv.countdown - dt
		if self.sv.countdown <= 0 then
			self:sv_destroy()
		end
	end
end

function ImploBomb:server_onCollision( other, pos, velocity, otherVelocity, normal )
	self.sv.countdownActive = true
	self.network:sendToClients("cl_startEffect")
end

function ImploBomb:sv_destroy()
	print("ImploBomb", self.sv.grenadeID, "destroyed.")
	self.shape:destroyPart()
end



function ImploBomb:client_onCreate()
	self.cl = {}
	self.cl.effects = {}

	local at = self.shape:getAt()
	local right = self.shape:getRight()
	local up = self.shape:getRight()
	local dirs = {
        at,
        at * -1,
        right,
        right * -1,
        up,
        up * -1
    }

    for i = 1, 6 do
        self.cl.effects[i] = sm.effect.createEffect("Vacuumpipe - Suction", self.interactable)
		self.cl.effects[i]:setOffsetRotation( sm.vec3.getRotation( se.vec3.up(), dirs[i] ) )
    end
end

function ImploBomb:cl_startEffect()
	for v, effect in pairs(self.cl.effects) do
		effect:start()
	end
end

function ImploBomb:client_onDestroy()
    for v, effect in pairs(self.cl.effects) do
        effect:stopImmediate()
        effect:destroy()
    end
end