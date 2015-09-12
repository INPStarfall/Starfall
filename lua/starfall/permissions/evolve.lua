local AM = {}

function AM.registerNode( nodeID, nodeTable )
	if not evolve or not SERVER or nodeTable.children then return end

	table.Add( evolve.privileges, { nodeID } )
	table.sort( evolve.priveleges )
end

function AM.hasNode ( player, nodeID )
	if not evolve then return end

	local ret = false
	local node = SF.Permissions.nodes[ nodeID ]

	if node then
		local ext = ( node.children and ".*" ) or ""

		ret = player:EV_HasPrivilege( "sf " .. nodeID .. ext )
		if not ret and node.parent then
			ret = AM.hasNode( player, node.parent )
		elseif not ret then
			ret = player:EV_HasPrivilege( "sf *" )
		end
	end

	return ret
end

SF.Permissions.registerAdminMod( AM )
