--- Concommand library
-- @name concommand
-- @shared
-- @class library
-- @libtbl concmd_library
local concmd_library, _ = SF.Libraries.Register( "concommand" )

if SERVER then
	util.AddNetworkString( "SF_concmd init" )
	util.AddNetworkString( "SF_concmd execute" )
	util.AddNetworkString( "SF_concmd add" )
	util.AddNetworkString( "SF_concmd help" )
end

local function init()

	if not SF.concommands then SF.concommands = {} end
	
	if CLIENT then

		SF.concommands["help"] = {func=function()
			for k, v in pairs( SF.concommands ) do 
				print( k ) 
			end
			net.Start( "SF_concmd help" )
			net.SendToServer()
		end, instance=nil}

		concommand.Add( "sf", function( ply, cmd, args, fullstring )

			if #args == 0 then print( "No command entered, use the command 'help' to see added commands" ) return end
				
			local cmd = table.remove( args, 1 )
				
			local func = SF.concommands[ cmd ]

			if func then 
				if func.instance then 
					local playerBefore = func.instance.player
					func.instance.player = LocalPlayer()
					func.func( ply, cmd, args, fullstring )
					func.instance.player = playerBefore
				else
					func.func( ply, cmd, args, fullstring )
				end
			else 
				local send = {}
				send.cmd = cmd
				send.args = args
				send.fullstring = fullstring

				net.Start( "SF_concmd execute" )
					net.WriteTable( send )
				net.SendToServer()
			end

		end )
	end
end

local function findPlayer( search ) 
	if not search then return end
	for k, v in pairs( player.GetAll() ) do 
		if string.find( string.lower( v:GetName() ), string.lower( search ) ) then 
			return v
		end 
	end 
	return nil
end

-- net receives
if SERVER then 
	net.Receive( "SF_concmd execute", function( len, ply ) 
		local send = net.ReadTable()

		local func = SF.concommands[ ply ][ send.cmd ]

		local success = false
		if func then
			func.func( ply, send.cmd, send.args, send.fullstring )
			success = true
		end
		if not success then ply:ChatPrint( "Command does not exist, use the command 'help' to see added commands" ) end
	end )
	net.Receive( "SF_concmd help", function( len, ply ) 
		for k, v in pairs( SF.concommands[ ply ] ) do 
			ply:ChatPrint( k ) 
		end
	end )
	net.Receive( "SF_concmd init", function( len, ply )
		SF.concommands[ ply ] = {}
		if ply:IsAdmin() then
			SF.concommands[ ply ][ "run" ] = {func=function( player, cmd, args )
				if not player:IsAdmin() then 
					player:ChatPrint( "You need to be an admin to use this command" ) 
					SF.concommands[ player ][ "run" ] = nil 
					return
				end

				if not args or not args[1] or not args[2] then player:ChatPrint( "Usage: sf run <player> <command> <args>" ) return end

				local target = findPlayer( table.remove( args, 1 ) )
				if not target then player:ChatPrint( "Player not found" ) return end

				local run = table.remove( args, 1 )
				local func = SF.concommands[ target ][ run ]

				target:ConCommand( "sf " .. run .. " " .. table.concat( args, " " ) )
				player:ChatPrint( "Command sent" )
			end, instance=nil}
		end
	end )
elseif CLIENT then
	hook.Add( "InitPostEntity", "sf_concmd init", function()
		net.Start( "SF_concmd init" ) net.SendToServer()
	end )
end

net.Receive( "SF_concmd add", function( len, ply )
	if ply then
		SF.concommands[ ply ][ net.ReadString() ] = nil
	else
		SF.concommands[ net.ReadString() ] = nil
	end
end )

--- Adds an sf console command, used like 'sf <name> <args>' in console
-- @shared
-- @param name The command name to be used in console
-- @param func The function to run when the concommand is executed, Args: ( Player ply, string cmd, table args, string fullstring )
function concmd_library.add( name, func )
	if CLIENT and SF.instance.player ~= LocalPlayer() then return end -- only execute on owner of screen
	SF.CheckType( name, "string" )
	SF.CheckType( func, "function" )

	if SERVER then
		SF.concommands[ SF.instance.player ][ name ] = {func=SF.WrapFunction( func, SF.instance ), instance=SF.instance}
	else
		SF.concommands[ name ] = {func=SF.WrapFunction( func, SF.instance ), instance=SF.instance}
	end

	net.Start( "SF_concmd add" )
		net.WriteString( name )
	if SERVER then net.Send( SF.instance.player ) else net.SendToServer() end
end

--- Removes an sf console command
-- @shared
-- @param name The name of the command to be removed
function concmd_library.remove( name )
	if CLIENT and SF.instance.player ~= LocalPlayer() then return end -- only execute on owner of screen
	SF.CheckType( name, "string" )

	if SERVER then
		SF.concommands[ SF.instance.player ][ name ] = nil
	else
		SF.concommands[ name ] = nil
	end
end

if CLIENT then
	--- Adds an sf console command to every player, for admins only
	-- @client
	-- @param name The command name to be used in console
	-- @param func The function to run when the concommand is executed, Args: ( Player ply, string cmd, table args, string fullstring )
	function concmd_library.addAll( name, func )
		if not SF.instance.player:IsAdmin() then SF.throw( "You need to be an admin to use this function.", 2 ) end
		SF.CheckType( name, "string" )
		SF.CheckType( func, "function" )

		if SERVER then
			SF.concommands[ SF.instance.player ][ name ] = {func=SF.WrapFunction( func, SF.instance ), instance=SF.instance}
		else
			SF.concommands[ name ] = {func=SF.WrapFunction( func, SF.instance ), instance=SF.instance}
		end

		net.Start( "SF_concmd add" )
			net.WriteString( name )
		if SERVER then net.Send( SF.instance.player ) else net.SendToServer() end
	end
end

SF.Libraries.AddHook( "postload", function()
	init()
end )
SF.Libraries.AddHook( "deinitialize", function( instance ) 
	if not SF.concommands then return end
	if SERVER then
		for i, j in pairs( player.GetAll() ) do
			if SF.concommands[ j ] then
				for k, v in pairs( SF.concommands[ j ] ) do
					if v.instance == instance then 
						SF.concommands[ j ][ k ] = nil
					end
				end
			end
		end
	else
		for k, v in pairs( SF.concommands ) do
			if v.instance == instance then 
				SF.concommands[ k ] = nil
			end
		end
	end
end )