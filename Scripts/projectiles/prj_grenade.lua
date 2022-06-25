dofile "$CONTENT_DATA/Scripts/se_util.lua"

Grenade = class()

function Grenade:server_onCreate()
	self.grenadeID = self.shape:getId()
	self.grenadeBody = self.shape:getBody()
	self.countdownActive = false
	self.countdown = 2

	local data = sm.interactable.getPublicData( self.interactable )
	if data == nil then
		self:sv_destroy()
	else
		self.player = data.player
	end
end

function Grenade:server_onFixedUpdate( dt )
	self.multiplier = sm.interactable.getPublicData( self.interactable ).multiplier

	if self.countdownActive then
		self.countdown = self.countdown - dt
		if self.countdown <= 0 then
			self:sv_destroy()
		end
	end
end

function Grenade:server_onCollision( other, pos, velocity, otherVelocity, normal )
	self.countdownActive = true
end

function Grenade:sv_destroy()
	se.physics.explode( self.shape:getWorldPosition(), 30 * self.multiplier, 10 * self.multiplier, 15 * self.multiplier, 50 * self.multiplier, "PropaneTank - ExplosionSmall", nil, self.player, true )
	print("Grenade", self.grenadeID, "destroyed.")
	self.shape:destroyPart()
end



function Grenade:client_onCreate()
	self.fireEffect = sm.effect.createEffect("Fire - small01", self.interactable)
	--self.fireEffect:start()
end