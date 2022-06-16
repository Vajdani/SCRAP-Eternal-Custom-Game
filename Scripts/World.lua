World = class( nil )
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -2
World.cellMaxX = 1
World.cellMinY = -2
World.cellMaxY = 1
World.worldBorder = true

function World.server_onCreate( self )
    print("World.server_onCreate")

    self.sv = {}
    self.sv.data = {}
end

function World:server_onFixedUpdate( dt )

end



--Client
function World.client_onCreate( self )
    print("World.client_onCreate")

    self.cl = {}
    self.cl.data = {}
end

function World:client_onFixedUpdate( dt )

end