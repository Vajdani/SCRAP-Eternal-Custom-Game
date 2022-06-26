MonkeyBar = class()

function MonkeyBar:server_onCreate()
    self.swingArea = sm.areaTrigger.createAttachedBox(
        self.interactable,
        sm.vec3.new(0.5,0.5,1),
        sm.vec3.new(0,0,1),
        sm.quat.identity(),
        sm.areaTrigger.filter.character
    )
    self.swingArea:bindOnEnter("sv_applyBoost")
end

function MonkeyBar:sv_applyBoost(trigger, result)
    for _, char in ipairs(result) do
        if char:isPlayer() then
            local boostDir = char:getDirection()
            sm.physics.applyImpulse(char, sm.vec3.new( 800 * boostDir.x, 800 * boostDir.y, se.vec3.redirectVel( "z", 800, char ).z ) )
            self.network:sendToClient(char:getPlayer(), "cl_playAudio")
        end
    end
end

function MonkeyBar:cl_playAudio()
    sm.audio.play("Handbook - Open")
end