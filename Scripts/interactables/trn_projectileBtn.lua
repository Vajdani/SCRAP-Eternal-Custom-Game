ProjectileBtn = class()

ProjectileBtn.maxParentCount = 0
ProjectileBtn.maxChildCount = -1
ProjectileBtn.connectionInput = sm.interactable.connectionType.none
ProjectileBtn.connectionOutput = sm.interactable.connectionType.logic
ProjectileBtn.poseWeightCount = 1

function ProjectileBtn:server_onCreate()
	self.sv = {}
	self.sv.count = self.data.outputDuration
	self.sv.canBeActivated = true
end

function ProjectileBtn:server_onProjectile( hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	if self.sv.canBeActivated then
		self:sv_toggle( true )
	end
end

function ProjectileBtn:server_onMelee( hitPos, attacker, damage, power  )
	if self.sv.canBeActivated then
		self:sv_toggle( true )
	end
end

function ProjectileBtn:server_onFixedUpdate( dt )
	if self.interactable.active and self.sv.count > 0 then
		self.sv.count = self.sv.count - dt
		if self.sv.count <= 0 then
			self:sv_toggle( false )
		end
	end
end

function ProjectileBtn:client_onCreate()
	self.cl = {}
	self.cl.poseWeightCount = 1
	self.cl.count = self.data.outputDuration
end

function ProjectileBtn:client_onUpdate( dt )
	if self.interactable.active and self.cl.count > 0 then
		self.cl.count = self.cl.count - dt
	end

	if self.interactable.active and self.cl.count < self.data.outputDuration then
		if self.cl.count > self.data.outputDuration/2 then
			self.cl.poseWeightCount = 0
		else
			self.cl.poseWeightCount = self.cl.poseWeightCount + dt/self.data.outputDuration*2
		end
	end

	if self.cl.poseWeightCount > 1 then
		self.cl.poseWeightCount = 1
	end

	self.interactable:setPoseWeight( 0, self.cl.poseWeightCount )
end

function ProjectileBtn:sv_toggle( toggle )
	if toggle then
		self.sv.count = self.data.outputDuration
		self.sv.canBeActivated = false
		self.interactable.active = true
		self.interactable.power = 1
		print("Projectile Button "..self.shape:getId().." activated.")
	else
		self.sv.canBeActivated = true
		self.interactable.active = false
		self.interactable.power = 0
		print("Projectile Button "..self.shape:getId().." deactivated.")
	end

	self.network:sendToClients( "cl_toggle", toggle )
end

function ProjectileBtn:cl_toggle( toggle )
	if toggle then
		self.cl.count = self.data.outputDuration
		sm.audio.play("Button on", self.shape:getWorldPosition())
	else
		sm.audio.play("Button off", self.shape:getWorldPosition())
	end
end