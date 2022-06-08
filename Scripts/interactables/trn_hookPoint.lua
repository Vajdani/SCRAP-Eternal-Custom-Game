HookPoint = class()

function HookPoint:server_onCreate()
	self.data = {
		countdown = 10,
		canBeHooked = true,
		recharge = false
	}
end

function HookPoint:togglehook( toggle )
	if toggle and self.data.canBeHooked then
		self.data.canBeHooked = false
		self.data.countdown = 0
	elseif not toggle or toggle and not self.data.canBeHooked then
		self.data.recharge = true
	end
end

function HookPoint:server_onFixedUpdate( dt )
	if self.data.recharge then
		self.data.countdown = self.data.countdown + dt
		if self.data.countdown >= 10 then
			self.data.countdown = 10
			self.data.canBeHooked = true
			self.data.recharge = false
		end
	end

	sm.interactable.setPublicData(self.interactable, self.data)
end

function HookPoint:client_onFixedUpdate( dt )
	local index = self.data.canBeHooked and 0 or 1 --(self.data.canBeHooked or not self.data.canBeHooked and self.data.countdown == 0)
	sm.interactable.setUvFrameIndex( self.interactable, index )
end