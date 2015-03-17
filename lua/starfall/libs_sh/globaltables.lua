
--- Cross-instance tables
-- @shared
local gtables_library, gtables_metamethods = SF.Libraries.Register("globaltables")

SF.GlobalTables = {}

SF.GlobalTables.Global = {}
SF.GlobalTables.Players = {}
SF.GlobalTables.Instance = {}

--- Global table shared by all instances on the same side.
-- @name gtables_library.global
-- @class table
gtables_library.global = SF.GlobalTables.Global

--- Player-unique global table.
-- @name gtables_library.player
-- @class table

--- Instance-unique global table
-- @name gtables_library.instance
-- @class table

hook.Add("PlayerInitialSpawn", "SF_GlobalTables_cn", function(ply)
	SF.GlobalTables.Players[ply] = {}
end)

hook.Add("PlayerDisconnected", "SF_GlobalTables_dc", function(ply)
	SF.GlobalTables.Players[ply] = nil
end)

hook.Add( "sf_initialize", "SF_GlobalTables_init", function( index )
	SF.GlobalTables.Instance[ index ] = { }
end )

hook.Add( "sf_deinitialize", "SF_GlobalTables_deinit", function( index )
	SF.GlobalTables.Instance[ index ] = nil
end )

local oldindex = gtables_metamethods.__index
function gtables_metamethods:__index(k)
	if k == "player" then
		return SF.GlobalTables.Players[SF.instance.player]
	elseif k == "instance" then
		return SF.GlobalTables.Instance[ SF.instance.data.entity:EntIndex( ) ]
	else
		return oldindex[k]
	end
end
