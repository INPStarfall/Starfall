local AM = {}

function AM.registerNode ( nodeID, nodeTable )
	if not ULib or nodeTable.children then return end

	ULib.ucl.registerAccess( "sf " .. nodeID, nil, nodeTable.description or "", "Starfall" )
end

function AM.hasNode ( player, nodeID )
	if not ULib then return end

	local ret = false
	local node = SF.Permissions.nodes[ nodeID ]

	if node then
		local ext = ( node.children and ".*" ) or ""

		ret = player:query( "sf " .. nodeID .. ext )
		if not ret and node.parent then
			ret = AM.hasNode( player, node.parent )
		elseif not ret then
			ret = player:query( "sf *" )
		end
	end

	return ret
end

SF.Permissions.registerAdminMod( AM )
