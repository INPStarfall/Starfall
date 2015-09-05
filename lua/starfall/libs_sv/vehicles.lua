assert( SF.GetTypeDef( "Vehicle" ) )

local vehicle_metamethods = SF.GetTypeDef( "Player" )
local vehicle_methods = vehicle_metamethods.__methods


local wrap = vehicle_metamethods.__wrap
local unwrap = vehicle_metamethods.__unwrap

--- Gets the entity that is driving the vehicle
-- @return The player driving the vehicle or nil if there is no driver
function vehicle_methods:getDriver ()
	local ent = unwrap( self )
	return ent and SF.GetTypeDef( "Player" ).__wrap( ent:GetDriver() ) or nil
end

--- Gets the entity that is the riding in the passenger seat of the vehicle
-- @param n The passenger number to get.
-- @return The passenger player of the vehicle or nil if there is no passenger
function vehicle_methods:getPassenger ( n )
	SF.CheckType( n, "number" )

	local ent = unwrap( self )
	return ent and SF.GetTypeDef( "Player" ).__wrap( ent:GetPassenger( n ) ) or nil
end
