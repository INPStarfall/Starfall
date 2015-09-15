local P = {}

function P.check ( player, node, entity, path )
	--TODO: Check permissions with path too
	if type( entity ) == "Entity" then
		if entity:GetOwner() == player then
			return SF.Permissions.hasNode( player, node .. ".self" )
		elseif CPPI and entity:CPPICanTool( player, "starfall_ent_lib" ) then
			return SF.Permissions.hasNode( player, node .. ".buddy" )
		end

		return SF.Permissions.hasNode( player, node .. ".other" )
	else
		return SF.Permission.hasNode( player, node )
	end
end

SF.Permissions.registerProvider( P )