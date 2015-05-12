local P = {}
P.__index = SF.Permissions.Provider
setmetatable( P, P )

local ALLOW = SF.Permissions.Result.ALLOW
local DENY = SF.Permissions.Result.DENY
local NEUTRAL = SF.Permissions.Result.NEUTRAL

local keys = {
	[ "input" ] = true,
	[ "input.key" ] = true,
	[ "input.mouse" ] = true
}

function P:check ( principal, target, key )
	if type( principal ) ~= "player" then return NEUTRAL end

	if keys[ key ] then
		return ( principal == LocalPlayer() and ALLOW ) or DENY
	else
		return NEUTRAL
	end
end

SF.Permissions.registerProvider( P )
