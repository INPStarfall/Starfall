local P = {}

local canTool = {
	[ "entities.parent" ] = true,
	[ "entities.unparent" ] = true,
	[ "entities.setSolid" ] = true,
	[ "entities.enableGravity" ] = true,
	[ "entities.setColor" ] = true,
	[ "entities.setSubMaterial" ] = true
}

local canPhysgun = {
	[ "entities.applyForce" ] = true,
	[ "entities.setPos" ] = true,
	[ "entities.setAngles" ] = true,
	[ "entities.setVelocity" ] = true,
	[ "entities.setFrozen" ] = true
}

local function check ( player, node, entity )
	if entity:GetOwner() == player then
		return SF.Permissions.hasNode( player, node .. ".self" )
	elseif CPPI then
		if ( canTool[ node ] and entity:CPPICanTool( player, "starfall_ent_lib" ) ) or ( canPhysgun[ node ] and entity:CPPICanPhysgun( player ) ) then
			return SF.Permissions.hasNode( player, node .. ".buddy" )
		end
	end

	return SF.Permissions.hasNode( player, node .. ".other" )
end

function P.check ( player, node, entities )
	if type( entities ) == "table" then
		for k, v in pairs( entities ) do
			if not check( player, node, v ) then
				return false
			end
		end
		return true
	end

	return check( player, node, entities )
end

SF.Permissions.registerProvider( P )