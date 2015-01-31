---------------------------------------------------------------------
-- SF Group Functions
---------------------------------------------------------------------

local P = SF.Permissions

if SERVER then
	--- Registers a group privilege to the SF.Permissions.privileges table
	function registerGroup( id, group )
		SF.Permissions.privileges[ id ].group = {}

		local queryString = {
			insert = "INSERT INTO ".. P.table .." (`permission`, `group`) SELECT '".. id .."', '".. group .."' WHERE NOT EXISTS (SELECT * FROM ".. P.table .." WHERE `group`='".. id .."' AND `permission`='".. group .."');",
			select = "SELECT `group` FROM sf_permissions WHERE permission='".. id .."'"
		}
		if P.useMysqloo and P.database then
			local query = P.database:query( queryString.insert )
			query:start()
			local query = P.database:query( queryString.select )
			query:start()
			query:wait()
			for i = 1, #( query ) do
				P.privileges[ id ].group[ query[ i ].group ] = true
			end
		else
			local query = sql.Query( queryString.insert )
			local query = sql.Query( queryString.select )
			for i = 1, #( query ) do
				P.privileges[ id ].group[ query[ i ].group ] = true
			end
		end
		net.Start( "sf_groupperm_response" )
			net.WriteString( id )
			net.WriteTable( P.privileges[ id ] )
		net.Broadcast()
	end

	util.AddNetworkString( "sf_sendperm_group" )
	net.Receive( "sf_sendperm_group", function( _, ply )
		local id = net.ReadString()
		local name = net.ReadString()
		local desc = net.ReadString()
		local group = net.ReadString()
		P.registerPrivilege( id, name, desc )
		registerGroup( id, group )
		net.Start( "sf_groupperm_response" )
			net.WriteString( id )
			net.WriteTable( P.privileges[ id ] )
		net.Broadcast()
	end )
elseif CLIENT then
	permRequests = {}
end

hook.Add( "sf_registerPrivilege", "SF_PERM", function( id, name, description, source )
	if SERVER then
		registerGroup( id, "superadmin" )
	elseif CLIENT then
		if source == "cl" then
			table.insert( permRequests, { id = id, name = name, desc = description, group = "*" } )
			table.insert( permRequests, { id = id .. ".others", name = name .. " (Others)", desc = description, group = "superadmin" } )
		end
	end
end )

if SERVER then
	util.AddNetworkString( "sf_clperm_request" )
	util.AddNetworkString( "sf_groupperm_response" )
	hook.Add( "PlayerInitialSpawn", "sf_sendperm_group", function( ply )
		net.Start( "sf_clperm_request" )
		net.Send( ply )
	end )
elseif CLIENT then
	net.Receive( "sf_clperm_request", function( )
		for _, v in pairs( permRequests ) do
			net.Start( "sf_sendperm_group" )
				net.WriteString( v.id )
				net.WriteString( v.name)
				net.WriteString( v.desc )
				net.WriteString( v.group )
			net.SendToServer()
		end
	end )

	net.Receive( "sf_groupperm_response", function( )
		local id = net.ReadString()
		local priv = net.ReadTable()
		P.privileges[ id ] = priv
	end )
end

if SERVER then
	util.AddNetworkString( "sf_concommand_perm_get" )
	util.AddNetworkString( "sf_concommand_perm_add" )
	util.AddNetworkString( "sf_concommand_perm_del" )
	net.Receive( "sf_concommand_perm_add", function( )
		local id = net.ReadString()
		local group = net.ReadString()

		local perm = P.privileges[ id ]
		perm.group[ group ] = true

		local queryString = {
			insert = "INSERT INTO ".. P.table .." (`permission`, `group`) SELECT '".. id .."', '".. group .."' WHERE NOT EXISTS (SELECT * FROM ".. P.table .." WHERE `group`='".. id .."' AND `permission`='".. group .."');",
			select = "SELECT `group` FROM sf_permissions WHERE permission='".. id .."'"
		}

		if P.useMysqloo and P.database then
			local query = P.database:query( queryString.insert )
			query:start()
			local query = P.database:query( queryString.select )
			query:start()
			query:wait()
			for i = 1, #( query ) do
				P.privileges[ id ].group[ query[ i ].group ] = true
			end
		else
			local query = sql.Query( queryString.insert )
			local query = sql.Query( queryString.select )
			for i = 1, #( query ) do
				P.privileges[ id ].group[ query[ i ].group ] = true
			end
		end
		net.Start( "sf_groupperm_response" )
			net.WriteString( id )
			net.WriteTable( P.privileges[ id ] )
		net.Broadcast()
	end )

	net.Receive( "sf_concommand_perm_del", function( )
		 local id = net.ReadString()
		local group = net.ReadString()

		local perm = P.privileges[ id ]
		perm.group[ group ] = nil

		local queryString = {
			delete = "DELETE FROM ".. P.table .." WHERE `permission`='".. args[ 1 ] .."' AND `group`='".. args[ 2 ] .."';",
			select = "SELECT `group` FROM sf_permissions WHERE permission='".. id .."'"
		}

		 if P.useMysqloo and P.database then
			 local query = P.database:query( queryString.delete )
			 query:start()
			 local query = P.database:query( queryString.select )
			 query:start()
			 query:wait()
			 for i = 1, #( query ) do
				 P.privileges[ id ].group[ query[ i ].group ] = true
			 end
		 else
			 local query = sql.Query( queryString.delete )
			 local query = sql.Query( queryString.select )
			 for i = 1, #( query ) do
				 P.privileges[ id ].group[ query[ i ].group ] = true
			 end
		 end
		 net.Start( "sf_groupperm_response" )
			 net.WriteString( id )
			 net.WriteTable( P.privileges[ id ] )
		 net.Broadcast()
	end )
