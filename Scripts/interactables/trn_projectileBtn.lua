ProjectileBtn = class()

ProjectileBtn.maxParentCount = 0
ProjectileBtn.maxChildCount = -1
ProjectileBtn.connectionInput = sm.interactable.connectionType.none
ProjectileBtn.connectionOutput = bit.bor( sm.interactable.connectionType.logic )
ProjectileBtn.poseWeightCount = 1

function ProjectileBtn:server_onCreate()
	self.count = self.data.outputDuration
	self.active = false
	self.canBeActivated = true
end

function ProjectileBtn:server_onProjectile( hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	if self.canBeActivated then
		self:sv_toggle( true )
	end
end

function ProjectileBtn:server_onMelee( hitPos, attacker, damage, power  )
	if self.canBeActivated then
		self:sv_toggle( true )
	end
end

function ProjectileBtn:server_onFixedUpdate( dt )
	if self.active and not self.interactable.active then
		self.interactable.active = true
		self.interactable.power = 1
	end

	if self.interactable.active and self.count > 0 then
		self.count = self.count - dt
		if self.count <= 0 then
			self:sv_toggle( false )
		end
	end

	if self.interactable.active and self.count < self.data.outputDuration then
		if self.count > self.data.outputDuration/2 then
			self.poseWeightCount = 0
		else
			self.poseWeightCount = self.poseWeightCount + dt/self.data.outputDuration*2
		end
	end

	if self.poseWeightCount > 1 then
		self.poseWeightCount = 1
	end
end

function ProjectileBtn:client_onFixedUpdate( dt )
	self.interactable:setPoseWeight( 0, self.poseWeightCount )
end

function ProjectileBtn:sv_toggle( toggle )
	if toggle then
		self.count = self.data.outputDuration
		self.canBeActivated = false
		self.interactable.active = true
		self.interactable.power = 1
		self.active = true
		print("Projectile Button "..self.shape:getId().." activated.")
	else
		self.canBeActivated = true
		self.interactable.active = false
		self.interactable.power = 0
		self.active = false
		print("Projectile Button "..self.shape:getId().." deactivated.")
	end

	self.network:sendToClients( "cl_toggle", toggle )
end

function ProjectileBtn:cl_toggle( toggle )
	if toggle then
		sm.audio.play("Button on", self.shape:getWorldPosition())
	else
		sm.audio.play("Button off", self.shape:getWorldPosition())
	end
end