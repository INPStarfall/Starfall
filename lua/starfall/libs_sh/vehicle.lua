-- Vehicle type and functions

local vehicle_methods, vehicle_metamethods = SF.Typedef( "Vehicle", SF.GetTypeDef( "Entity" ) )

local vwrap = SF.WrapObject

--- Using a custom wrapper / unwrapper similar to the player wrapper

local function wrap ( obj )
	obj = SF.GetTypeDef( "Entity" ).__wrap( obj )
	debug.setmetatable( obj, vehicle_metamethods )
	return obj
end

local unwrap = SF.GetTypeDef( "Entity" ).__unwrap

SF.AddObjectWrapper( debug.getregistry().Vehicle, vehicle_metamethods, wrap )
SF.AddObjectUnwrapper( vehicle_metamethods, unwrap )

function vehicle_metamethods:__tostring ()
	local ent = unwrap( self )
	if not ent then
		return "(NULL Entity)"
	else
		return tostring( ent )
	end
end
