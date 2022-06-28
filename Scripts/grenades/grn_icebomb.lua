IceBomb = class()

function IceBomb:server_onCreate()
	local data = sm.interactable.getPublicData( self.interactable )
	if data ~= nil then
		self.char = data.player:getCharacter()
	else
		self:sv_destroy()
	end
	self.bombID = self.shape:getId()
	self.bombBody = self.shape:getBody()
end

function IceBomb:server_onCollision( other, pos, velocity, otherVelocity, normal )
	self.freezeArea = sm.areaTrigger.createBox(sm.vec3.new(10,10,10), self.bombBody:getWorldPosition(), sm.quat.identity(), 4)
	self.freezeArea:bindOnEnter("sv_freezeUnits")
end

function IceBomb:sv_freezeUnits( trigger, result )
	sm.event.sendToGame( "sv_iceBombStun", { char = self.char, units = result } )
	self.network:sendToClients("cl_destroy")
	self:sv_destroy()
end

function IceBomb:sv_destroy()
	print("IceBomb", self.bombID, "destroyed.")
	if sm.exists(self.freezeArea) then
		sm.areaTrigger.destroy( self.freezeArea )
	end
	self.shape:destroyPart()
end

function IceBomb:cl_destroy()
	sm.effect.playEffect( "PropaneTank - ExplosionSmall", self.shape.worldPosition, sm.vec3.zero(), sm.quat.identity() )
end