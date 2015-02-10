---------------------------------------------------------------------
-- SF Server Group Provider
---------------------------------------------------------------------

--  TODO: Clients opt-into / out-out-of running client side functions from other users ie. allow clients to run sf_addperm on cl.other perms even without the privilege
-- TODO: Wildcards for permissions
-- TODO: A gui for managing permissions / groups

local P = SF.Permissions

if SERVER then --Not needed but just as a safeguard to prevent users from getting mysql information
	include( "starfall/permissions/database.lua" )

	local queryStr = "CREATE TABLE `".. P.table .."` (`group` text NOT NULL, `permission` varchar(255) NOT NULL);"
	if P.useMysqloo then
		require( "mysqloo" )

		if P.host then
			local function checkTable()
				local makePermTable = P.database:query( queryStr )
				makePermTable.onError = function(Q, Err) print("Failed to Create sf permission table: " .. Err) end
				makePermTable:start()
				makePermTable:wait()
			end

			local function connectDB()
				P.database = mysqloo.connect( P.host, P.user, P.pass, P.dbName, P.port )
				P.database:connect( )

				function P.database:onConnectionFailed( err )
					Msg("Starfall permissions database connection error: "..err.."\n")
				end

				function P.database:onConnected()
					Msg("Connected to the starfall permissions database\n")
					checkTable()
				end
			end
			connectDB()
		end
	else
		if not sql.TableExists( P.table ) then
			local query = sql.Query( queryStr )
			if query == false then
				error( "Error creating the SF Permisisons table: ".. sql.LastError() )
			end
		end
	end

	P.groups = {}
	if evolve then
		for k, _ in pairs( evolve.ranks ) do
			P.groups[ k ] = true
		end
	elseif ulx and ULib then
		for k, v in pairs( ULib.ucl.groups ) do
			P.groups[ k ] = true
		end
	else
		P.groups = {
			[ "superadmin" ] = true,
			[ "admin" ] = true,
			[ "user" ] = true
		}
	end
end

local Provider = setmetatable( {}, { __index = SF.Permissions.Provider } )

local ALLOW = SF.Permissions.Result.ALLOW
local DENY = SF.Permissions.Result.DENY
local NEUTRAL = SF.Permissions.Result.NEUTRAL

local function getGroup( ply )
	if evolve then
		return ply:EV_GetRank( )
	else
		return ply:GetUserGroup( )
	end
end

function Provider:check ( principal, target, key )
	if SF.Permissions.privileges[ key ].group[ getGroup( principal ) ] or SF.Permissions.privileges[ key ].group[ "*" ] then
		return ALLOW
	end
	SF.throw( "You do not have permission to run ".. SF.Permissions.privileges[ key ].name ..".", 2 )
	return DENY
end

SF.Permissions.registerProvider( Provider )
