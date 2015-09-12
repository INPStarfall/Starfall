---------------------------------------------------------------------
-- SF Permissions management
---------------------------------------------------------------------
SF.Permissions = {}

local P = SF.Permissions
P.__index = P

P.nodes = {}

P.AdminMod = CreateConVar( "sf_adminmod", "", { FCVAR_ARCHIVE }, "The name of the adminmod to use for starfall permissions" )

local providers = {}
local adminMod = {}

--- Adds a provider implementation to the set used by this library.
-- Providers must implement the {@link SF.Permissions.Provider} interface.
-- @param provider the provider to be registered
-- @param lib the name of the library, defaults to the libraries directory that the function was called from
function P.registerProvider ( provider, lib )
	if type( provider ) ~= "table"
		or ( provider.check and type( provider.check ) ~= "function" )
		or ( provider.modify and type( provider.modify ) ~= "function" ) then
		error( "given object does not implement the provider interface", 2 )
	end

	local libname = debug.getinfo( 2, "S" ).short_src:match( "starfall%/libraries%/(.*)%/.*%.lua" )

	providers[ libname ] = provider
end

--- Registers a privilege
-- @param nodeID unique identifier of the privilege being registered
-- @param nodeTable The node table
function P.registerNode ( nodeID, nodeTable )
	P.nodes[ nodeID ] = { id = nodeID }
	local node = P.nodes[ nodeID ]
	node.name = nodeTable.name
	node.description = nodeTable.description
	node.default = nodeTable.default
	node.parent = nodeTable.parent

	if nodeTable.children then
		node.children = {}
		for k, v in pairs( nodeTable.children ) do
			node.children[ nodeID .. "." .. k ] = true

			v.parent = nodeID
			if v.default == nil then
				v.default = node.default
			end

			P.registerNode( nodeID .. "." .. k, v )
		end
	end

	if adminMod.registerNode then
		adminMod.registerNode( nodeID, nodeTable )
	end
end

--- Checks whether a player has a specified node
-- @param player The player to check
-- @param nodeID The string that identifies the node
function P.hasNode ( player, nodeID )
	local ret
	if hasNodeOverride then
		ret = hasNodeOverride( player, nodeID )
	end

	if ret == nil then
		local node = P.nodes[ nodeID ]
		if not node then return false end

		if node.default ~= nil then
			if node.default == true then
				ret = true
			elseif node.default == "owner" then
				ret =  player:IsSuperAdmin( )
			else
				ret =  false
			end
		elseif node.parent then
			ret =  P.hasNode( player, node.parent )
		else
			ret =  false
		end
	end

	return ret
end

--- Overrides the hasNode function
-- @param adminModTable The admin mod table
function P.registerAdminMod( adminModTable )
	if type( adminModTable ) ~= "table"
			or ( adminModTable.hasNode and type( adminModTable.hasNode ) ~= "function" )
			or ( adminModTable.registerNode and type( adminModTable.registerNode ) ~= "function" ) then
		error( "given object does not implement the admin mod interface", 2 )
	end

	adminMod = adminModTable
end

--- Checks whether a player may perform an action.
-- @param player the player performing the action to be authorized
-- @param nodeID a string identifying the action being performed
-- @param ... Any arguments to pass to the provider
-- @return boolean whether the action is permitted
function P.check ( player, nodeID, ... )
	local lib = nodeID:match( "^(.*)%..*" )

	local provider = providers[ lib ]
	if provider and provider.check then
		return provider.check( player, nodeID, unpack{ ... } )
	end

	return P.hasNode( player, nodeID )
end

local nodesJSON = {}
if SERVER then
	util.AddNetworkString( "starfall_client_node_data" )

	hook.Add( "PlayerAuthed", "starfall_send_node_data", function ( ply )
		net.Start( "starfall_client_node_data" )
		net.WriteTable( nodesJSON )
		net.Send( ply )
	end )

	--- Loads the permissions file for a library and registers all nodes that are decalred within
	-- @param lib The name of the library
	function P.loadLibPermissions ( lib )
		if file.Exists( lib .. "/permissions.json", "LUA" ) then
			local nodes = file.Read( lib .. "/permissions.json", "LUA" )
			nodes = util.JSONToTable( nodes )

			if nodes == nil then return end

			nodesJSON[ lib ] = nodes

			for node, nodeTable in pairs( nodes ) do
				P.registerNode( node, nodeTable )
			end

			if file.Exists( lib .. "/permissions.lua", "LUA" ) then
				include( lib .. "/permissions.lua" )
				AddCSLuaFile( lib .. "/permissions.lua" )
			end
		end
	end
elseif CLIENT then
	net.Receive( "starfall_client_lib_data", function ()
		nodesJSON = net.ReadTable( )
	end )

	function P.loadLibPermissions ( lib )
		if nodesJSON[ lib ] then
			local nodes = nodesJSON[ lib ]

			for node, nodeTable in pairs( nodes ) do
				P.registerNode( node, nodeTable )
			end

			if file.Exists( lib .. "/permissions.lua", "LUA" ) then
				include( lib .. "/permissions.lua" )
			end
		end
	end
end

hook.Add( "sf_libs_loaded", "starfall_load_permissions", function ()
	local _, dirs = file.Find( "starfall/libraries/*", "LUA" )

	if SERVER and P.AdminMod:GetString() ~= "" then
		if file.Exists( "starfall/permissions/" .. P.AdminMod:GetString() .. ".lua", "LUA" ) then
			include( "starfall/permissions/" .. P.AdminMod:GetString() .. ".lua" )
			AddCSLuaFile( "starfall/permissions/" .. P.AdminMod:GetString() .. ".lua" )
		end
	elseif CLIENT then
		for _, file in pairs( file.Find( "starfall/permissions/*.lua", "LUA" ) ) do
			include( "starfall/permissions/" .. file )
		end
	end

	for _, dir in pairs( dirs ) do
		if SF.Libraries.wasLoaded( dir ) then
			P.loadLibPermissions( "starfall/libraries/" .. dir )
		end
	end
end )
