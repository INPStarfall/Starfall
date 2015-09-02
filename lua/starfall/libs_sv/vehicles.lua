assert( SF.Vehicles )

local vehicle_methods = SF.Vehicles.Methods
local vehicle_metamethods = SF.Vehicles.Metatable

local wrap = SF.Vehicles.Wrap
local unwrap = SF.Vehicles.Unwrap

--- Gets the entity that is driving the vehicle
-- @return The player driving the vehicle or nil if there is no driver
function vehicle_methods:getDriver ()
	local ent = unwrap( self )
	return ent and SF.Players.Wrap( ent:GetDriver() ) or nil
end

--- Gets the entity that is the riding in the passenger seat of the vehicle
-- @param n The passenger number to get.
-- @return The passenger player of the vehicle or nil if there is no passenger
function vehicle_methods:getPassenger ( n )
	SF.CheckType( n, "number" )

	local ent = unwrap( self )
	return ent and SF.Players.Wrap( ent:GetPassenger( n ) ) or nil
end
