Game = class( nil )

dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )


function Game.server_onCreate( self )
	print("Game.server_onCreate")
    self.sv = {}
	self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
		self.storage:save( self.sv.saved )
	end

    g_unitManager = UnitManager()
	g_unitManager:sv_onCreate( nil, { aggroCreations = true } )

    sm.playerInfo = {}
	sm.unitData = {}
end

function Game:sv_iceBombStun( args )
	sm.event.sendToWorld( args.char:getWorld(), "sv_iceBombStun", args )
end

function Game:sv_bloodPunch( args )
	sm.event.sendToWorld( args.player:getCharacter():getWorld(), "sv_bloodPunch", args )
end

function Game:sv_extendGK( args )
	sm.event.sendToWorld( args.player:getCharacter():getWorld(), "sv_extendGK", args )
end

function Game:sv_killGkTarget( args )
	sm.event.sendToWorld( args.player:getCharacter():getWorld(), "sv_killGkTarget", args )
end

function Game:sv_setUnitOnFire( args )
	sm.event.sendToWorld( args.player:getCharacter():getWorld(), "sv_setUnitOnFire", args )
end

function Game:sv_se_onExplosion( args )
	sm.event.sendToWorld( args.player:getCharacter():getWorld(), "sv_se_onExplosion", args )
end

function Game.server_onPlayerJoined( self, player, isNewPlayer )
    print("Game.server_onPlayerJoined")
    if isNewPlayer then
        if not sm.exists( self.sv.saved.world ) then
            sm.world.loadWorld( self.sv.saved.world )
        end
        self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
    end

	g_unitManager:sv_onPlayerJoined( player )
end

function Game.sv_createPlayerCharacter( self, world, x, y, player, params )
    local character = sm.character.createCharacter( player, world, sm.vec3.new( 32, 32, 5 ), 0, 0 )
	player:setCharacter( character )
end

function Game:server_onFixedUpdate( dt )
	g_unitManager:sv_onFixedUpdate()
end



function Game:client_onCreate()
    if g_unitManager == nil then
        assert( not sm.isHost )
        g_unitManager = UnitManager()
    end
    g_unitManager:cl_onCreate()
end