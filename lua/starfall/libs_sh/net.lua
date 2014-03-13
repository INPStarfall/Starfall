-------------------------------------------------------------------------------
-- Networking library.
-------------------------------------------------------------------------------

local net = net

--- Net message library. Used for sending data from the server to the client and back
--@deprecated Will be replaced by signal library once it is ready
local net_library, _ = SF.Libraries.Register("net")

local burst_limit = CreateConVar( "sf_net_burst_limit", "10", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
					"The net message burst limit." )

local burst_interval = CreateConVar( "sf_net_burst_interval", "0.1", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
						"The interval of the timer that adds one more available net message. Requires a map reload to update." )

local function can_send( instance, noupdate )
	if instance.data.net.burst > 0 then
		if not noupdate then instance.data.net.burst = instance.data.net.burst - 1 end
		return true
	else
		return false
	end
end

local function write( instance, type, value, setting )
	instance.data.net.data[#instance.data.net.data+1] = { "Write" .. type, value, setting }
end

local instances = {}
SF.Libraries.AddHook( "initialize", function( instance )
	instance.data.net = {
		started = false,
		burst = burst_limit:GetInt(),
		data = {},
	}
	
	instances[instance] = true
end)

SF.Libraries.AddHook( "deinitialize", function( instance )
	if instance.data.net.started then
		instance.data.net.started = false
	end
	
	instances[instance] = nil
end)

timer.Create( "SF_Net_BurstCounter", burst_interval:GetFloat(), 0, function()
	for instance, b in pairs( instances ) do
		if instance.data.net.burst < burst_limit:GetInt() then
			instance.data.net.burst = instance.data.net.burst + 1
		end
	end
end)

if SERVER then
	util.AddNetworkString( "SF_netmessage" )
	
	local function checktargets( target )
		if target then
			if SF.GetType(target) == "table" then
				local newtarget = {}
				for i=1,#target do
					SF.CheckType( SF.Entities.Unwrap(target[i]), "Player", 1 )
					newtarget[i] = SF.Entities.Unwrap(target[i])
				end
				return net.Send, newtarget
			else
				SF.CheckType( SF.Entities.Unwrap(target), "Player", 1 ) -- TODO: unhacky this
				return net.Send, SF.Entities.Unwrap(target)
			end
		else
			return net.Broadcast
		end
	end
	
	--- Send the net message
	-- @server
	-- @param target The player or table of players to send the message to, or nil to send to everyone

	function net_library.send( target )
		local instance = SF.instance
		if not instance.data.net.started then error("net message not started",2) end

		local sendfunc, newtarget = checktargets( target )
		
		local data = instance.data.net.data
		if #data == 0 then return false end
		net.Start( "SF_netmessage" )
		for i=1,#data do
			local writefunc = data[i][1]
			local writevalue = data[i][2]
			local writesetting = data[i][3]
			
			net[writefunc]( writevalue, writesetting )
		end
		
		sendfunc( newtarget )
	end
else
	--- Send the net message to the server
	-- @client
	function net_library.send()
		local instance = SF.instance
		if not instance.data.net.started then error("net message not started",2) end
		
		local data = instance.data.net.data
		if #data == 0 then return false end
		net.Start( "SF_netmessage" )
		for i=1,#data do
			local writefunc = data[i][1]
			local writevalue = data[i][2]
			local writesetting = data[i][3]
			
			net[writefunc]( writevalue, writesetting )
		end
		
		net.SendToServer()
	end
end

--- Starts the net message
-- @shared
-- @param name The message name
function net_library.start( name )
	SF.CheckType( name, "string" )
	local instance = SF.instance
	if not can_send( instance ) then return error("can't send net messages that often",2) end
	
	instance.data.net.started = true
	instance.data.net.data = {}
	write( instance, "String", name )
end

---------------------------------------
-------------------------- Writing
---------------------------------------


--- Writes a table to the net message
-- @shared
-- @param table The table to be written

function net_library.writeTable( t )
	local instance = SF.instance
	if not instance.data.net.started then error("net message not started",2) end
	
	SF.CheckType( t, "table" )
	
	write( instance, "Table", SF.Unsanitize(t) )
	return true
end

--- Writes a string to the net message
-- @shared
-- @param string The string to be written

function net_library.writeString( t )
	local instance = SF.instance
	if not instance.data.net.started then error("net message not started",2) end

	SF.CheckType( t, "string" )

	write( instance, "String", t )
	return true
end

--- Writes an integer to the net message
-- @shared
-- @param integer The integer to be written
-- @param bitCount The amount of bits the integer consists of

function net_library.writeInt( t, n )
	local instance = SF.instance
	if not instance.data.net.started then error("net message not started",2) end

	SF.CheckType( t, "number" )
	SF.CheckType( n, "number" )

	write( instance, "Int", t, n )
	return true
end

--- Writes an unsigned integer to the net message
-- @shared
-- @param integer The integer to be written
-- @param bitCount The amount of bits the integer consists of. Should not be greater than 32

function net_library.writeUInt( t, n )
	local instance = SF.instance
	if not instance.data.net.started then error("net message not started",2) end

	SF.CheckType( t, "number" )
	SF.CheckType( n, "number" )

	write( instance, "UInt", t, n )
	return true
end

--- Writes a bit to the net message
-- @shared
-- @param bit The bit to be written. (boolean)

function net_library.writeBit( t )
	local instance = SF.instance
	if not instance.data.net.started then error("net message not started",2) end

	SF.CheckType( t, "boolean" )

	write( instance, "Bit", t )
	return true
end

--- Writes a double to the net message
-- @shared
-- @param double The double to be written

function net_library.writeDouble( t )
	local instance = SF.instance
	if not instance.data.net.started then error("net message not started",2) end

	SF.CheckType( t, "number" )

	write( instance, "Double", t )
	return true
end

--- Writes a float to the net message
-- @shared
-- @param double The float to be written

function net_library.writeFloat( t )
	local instance = SF.instance
	if not instance.data.net.started then error("net message not started",2) end

	SF.CheckType( t, "number" )

	write( instance, "Float", t )
	return true
end


---------------------------------------
-------------------------- Reading
---------------------------------------

local values_read = {}
local values_read_pointer = 1
local function read( value, type )
	if values_read_pointer > #values_read then
		values_read[values_read_pointer] = { value, type }
		values_read_pointer = values_read_pointer + 1
		return value
	else
		local t = values_read[values_read_pointer]
		local value, _type = t[1], t[2]
		values_read_pointer = values_read_pointer + 1
		if _type == type then
			return value
		end
	end
end

local function resetValuesReadPointer()
	values_read_pointer = 1
end

local function resetValuesRead()
	values_read = {}
	resetValuesReadPointer()
end
		
--- Reads a table from the net message
-- @shared
-- @return The table that was read

function net_library.readTable()
	return read( SF.Sanitize(net.ReadTable()), "table" )
end

--- Reads a string from the net message
-- @shared
-- @return The string that was read

function net_library.readString()
	return read( net.ReadString(), "string" )
end


--- Reads an integer from the net message
-- @shared
-- @param bitCount The amount of bits to read
-- @return The integer that was read

function net_library.readInt(n)
	SF.CheckType( n, "number" )
	return read( net.ReadInt(n), "int" )
end

--- Reads an unsigned integer from the net message
-- @shared
-- @param bitCount The amount of bits to read
-- @return The unsigned integer that was read

function net_library.readUInt(n)
	SF.CheckType( n, "number" )
	return read( net.ReadUInt(n), "uint" )
end

--- Reads a bit from the net message
-- @shared
-- @return The bit that was read. (0 for false, 1 for true)

function net_library.readBit()
	return read( net.ReadBit(), "bit" )
end

--- Reads a double from the net message
-- @shared
-- @return The double that was read

function net_library.readDouble()
	return read( net.ReadDouble(), "double" )
end

--- Reads a float from the net message
-- @shared
-- @return The float that was read

function net_library.readFloat()
	return read( net.ReadFloat(), "float" )
end

---------------------------------------
-------------------------- Other
---------------------------------------

--- Gets the amount of bytes written so far
-- @return The amount of bytes written so far

function net_library.bytesWritten()
	local instance = SF.instance
	if not instance.data.net.started then error("net message not started",2) end

	return net.BytesWritten()
end

--- Checks whether you can currently send a net message
-- @return A boolean that states whether or not you can currently send a net message

function net_library.canSend()
	return can_send(SF.instance, true)
end

---------------------------------------
-------------------------- Hook
---------------------------------------

net.Receive( "SF_netmessage", function( len, ply )
	resetValuesRead()
	
	local name = net.ReadString()
	
	--- Calls a script hook on all processors.
	for _,instance in pairs(SF.allInstances) do
	
		if not instance.error then
			local ok, err = instance:runScriptHook("net", name, len, ply and SF.WrapObject( ply ))
			if not ok then
				instance.error = true
				if instance.runOnError then
					instance:runOnError( err )
				end
			end
			
			resetValuesReadPointer()
		end
	end

	--SF.RunScriptHook( "net", net.ReadString(), len, ply and SF.WrapObject( ply ) )
end)
