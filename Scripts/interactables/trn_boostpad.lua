BoostPad = class()

BoostPad.maxParentCount = 1
BoostPad.maxChildCount = 0
BoostPad.connectionInput = bit.bor( sm.interactable.connectionType.logic )
BoostPad.connectionOutput = sm.interactable.connectionType.none

function BoostPad:server_onCreate()
    self.boostArea = sm.areaTrigger.createAttachedBox(
            self.interactable,
            sm.vec3.new(0.5, 0.5, 0.5),
            self.shape:getUp() * 0.5,
            sm.quat.identity(),
            sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody
        )
	self.inputActive = false
	self.parent = nil
	self.effectPlaying = false
    self.boostArea:bindOnStay("sv_applyBoost")
end

function BoostPad:sv_applyBoost(trigger, result)
    for _, object in ipairs(result) do
        if (object ~= self.shape:getBody()) and self.inputActive or (object ~= self.shape:getBody()) and self.parent == nil then
            sm.physics.applyImpulse(object, self.shape:getUp() * 175 * (object:getMass()/75))
        end
    end
end

function BoostPad:client_onFixedUpdate( dt )
	self.parent = sm.interactable.getSingleParent( self.interactable )
	if self.parent ~= nil then
		self.inputActive = sm.interactable.isActive( self.parent )
	end
	
	if self.parent == nil or self.inputActive then
		if not self.effectPlaying then
			for _, effect in ipairs(self.thrustEffects) do
				effect:start()
			end
			self.effectPlaying = true
		end
	elseif not self.inputActive and self.effectPlaying then
		for _, effect in ipairs(self.thrustEffects) do
			effect:stop()
		end
		self.effectPlaying = false
	end
end

function BoostPad:client_onCreate()
    self.thrustEffects = {}
    self.effectOffsets = {
        sm.vec3.new(-1, 1, -1),
        sm.vec3.new(1, 1, -1),
        sm.vec3.new(-1, -1, -1),
        sm.vec3.new(1, -1, -1)
    }

    for i = 1, 4, 1 do
        self.thrustEffects[i] = sm.effect.createEffect("Thruster - Level 5", self.interactable)
        self.thrustEffects[i]:setOffsetPosition(self.effectOffsets[i] * 0.25)
        self.thrustEffects[i]:start()
    end
	self.effectPlaying = true
end

function BoostPad:client_onDestroy()
    for _, effect in ipairs(self.thrustEffects) do
        effect:stop()
    end
	self.effectPlaying = false
end