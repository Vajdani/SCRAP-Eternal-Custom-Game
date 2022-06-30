BaseWeapon = class()

dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"

function BaseWeapon.cl_onCreate( self, weapon )
	self.cl.owner = self.tool:getOwner()
    self.cl.ownerData = self.cl.owner:getClientPublicData()
	self.cl.powerups = self.cl.ownerData.powerup
	self.cl.weaponData = self.cl.ownerData.data.weaponData[weapon]

    if self.cl.weaponData.mod1.owned then
        self.cl.currentWeaponMod = self.mod1
    elseif self.cl.weaponData.mod2.owned then
        self.cl.currentWeaponMod = self.mod2
    else
        self.cl.currentWeaponMod = "poor"
    end

    if not self.tool:isLocal() then return end
    --General stuff
	self.cl.isFiring = false
	self.cl.usingMod = false

	--Mod switch
	self.cl.modSwitch = {
        active = false,
        timer = Timer()
    }
    self.cl.modSwitch.timer:start(40)

    --bind doom mod functions
    function self:updateModData()
        self.cl.ownerData.weaponMod = {
            mod = self.cl.currentWeaponMod,
            using = self.cl.usingMod,
            ammo = 0,
            recharge = 0
        }
    end

    function self:updateRenderables()
        local currentRenderablesTp = {}
        local currentRenderablesFp = {}
        local renderables = self.renderables[self.cl.currentWeaponMod]

        for k,v in pairs( self.renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
        for k,v in pairs( self.renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
        for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
        for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
        self.tool:setTpRenderables( currentRenderablesTp )
        if self.tool:isLocal() then
            self.tool:setFpRenderables( currentRenderablesFp )
        end

        self:loadAnimations()
    end

    function self:sv_onModSwitch( mod )
        self.network:sendToClients( "cl_onModSwitch", mod )
    end

    function self:cl_onModSwitch( mod )
	    if not self.tool:isLocal() then --sync currently selected mod to other clients
            self.cl.currentWeaponMod = mod
        end

        self:updateRenderables()

        setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
        if self.tool:isLocal() then
            swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
        end
    end



    --bind common vanilla functions
    function self:calculateFpMuzzlePos()
        local fovScale = ( sm.camera.getFov() - 45 ) / 45

        local up = sm.localPlayer.getUp()
        local dir = sm.localPlayer.getDirection()
        local right = sm.localPlayer.getRight()

        local muzzlePos45 = sm.vec3.new( 0.0, 0.0, 0.0 )
        local muzzlePos90 = sm.vec3.new( 0.0, 0.0, 0.0 )

        if self.aiming then
            muzzlePos45 = muzzlePos45 - up * 0.2
            muzzlePos45 = muzzlePos45 + dir * 0.5

            muzzlePos90 = muzzlePos90 - up * 0.5
            muzzlePos90 = muzzlePos90 - dir * 0.6
        else
            muzzlePos45 = muzzlePos45 - up * 0.15
            muzzlePos45 = muzzlePos45 + right * 0.2
            muzzlePos45 = muzzlePos45 + dir * 1.25

            muzzlePos90 = muzzlePos90 - up * 0.15
            muzzlePos90 = muzzlePos90 + right * 0.2
            muzzlePos90 = muzzlePos90 + dir * 0.25
        end

        return self.tool:getFpBonePos( "pejnt_barrel" ) + sm.vec3.lerp( muzzlePos45, muzzlePos90, fovScale )
    end

    function self:calculateTpMuzzlePos()
        local crouching = self.tool:isCrouching()
        local dir = sm.localPlayer.getDirection()
        local pitch = math.asin( dir.z )
        local right = sm.localPlayer.getRight()
        local up = right:cross(dir)

        local fakeOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

        --General offset
        fakeOffset = fakeOffset + right * 0.25
        fakeOffset = fakeOffset + dir * 0.5
        fakeOffset = fakeOffset + up * 0.25

        --Action offset
        local pitchFraction = pitch / ( math.pi * 0.5 )
        if crouching then
            fakeOffset = fakeOffset + dir * 0.2
            fakeOffset = fakeOffset + up * 0.1
            fakeOffset = fakeOffset - right * 0.05

            if pitchFraction > 0.0 then
                fakeOffset = fakeOffset - up * 0.2 * pitchFraction
            else
                fakeOffset = fakeOffset + up * 0.1 * math.abs( pitchFraction )
            end
        else
            fakeOffset = fakeOffset + up * 0.1 *  math.abs( pitchFraction )
        end

        local fakePosition = fakeOffset + GetOwnerPosition( self.tool )
        return fakePosition
    end

    function self:calculateFirePosition()
        local crouching = self.tool:isCrouching()
        local firstPerson = self.tool:isInFirstPersonView()
        local dir = sm.localPlayer.getDirection()
        local pitch = math.asin( dir.z )
        local right = sm.localPlayer.getRight()

        local fireOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

        if crouching then
            fireOffset.z = 0.15
        else
            fireOffset.z = 0.45
        end

        if firstPerson then
            if not self.aiming then
                fireOffset = fireOffset + right * 0.05
            end
        else
            fireOffset = fireOffset + right * 0.25
            fireOffset = fireOffset:rotate( math.rad( pitch ), right )
        end
        local firePosition = GetOwnerPosition( self.tool ) + fireOffset
        return firePosition
    end

    function self:sv_n_onAim( aiming )
        self.network:sendToClients( "cl_n_onAim", aiming )
    end

    function self:cl_n_onAim( aiming )
        if not self.tool:isLocal() and self.tool:isEquipped() then
            self:onAim( aiming )
        end
    end

    function self:onAim( aiming )
        self.aiming = aiming
        if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
            setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
        end
    end

    function self:sv_n_onShoot( dir )
        self.network:sendToClients( "cl_n_onShoot", dir )
    end

    function self:cl_n_onShoot( dir )
        if not self.tool:isLocal() and self.tool:isEquipped() then
            self.onShoot( dir )
        end
    end

    function self:onShoot( dir )
        self.tpAnimations.animations.idle.time = 0
        self.tpAnimations.animations.shoot.time = 0
        self.tpAnimations.animations.aimShoot.time = 0

        setTpAnimation( self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0 )

        if self.tool:isInFirstPersonView() then
            self.shootEffectFP:start()
        else
            self.shootEffect:start()
        end
    end
end

function BaseWeapon.cl_onFixed( self )
    if self.cl.modSwitch.active then
        for i = 1, self.cl.powerups.speedMultiplier.current do
            self.cl.modSwitch.timer:tick()
        end

        if self.cl.modSwitch.timer:done() then
            self.cl.modSwitch.timer:reset()
            self.cl.modSwitch.active = false
        end
    end
end

function BaseWeapon.onModSwitch( self )
    if self.cl.weaponData.mod1.owned and self.cl.weaponData.mod2.owned then
        self.cl.currentWeaponMod = self.cl.currentWeaponMod == self.mod1 and self.mod2 or self.mod1
		self.cl.modSwitch.active = true
		sm.gui.displayAlertText("Current weapon mod: #ff9d00" .. self.cl.currentWeaponMod, 2.5)
		sm.audio.play("PaintTool - ColorPick")
        self:updateModData()
        self.network:sendToServer("sv_onModSwitch", self.cl.currentWeaponMod)
	else
		sm.audio.play("Button off")
	end
end

function BaseWeapon.onEquipped( self, primaryState, secondaryState )
    local prevUse = self.cl.usingMod

    self.cl.isFiring = primaryState == sm.tool.interactState.start or primaryState == sm.tool.interactState.hold
	self.cl.usingMod = secondaryState == sm.tool.interactState.start or secondaryState == sm.tool.interactState.hold

    if prevUse ~= self.cl.usingMod then
        self:updateModData()
    end

	if self.cl.modSwitch.active then
		sm.gui.setProgressFraction(self.cl.modSwitch.timer.count/self.cl.modSwitch.timer.ticks)
	end

    self.fireCooldownTimer = self.fireCooldownTimer or 0

    if self.fireCooldownTimer > 0 and self.visualiseFireCooldown then
		sm.gui.setProgressFraction(self.fireCooldownTimer/2)
	end
end