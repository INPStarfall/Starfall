-- Vehicle type and functions

SF.Vehicles = {}

local vehicle_methods, vehicle_metamethods = SF.Typedef( "Vehicle", SF.Entities.Metatable )

local vwrap = SF.WrapObject

SF.Vehicles.Methods = vehicle_methods
SF.Vehicles.Metatable = vehicle_metamethods

--- Using a custom wrapper / unwrapper similar to the player wrapper

local function wrap ( obj )
	obj = SF.Entities.Wrap( obj )
	debug.setmetatable( obj, vehicle_metamethods )
	return obj
end

local unwrap = SF.Entities.Unwrap

SF.AddObjectWrapper( debug.getregistry().Vehicle, vehicle_metamethods, wrap )
SF.AddObjectUnwrapper( vehicle_metamethods, unwrap )

--- Adding the wrap / unwrap functions to the SF.Vehicles table
SF.Vehicles.Wrap = wrap
SF.Vehicles.Unwrap = unwrap

function vehicle_metamethods:__tostring ()
	local ent = unwrap( self )
	if not ent then
		return "(NULL Entity)"
	else
		return tostring( ent )
	end
end
