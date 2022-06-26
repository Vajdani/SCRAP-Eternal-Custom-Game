HookPoint = class()

function HookPoint:server_onCreate()
	self.sv = {}
	self.sv.data = {
		countdown = 10,
		canBeHooked = true,
		recharge = false
	}

	self.network:sendToClients("cl_updateUv", 0)
end

function HookPoint:sv_hook( toggle )
	if toggle and self.sv.data.canBeHooked then
		self.sv.data.canBeHooked = false
		self.sv.data.countdown = 0

		self.network:sendToClients("cl_updateUv", 1)
	elseif not toggle or toggle and not self.sv.data.canBeHooked then
		self.sv.data.recharge = true
	end

	sm.interactable.setPublicData(self.interactable, self.sv.data)
end

function HookPoint:server_onFixedUpdate( dt )
	if self.sv.data.recharge then
		self.sv.data.countdown = self.sv.data.countdown + dt
		if self.sv.data.countdown >= 10 then
			self.sv.data.countdown = 10
			self.sv.data.canBeHooked = true
			self.sv.data.recharge = false

			sm.interactable.setPublicData(self.interactable, self.sv.data)
			self.network:sendToClients("cl_updateUv", 0)
		end
	end
end



function HookPoint:cl_updateUv( index )
	sm.interactable.setUvFrameIndex( self.interactable, index )
end