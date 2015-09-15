local P = {}

local canTool = {
	[ "wire.entity.wire.create" ] = true,
	[ "wire.entity.wire.delete" ] = true,
	[ "wire.entity.get.input" ] = true,
	[ "wire.entity.wgetire.output" ] = true,
}

local function check ( player, node, entity )
	if canTool[ node ] then
		if entity:GetOwner() == player then
			return SF.Permissions.hasNode( player, node .. ".self" )
		elseif CPPI then
			if entity:CPPICanTool( player, "starfall_ent_lib" ) then
				return SF.Permissions.hasNode( player, node .. ".buddy" )
			end
		end

		return SF.Permissions.hasNode( player, node .. ".other" )
	else
		return SF.Permissions.hasNode( player, node )
	end
end

function P.check ( player, node, entities )
	if type( entities ) == "table" then
		for _, v in pairs( entities ) do
			if not check( player, node, v ) then
				return false
			end
		end
		return true
	end

	return check( player, node, entities )
end

SF.Permissions.registerProvider( P )