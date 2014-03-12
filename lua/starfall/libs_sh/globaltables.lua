
--- Cross-instance tables
-- @shared
local gtables_library, gtables_metamethods = SF.Libraries.Register("globaltables")

SF.GlobalTables = {}
SF.GlobalTables.Global = {}
SF.GlobalTables.Players = {}
SF.GlobalTables.Safe = {}

--- Global table shared by all instances on the same side.
-- @name gtables_library.global
-- @class table
gtables_library.global = SF.GlobalTables.Global

--- Player-unique global table.
-- @name gtables_library.player
-- @class table

hook.Add("PlayerInitialSpawn", "SF_GlobalTables_cn", function(ply)
	SF.GlobalTables.Players[ply] = {}
end)

hook.Add("PlayerDisconnected", "SF_GlobalTables_dc", function(ply)
	SF.GlobalTables.Players[ply] = nil
end)

local util_CRC = util.CRC
local tonumber = tonumber
local function getHash(code)
	return tonumber(util_CRC(code)) or -1
end

local oldindex = gtables_metamethods.__index
function gtables_metamethods:__index(k)
	if k == "player" then
		return SF.GlobalTables.Players[SF.instance.player]
	elseif k == "safe" then
		local hash = getHash(SF.instance.source[SF.instance.mainfile])
		if not SF.GlobalTables.Safe[hash] then 
			SF.GlobalTables.Safe[hash] = {}
		end
		
		return SF.GlobalTables.Safe[hash]
	else
		return oldindex[k]
	end
end
