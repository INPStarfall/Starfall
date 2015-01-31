---------------------------------------------------------------------
-- SF Client Group Provider
---------------------------------------------------------------------

local Provider = setmetatable( {}, { __index = SF.Permissions.Provider } )

local ALLOW = SF.Permissions.Result.ALLOW
local DENY = SF.Permissions.Result.DENY
local NEUTRAL = SF.Permissions.Result.NEUTRAL

function Provider:check ( principal, target, key )
	if principal == LocalPlayer() then
		if SF.Permissions.privileges[ key ].group[ principal:GetUserGroup( ) ] or SF.Permissions.privileges[ key ].group[ "*" ] then
			return ALLOW
		end
	elseif SF.Permissions.privileges[ key .. ".others" ].group[ principal:GetUserGroup( ) ] or SF.Permissions.privileges[ key .. ".others" ].group[ "*" ] then
		return ALLOW
	end

	SF.throw( "You do not have permission to run ".. SF.Permissions.privileges[ key ].name ..".", 2 )
	return DENY
end

SF.Permissions.registerProvider( Provider )