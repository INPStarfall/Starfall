
--- Cross-instance tables
-- @shared
local gtables_library, gtables_metamethods = SF.Libraries.Register( "globaltables" )

gtables_metamethods.Global = {}
gtables_metamethods.Players = {}

--- Global table shared by all instances on the same side.
-- @name gtables_library.global
-- @class table
gtables_library.global = gtables_metamethods.Global

--- Player-unique global table.
-- @name gtables_library.player
-- @class table

hook.Add("PlayerInitialSpawn", "SF_GlobalTables_cn", function (ply)
	gtables_metamethods.Players [ ply ] = {}
end)

hook.Add("PlayerDisconnected", "SF_GlobalTables_dc", function (ply)
	gtables_metamethods.Players [ ply ] = nil
end)

function gtables_metamethods:__index ( k )
	if k == "player" then
		return gtables_metamethods.Players[ SF.instance.player ]
	else
		return gtables_metamethods.__methods[ k ]
	end
end
