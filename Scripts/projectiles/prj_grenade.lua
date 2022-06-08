dofile "$CONTENT_DATA/Scripts/se_util.lua"

Grenade = class()

function Grenade:server_onCreate()
	self.grenadeID = self.shape:getId()
	self.grenadeBody = self.shape:getBody()
	self.countdownActive = false
	self.countdown = 2
	self.multiplier = 1

	local data = sm.interactable.getPublicData( self.interactable )
	if data ~= nil then
		self.player = data.player
	else
		self:sv_destroy()
	end

	sm.interactable.setPublicData( self.interactable, { player = self.player, multiplier = self.multiplier } )

	--self.trigger = sm.areaTrigger.createAttachedBox( self.interactable, sm.vec3.new(0.5,0.5,0.5), sm.vec3.zero(), sm.quat.identity() )
end

function Grenade:client_onCreate()
	self.fireEffect = sm.effect.createEffect("Fire - small01", self.interactable)
	--self.fireEffect:start()
end

function Grenade:server_onFixedUpdate( dt )
	self.multiplier = sm.interactable.getPublicData( self.interactable ).multiplier

	if self.countdownActive then
		self.countdown = self.countdown - dt
		if self.countdown <= 0 or self.multiplier > 1 then
			self:sv_destroy()
		end
	end
end

function Grenade:server_onCollision( other, pos, velocity, otherVelocity, normal )
	self.countdownActive = true
end

function Grenade:sv_destroy()
	se.physics.explode( self.shape:getWorldPosition(), 4 * self.multiplier, 5 * self.multiplier, 5.5 * self.multiplier, 20 * self.multiplier, "PropaneTank - ExplosionSmall", nil, self.player, true )
	print("Grenade", self.grenadeID, "destroyed.")
	--sm.areaTrigger.destroy( self.trigger )
	self.shape:destroyPart()
end