elseif CLIENT then
	net.Receive( "sf_concommand_perm_get", function( len )
		if len == 1 then
			print( "No such permission: ".. net.ReadString() )
		else
			print( net.ReadString(), net.ReadString(), net.ReadString() )
		end
	end )
end

--- Prints the permission passed
P.registerPrivilege( "permissions.get", "sf_getperm", "Console command to get the required group(s) of a starfall permission" )
concommand.Add( "sf_getperm", function( ply, _, args )
	if CLIENT then
		if not P.privileges[ "permissions.get" ].group[ ply:GetUserGroup() ] then return end
	end

	if P.privileges[ args[1] ] ~= nil then
		local perm = P.privileges[ args[1] ]
		local groups = ""
		for k, v in pairs( perm.group ) do
			groups = groups .. k .. " "
		end
		if IsValid( ply ) then
			net.Start( "sf_concommand_perm_get" )
				net.WriteString( perm.name )
				net.WriteString( perm.description )
				net.WriteString( groups )
			net.Send( ply )
		else
			print( perm.name, perm.description, groups )
		end
	else
		if IsValid( ply ) then
			net.Start( "sf_concommand_perm_get" )
				net.WriteString( "No such permission: ".. args[ 1 ] or "nil" )
			net.Send( ply )
		else
			print( "No such permission: ".. args[ 1 ] or "nil" )
		end
	end
end )

--- Grants permission ( arg[1] ) to group ( arg[2] )
P.registerPrivilege( "permissions.add", "sf_addperm", "Console command to grant access to a starfall permission to a usergroup" )
concommand.Add( "sf_addperm", function( ply, _, args )
	if CLIENT then
		if not P.privileges[ "permissions.add" ].group[ ply:GetUserGroup() ] then return end
	end

	if not P.groups[ args[ 2 ] ] and args[ 2 ] ~= "*" then
		print( "Invalid group supplied: ".. args[ 2 ] .."." )
		return
	end

	if P.privileges[ args[1] ] ~= nil then
		local perm = P.privileges[ args[1] ]
		perm.group[ args[2] ] = true

		if SERVER then
			local queryString = "INSERT INTO ".. P.table .." (`permission`, `group`) SELECT '".. args[ 1 ] .."', '".. args[ 2 ] .."' WHERE NOT EXISTS (SELECT * FROM ".. P.table .." WHERE `group`='".. args[ 1 ] .."' AND `permission`='".. args[ 2 ] .."');"

			if P.useMysqloo and P.database then
				local query = P.database:query( queryString )
				query:start()
			else
				local query = sql.Query( queryString )
			end
		elseif CLIENT then
			net.Start( "sf_concommand_perm_add" )
				net.WriteString( id )
				net.WriteString( group )
			net.SendToServer()
		end
	else
		print( "No such permission: ".. args[ 1 ] )
	end
end )

--- Revokes permission ( arg[1] ) from group ( arg[2] )
P.registerPrivilege( "permissions.delete", "sf_delperm", "Console command to revoke access to a starfall permission from a usergroup" )
concommand.Add( "sf_delperm", function( ply, _, args )
	if CLIENT then
		if not P.privileges[ "permissions.delete" ].group[ ply:GetUserGroup() ] then return end
	end

	if not P.groups[ args[ 2 ] ] and args[ 2 ] ~= "*" then
		print( "Invalid group supplied: ".. args[ 2 ] .."." )
		return
	end

	if P.privileges[ args[1] ] ~= nil then
		local perm = P.privileges[ args[1] ]
		perm.group[ args[2] ] = nil

		if SERVER then
			local queryString = "DELETE FROM ".. P.table .." WHERE `permission`='".. args[ 1 ] .."' AND `group`='".. args[ 2 ] .."';"

			if P.useMysqloo and P.database then
				local query = P.database:query( queryString )
				query:start()
			else
				local query = sql.Query( queryString )
			end
		elseif CLIENT then
			--Request server to delete perm
		end
	else
		print( "No such permission: ".. args[ 1 ] )
	end
end )
