Basic = class()

local meathookConsumeActions = {
    sm.interactable.actions.forward,
    sm.interactable.actions.backward,
    sm.interactable.actions.left,
    sm.interactable.actions.right,
    sm.interactable.actions.jump
}

local consumeActions = {
    sm.interactable.actions.zoomIn,
    sm.interactable.actions.zoomOut
}

local callbackPerAction = {
    [sm.interactable.actions.jump] =            "sv_e_onJump",
    [sm.interactable.actions.zoomOut] =         "sv_e_onCamOut",
    [sm.interactable.actions.zoomIn] =          "sv_e_onCamIn",
    [sm.interactable.actions.forward] =         "sv_e_onMove",
    [sm.interactable.actions.backward] =        "sv_e_onMove",
    [sm.interactable.actions.left] =            "sv_e_onMove",
    [sm.interactable.actions.right] =           "sv_e_onMove"
}

function Basic:server_onFixedUpdate()
    for v, player in pairs(sm.player.getAllPlayers()) do
        local char = player.character
        if char ~= nil and char:getLockingInteractable() == nil then
            char:setLockingInteractable(self.interactable)
        end
    end
end

function Basic:client_onAction( action, state )
    local player = sm.localPlayer.getPlayer()
    local publicData = player:getClientPublicData()
    publicData.input[action] = state

	self.network:sendToServer("sv_onAction", { action = action, state = state, player = player })

    local consume = false
    if isAnyOf(action, meathookConsumeActions) and publicData.meathookState or isAnyOf(action, consumeActions) then consume = true end

    return consume
end

function Basic:sv_onAction( args )
    local publicData = args.player:getPublicData()
    local input = publicData.input[args.action]

    local callback = callbackPerAction[args.action]
    if callback ~= nil then
        local state = sm.tool.interactState.start
        if input and not args.state then
            state = sm.tool.interactState.stop
        end

        local data = callback == "sv_e_onMove" and { key = args.action, state = state } or state
        sm.event.sendToPlayer( args.player, callback, data )
    end

    publicData.input[args.action] = args.state
end