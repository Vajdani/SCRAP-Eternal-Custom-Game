WallClimb = class()

function WallClimb:server_onCreate()
    self.lookDir = sm.shape.getUp(self.shape)
    self.dismountDash = sm.vec3.new(1750, 1750, 1750)
    self.climbArea = sm.areaTrigger.createAttachedBox(
        self.interactable,
        sm.vec3.new(self.data.size.x, self.data.size.y, self.data.size.z),
        sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z),
        sm.quat.identity(),
        sm.areaTrigger.filter.character
    )
    self.climbArea:bindOnEnter("sv_toggleClimbOn")
    self.climbArea:bindOnExit("sv_toggleClimbOff")
end

function WallClimb:server_onDestroy()
    for _, player in ipairs(sm.player.getAllPlayers()) do
        self:sv_toggleClimb(player.character, false, 1)
    end
end

function WallClimb:sv_toggleClimbOn(trigger, result)
    for _, character in ipairs(result) do
        self.network:sendToClient(character:getPlayer(), "cl_toggleClimb", true)
        self:sv_toggleClimb(character, true, 1)
    end
end

function WallClimb:sv_toggleClimbOff(trigger, result)
    for _, character in ipairs(result) do
        self.network:sendToClient(character:getPlayer(), "cl_toggleClimb", false)
        self:sv_toggleClimb(character, false, 1);
    end
end

function WallClimb:sv_toggleClimb(character, climbing, speed)
    character:setDiving(climbing)
    character:setSwimming(climbing)
    character:setMovementSpeedFraction(speed)
end

function WallClimb:sv_dismountWall(character)
    self.network:sendToClient(character:getPlayer(), "cl_toggleClimb", false)
    self:sv_toggleClimb(character, false, 1)
    sm.physics.applyImpulse(character, character:getDirection() * self.dismountDash)
end

function WallClimb:client_onCreate()
    self.isOnWall = false
end

function WallClimb:client_onDestroy()
    self.isOnWall = false
    self:cl_toggleClimb(false)
end

function WallClimb:client_onAction(controllerAction, state)
    local consumeAction = false

    if state and (controllerAction == sm.interactable.actions.jump and self.isOnWall) then
        sm.audio.play("WeldTool - Weld")
        self.network:sendToServer("sv_dismountWall", sm.localPlayer.getPlayer().character)
        consumeAction = true
    end

    return consumeAction
end

function WallClimb:cl_toggleClimb(isOnWall)
    local character = sm.localPlayer.getPlayer().character
    self.isOnWall = isOnWall

    if isOnWall then
        character:setLockingInteractable(self.interactable)
        sm.audio.play("WeldTool - Sparks")
        sm.particle.createParticle("construct_welding", character:getWorldPosition(), sm.quat.identity())
    else
		character:setLockingInteractable(nil)
    end
end