HookPoint = class()

function HookPoint:server_onCreate()
	self.sv = {}
	self.sv.data = {
		countdown = 10,
		canBeHooked = true,
		recharge = false
	}

	self.interactable:setPublicData(self.sv.data)
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
end

function HookPoint:server_onFixedUpdate( dt )
	if self.sv.data.recharge then
		self.sv.data.countdown = self.sv.data.countdown + dt
		if self.sv.data.countdown >= 10 then
			self.sv.data.countdown = 10
			self.sv.data.canBeHooked = true
			self.sv.data.recharge = false

			self.network:sendToClients("cl_updateUv", 0)
		end
	end
end



function HookPoint:cl_updateUv( index )
	print(index)
	self.interactable:setUvFrameIndex( index )
end