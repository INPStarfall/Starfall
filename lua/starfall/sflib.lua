-------------------------------------------------------------------------------
-- The main Starfall library
-------------------------------------------------------------------------------

if SF ~= nil then return end
SF = {}

jit.off() -- Needed so ops counting will work reliably.

-- Do a couple of checks for retarded mods that disable the debug table
-- and run it after all addons load
do
	local function zassert(  cond, str )
		if not cond then error( "STARFALL LOAD ABORT: " .. str, 0 ) end
	end

	zassert( debug, "debug table removed" )

	-- Check for modified getinfo
	local info = debug.getinfo( 0, "S" )
	zassert( info, "debug.getinfo modified to return nil" )
	zassert( info.what == "C", "debug.getinfo modified" )

	-- Check for modified setfenv
	info = debug.getinfo( debug.setfenv, "S" )
	zassert( info.what == "C", "debug.setfenv modified" )

	-- Check get/setmetatable
	info = debug.getinfo( debug.getmetatable )
	zassert( info.what == "C", "debug.getmetatable modified" )
	info = debug.getinfo( debug.setmetatable )
	zassert( info.what == "C", "debug.setmetatable modified" )

	-- Lock the debug table
	local olddebug = debug
	debug = setmetatable( {}, {
		__index = olddebug,
		__newindex = function ( self, k, v ) print( "Addon tried to modify debug table" ) end,
		__metatable = "nope.avi",
	})
end

-- Send files to client
if SERVER then
	AddCSLuaFile( "sflib.lua" )
	AddCSLuaFile( "compiler.lua" )
	AddCSLuaFile( "instance.lua" )
	AddCSLuaFile( "libraries.lua" )
	AddCSLuaFile( "preprocessor.lua" )
	AddCSLuaFile( "database.lua" )
	AddCSLuaFile( "permissions/core.lua" )
	AddCSLuaFile( "editor.lua" )
	AddCSLuaFile( "sfderma.lua" )
	AddCSLuaFile( "callback.lua" )
	AddCSLuaFile( "sfhelper.lua" )
end

-- Load files
include( "compiler.lua" )
include( "instance.lua" )
include( "libraries.lua" )
include( "preprocessor.lua" )
include( "database.lua" )
include( "permissions/core.lua" )
include( "editor.lua" )
include( "sfhelper.lua" )

SF.cpuBufferN = CreateConVar( "sf_timebuffersize", 32, { FCVAR_REPLICATED }, "Default number of elements for the CPU Quota Buffer." )

-- We need to make sure that we clear the table if we shrink it, otherwise leftover values will affect the avg.
cvars.AddChangeCallback( "sf_timebuffersize", function ( n, o, u )
	if o > u then
		for _, v in pairs( SF.allInstances ) do
			v.cpuTime.buffer = {}
		end
	end
end )

if SERVER then
	SF.cpuQuota = CreateConVar( "sf_timebuffer", 0.0012, {}, "Default CPU Time Quota for serverside." )
	SF.cacheExpiryTime = CreateConVar( "sf_cache_expiry_time", 10, {}, "Time in minutes when the uploaded code cache expires." )
else
	SF.cpuQuota = CreateClientConVar( "sf_timebuffer", 0.015, false, false )
end


local dgetmeta = debug.getmetatable

--- Throws an error like the throw function in builtins
-- @param msg Message
-- @param level Which level in the stacktrace to blame
-- @param uncatchable Makes this exception uncatchable
function SF.throw ( msg, level, uncatchable )
	local info = debug.getinfo( 1 + ( level or 1 ), "Sl" )
	local filename = info.short_src:match( "^SF:(.*)$" ) or info.short_src
	local err = {
		uncatchable = false,
		file = filename,
		line = info.currentline,
		message = msg,
		uncatchable = uncatchable
	}
	error( err )
end

local real_type = function () end

--- Creates a type that is safe for SF scripts to use. Instances of the type
-- cannot access the type's metatable or metamethods.
-- @param name Name of table
-- @param supermeta The metatable to inheret from
-- @return The table to store normal methods
-- @return The table to store metamethods
SF.Types = {}
function SF.Typedef ( name, supermeta )
	local methods, metamethods = {}, {}
	metamethods.__metatable = name
	metamethods.__index = methods
	metamethods.__methods = methods

	metamethods.__supertypes = { [ metamethods ] = true }

	metamethods.__realType = real_type
	
	if supermeta then
		setmetatable( methods, { __index = supermeta.__index } )
		metamethods.__supertypes[supermeta] = true
		if supermeta.__supertypes then
			for k,_ in pairs( supermeta.__supertypes ) do
				metamethods.__supertypes[ k ] = true
			end
		end
	end

	SF.Types[ name ] = metamethods
	return methods, metamethods
end

function SF.GetTypeDef( name )
	return SF.Types[ name ]
end

-- Include this file after Typedef as this file relies on it.
include( "callback.lua" )

do
	local env, metatable = SF.Typedef( "Environment" )
	--- The default environment metatable
	SF.DefaultEnvironmentMT = metatable
	--- The default environment contents
	SF.DefaultEnvironment = env
end

--- A set of all instances that have been created. It has weak keys and values.
-- Instances are put here after initialization.
SF.allInstances = setmetatable( {},{ __mode = "kv" } )

--- Calls a script hook on all processors.
function SF.RunScriptHook ( hook, ... )
	for _, instance in pairs( SF.allInstances ) do
		if not instance.error then
			local ok, err = instance:runScriptHook( hook, ... )
			if not ok then
				instance.error = true
				if instance.runOnError then
					instance:runOnError( err )
				end
			end
		end
	end
end

--- Creates a new context. A context is used to define what scripts will have access to.
-- @param env The environment metatable to use for the script. Default is SF.DefaultEnvironmentMT
-- @param directives Additional Preprocessor directives to use. Default is an empty table
-- @param ops Operations quota function. Default is specified by the convar "sf_defaultquota" and returned when calling ops()
-- @param libs Additional (local) libraries for the script to access. Default is an empty table.
function SF.CreateContext ( env, directives, cpuTime, libs )
	local context = {}
	context.env = env or SF.DefaultEnvironmentMT
	context.directives = directives or {}
	context.cpuTime = cpuTime or {
		getBufferN = function () return SF.cpuBufferN:GetInt() or 3 end,
		getMax = function () return SF.cpuQuota:GetFloat() end
	}
	context.libs = libs or {}
	return context
end

--- Checks the type of val. Errors if the types don't match
-- @param val The value to be checked.
-- @param typ A string type or metatable.
-- @param level Level at which to error at. 3 is added to this value. Default is 0.
-- @param default A value to return if val is nil.
function SF.CheckType ( val, typ, level, default )
	if val == nil and default then return default
	elseif type( val ) == typ then return val
	else
		local meta = dgetmeta( val )
		if meta == typ or ( meta and meta.__supertypes and meta.__supertypes[ typ ] and meta.__realType == real_type ) then return val end
		
		-- Failed, throw error
		level = ( level or 0 ) + 3
		
		local typname
		if type( typ ) == "table" then
			assert( typ.__metatable and type( typ.__metatable ) == "string")
			typname = typ.__metatable
		else
			typname = typ
		end
		
		local funcname = debug.getinfo( level - 1, "n" ).name or "<unnamed>"
		local mt = getmetatable( val )
		SF.throw( "Type mismatch (Expected " .. typname .. ", got " .. ( type( mt ) == "string" and mt or type( val ) ) .. ") in function " .. funcname, level )
	end
end

--- Gets the type of val.
-- @param val The value to be checked.
function SF.GetType ( val )
	local mt = dgetmeta( val )
	return ( mt and mt.__metatable and type( mt.__metatable ) == "string" ) and mt.__metatable or type( val )
end

-- ------------------------------------------------------------------------- --

local object_wrappers = {}

--- Creates wrap/unwrap functions for sensitive values, by using a lookup table
-- (which is set to have weak keys and values)
-- @param metatable The metatable to assign the wrapped value.
-- @param weakwrapper Make the wrapper weak inside the internal lookup table. Default: True
-- @param weaksensitive Make the sensitive data weak inside the internal lookup table. Default: True
-- @param target_metatable (optional) The metatable of the object that will get
-- 		wrapped by these wrapper functions.  This is required if you want to
-- 		have the object be auto-recognized by the generic SF.WrapObject
--		function.
-- @return The function to wrap sensitive values to a SF-safe table
-- @return The function to unwrap the SF-safe table to the sensitive table
function SF.CreateWrapper ( metatable, weakwrapper, weaksensitive, target_metatable )
	local s2sfmode = ""
	local sf2smode = ""
	
	if weakwrapper == nil or weakwrapper then
		sf2smode = "k"
		s2sfmode = "v"
	end
	if weaksensitive then
		sf2smode = sf2smode .. "v"
		s2sfmode = s2sfmode .. "k"
	end 

	local sensitive2sf = setmetatable( {}, { __mode = s2sfmode } )
	local sf2sensitive = setmetatable( {}, { __mode = sf2smode } )
	
	local function wrap( value )
		if value == nil then return nil end
		if sensitive2sf[ value ] then return sensitive2sf[ value ] end
		local tbl = setmetatable( {}, metatable )
		sensitive2sf[ value ] = tbl
		sf2sensitive[ tbl ] = value
		return tbl
	end
	
	local function unwrap( value )
		return sf2sensitive[ value ]
	end
	
	if target_metatable ~= nil then
		object_wrappers[ target_metatable ] = wrap
		metatable.__wrap = wrap
	end
	
	metatable.__unwrap = unwrap
	
	return wrap, unwrap
end

--- Helper function for adding custom wrappers
-- @param object_meta metatable of object
-- @param sf_object_meta starfall metatable of object
-- @param wrapper function that wraps object
function SF.AddObjectWrapper ( object_meta, sf_object_meta, wrapper )
	sf_object_meta.__wrap = wrapper
	object_wrappers[ object_meta ] = wrapper
end

--- Helper function for adding custom unwrappers
-- @param object_meta metatable of object
-- @param unwrapper function that unwraps object
function SF.AddObjectUnwrapper ( object_meta, unwrapper )
	object_meta.__unwrap = unwrapper
end

--- Wraps the given object so that it is safe to pass into starfall
-- It will wrap it as long as we have the metatable of the object that is
-- getting wrapped.
-- @param object the object needing to get wrapped as it's passed into starfall
-- @return returns nil if the object doesn't have a known wrapper,
-- or returns the wrapped object if it does have a wrapper.
function SF.WrapObject ( object )
	local metatable = dgetmeta( object )
	
	local wrap = object_wrappers[ metatable ]
	return wrap and wrap( object )
end

--- Takes a wrapped starfall object and returns the unwrapped version
-- @param object the wrapped starfall object, should work on any starfall
-- wrapped object.
-- @return the unwrapped starfall object
function SF.UnwrapObject ( object )
	local metatable = dgetmeta( object )
	
	if metatable and metatable.__unwrap then
		return metatable.__unwrap( object )
	end
end

local wrappedfunctions = setmetatable( {}, { __mode = "kv" } )
local wrappedfunctions2instance = setmetatable( {}, { __mode = "kv" } )
--- Wraps the given starfall function so that it may called directly by GMLua
-- @param func The starfall function getting wrapped
-- @param instance The instance the function originated from
-- @return a function That when called will call the wrapped starfall function
function SF.WrapFunction ( func, instance )
	if wrappedfunctions[ func ] then return wrappedfunctions[ func ] end
	
	local function returned_func( ... )
		return SF.Unsanitize( instance:runFunction( func, SF.Sanitize( ... ) ) )
	end
	wrappedfunctions[ func ] = returned_func
	wrappedfunctions2instance[ returned_func ] = instance
	
	return returned_func
end

--- Gets the instance a wrapped function is bound to
-- @param func Function
-- @return Instance
function SF.WrappedFunctionInstance ( func )
	return wrappedfunctions2instance[ func ]
end

-- A list of safe data types
local safe_types = {
	[ "number" ] = true,
	[ "string" ] = true,
	[ "Vector" ] = false,
	[ "Color" ] = false,
	[ "Angle" ] = false,
	[ "Entity" ] = false,
	[ "VMatrix" ] = false,
	[ "boolean" ] = true,
	[ "nil" ] = true,
}

--- Sanitizes and returns its argument list.
-- Basic types are returned unchanged. Non-object tables will be
-- recursed into and their keys and values will be sanitized. Object
-- types will be wrapped if a wrapper is available. When a wrapper is
-- not available objects will be replaced with nil, so as to prevent
-- any possiblitiy of leakage. Functions will always be replaced with
-- nil as there is no way to verify that they are safe.
function SF.Sanitize ( ... )
	-- Sanitize ALL the things.
	local return_list = {}
	local args = { ... }
	
	for key, value in pairs( args ) do
		local typmeta = getmetatable( value )
		local typ = type( typmeta ) == "string" and typmeta or type( value )
		if safe_types[ typ ] then
			return_list[ key ] = value
		elseif SF.WrapObject( value ) then
			return_list[ key ] = SF.WrapObject( value )
		elseif typ == "table" then
			local tbl = {}
			for k,v in pairs( value ) do
				tbl[ SF.Sanitize( k ) ] = SF.Sanitize( v )
			end
			return_list[ key ] = tbl
		else 
			return_list[ key ] = nil
		end
	end
	
	return unpack( return_list )
end

--- Takes output from starfall and does it's best to make the output
-- fully usable outside of starfall environment
function SF.Unsanitize ( ... )
	local return_list = {}
	
	local args = { ... }
	
	for key, value in pairs( args ) do
		local typ = type( value )
		if typ == "table" and SF.UnwrapObject( value ) then
			return_list[ key ] = SF.UnwrapObject( value )
		elseif typ == "table" then
			return_list[ key ] = {}

			for k,v in pairs( value ) do
				return_list[ key ][ SF.Unsanitize( k ) ] = SF.Unsanitize( v )
			end
		else
			return_list[ key ] = value
		end
	end

	return unpack( return_list )
end

-- ------------------------------------------------------------------------- --

local function isnan ( n )
	return n ~= n
end

-- Taken from E2Lib

-- This function clamps the position before moving the entity
local minx, miny, minz = -16384, -16384, -16384
local maxx, maxy, maxz = 16384, 16384, 16384
local clamp = math.Clamp
local function clampPos ( pos )
	pos.x = clamp( pos.x, minx, maxx )
	pos.y = clamp( pos.y, miny, maxy )
	pos.z = clamp( pos.z, minz, maxz )
	return pos
end

function SF.setPos ( ent, pos )
	if isnan( pos.x ) or isnan( pos.y ) or isnan( pos.z ) then return end
	return ent:SetPos( clampPos( pos ) )
end

local huge, abs = math.huge, math.abs
function SF.setAng ( ent, ang )
	if isnan( ang.pitch ) or isnan( ang.yaw ) or isnan( ang.roll ) then return end
	if abs( ang.pitch ) == huge or abs( ang.yaw ) == huge or abs( ang.roll ) == huge then return false end -- SetAngles'ing inf crashes the server
	return ent:SetAngles( ang )
end

-- ------------------------------------------------------------------------- --

local serialize_replace_regex = "[\"\n]"
local serialize_replace_tbl = { [ "\n" ] = string.char( 5 ), [ '"' ] = string.char( 4 ) }

--- Serializes an instance's code in a format compatible with the duplicator library
-- @param sources The table of filename = source entries. Ususally instance.source
-- @param mainfile The main filename. Usually instance.mainfile
function SF.SerializeCode ( sources, mainfile )
	local rt = {source = {}}
	for filename, source in pairs( sources ) do
		rt.source[ filename ] = string.gsub( source, serialize_replace_regex, serialize_replace_tbl )
	end
	rt.mainfile = mainfile
	return rt
end

local deserialize_replace_regex = "[" .. string.char( 5 ) .. string.char( 4 ) .. "]"
local deserialize_replace_tbl = { [ string.char( 5 )[ 1 ] ] = "\n", [ string.char( 4 )[ 1 ] ] = '"' }
--- Deserializes an instance's code.
-- @return The table of filename = source entries
-- @return The main filename
function SF.DeserializeCode ( tbl )
	local sources = {}
	for filename, source in pairs(tbl.source) do
		sources[ filename ] = string.gsub( source, deserialize_replace_regex, deserialize_replace_tbl )
	end
	return sources, tbl.mainfile
end

-- ------------------------------------------------------------------------- --

if SERVER then
	util.AddNetworkString( "starfall_requpload" )
	util.AddNetworkString( "starfall_uploadlist")
	util.AddNetworkString( "starfall_requestfiles")
	util.AddNetworkString( "starfall_upload" )
	util.AddNetworkString( "starfall_addnotify" )
	util.AddNetworkString( "starfall_console_print" )
	
	local uploaddata = {}
	local codecache = {}

	-- Packet structure:
	-- 
	-- Initialize packet:
	--   Bit: False to cancel transfer
	--   String: Main filename
	-- Payload packets:
	--   Bit: End transmission. If true, no other data is included
	--   String: Filename. Multiple packets with the same filename are to be concactenated onto each other in the order they were sent
	--   String: File data

	--- Requests a player to send whatever code they have open in his/her editor to
	-- the server.
	-- @server
	-- @param ply Player to request code from
	-- @param callback Called when all of the code is recieved. Arguments are either the main filename and a table
	-- of filename->code pairs, or nil if the client couldn't handle the request (due to bad includes, etc)
	-- @return True if the code was requested, false if an incomplete request is still in progress for that player
	function SF.RequestCode ( ply, callback )
		if uploaddata[ply] then return false end

		net.Start( "starfall_requpload" )
		net.WriteEntity( ent )
		net.Send( ply )

		codecache[ply] = codecache[ply] or {}
		uploaddata[ ply ] = {
			files = {},
			mainfile = nil,
			needHeader = true,
			callback = callback,
		}
		return true
	end

	hook.Add( "PlayerDisconnected", "SF_requestcode_cleanup", function ( ply )
		uploaddata[ ply ] = nil
		codecache[ply] = nil
	end )

	function SF.AddNotify ( ply, msg, notifyType, duration, sound )

		-- If the first arg is a string, it can't be a player, so shift all values.
		if type( ply ) == "string" then
			ply, msg, notifyType, duration, sound = nil, ply, msg, notifyType, duration
		end

		if ply and not IsValid( ply ) then return end

		net.Start( "starfall_addnotify" )
		net.WriteString( msg )
		net.WriteUInt( notifyType, 8 or 0, 8 )
		net.WriteFloat( duration )
		net.WriteUInt( sound, 8 or 0, 8 )
		if ply then
			net.Send( ply )
		else
			net.Broadcast()
		end
	end

	function SF.Print ( ply, msg )
		if type( ply ) == "string" then
			ply, msg = nil, ply
		end

		net.Start( "starfall_console_print" )
		net.WriteString( msg )
		if ply then
			net.Send( ply )
		else
			net.Broadcast()
		end
	end


	--- Table for acceptable types to be spawned/created by SF.MakeSF.
	-- Only if an entity type matches a key in this table, will it be allowed to spawn via SF.MakeSF.
	--@key String - The string representing the ent, as used in ents.Create.
	--@value String - The 'common' name, for use in displaying to the user.
	--@server
	local acceptable_types = {
		[ "starfall_processor" ] = "Starfall Processor",
		[ "starfall_screen" ] = "Starfall Screen"
	}

	--- Function which clears uploaddata and errors
	-- Prevents 'locking' the user out from spawning if something erroneous occurs whilst MakeSF runs.
	-- NEVER CALL this unless inside MakeSF.
	--@param msg Message to error with.
	--@param ply Player that errored, so we can clear their uploaddata for them to try again. If ply is the err cause, function will skip uploaddata clearing.
	--@local
	local function errMaking ( msg, ply )
		if ply then
			uploaddata[ ply ] = nil
			SF.AddNotify( ply, "[ SPAWN ERROR ] " .. msg, NOTIFY_ERROR, 4, NOTIFYSOUND_ERROR1 )
		end

		error( msg )
	end

	--- Creates a SF of the given type.
	-- Used for starfall_processor & starfall_screen
	-- This contains code common to spawning both types of SF
	--@server
	--@param ply The player 'spawning' the entity, toolgun owner usually
	--@param typ The type of SF: "starfall_processor" or "starfall_screen". See 'acceptable_types'
	--@param trace The trace from the toolgun, used for placement and constraining.
	--@param model The model that the entity should be set to.
	--@return Entity - The Starfall entity, of type 'typ', as created by ents.Create.
	function SF.MakeSF ( ply, typ, trace, model )
		-- Sanity checks
		if not IsValid( ply ) then errMaking( "Invalid player during spawning" ) end

		if type( typ ) ~= "string" or typ == "" then
			errMaking( "Cannot make a Starfall of that type", ply )
		elseif not acceptable_types[ typ ] then
			errMaking( "Cannot make a Starfall of type: " .. typ, ply )
		end

		if not trace then errMaking( "No trace data for " .. acceptable_types[ typ ] .. " specified!", ply ) end

		if not model or model == "" then errMaking( "Cannot create a " .. acceptable_types[ typ ] .." without a model!", ply ) end

		-- CheckLimit throws its own error, so just return
		if not ply:CheckLimit( typ ) then return end

		local sf = ents.Create( typ )
		if not IsValid( sf ) then errMaking( "Error occurred with creating entity: " .. acceptable_types[ typ ], ply ) end

		local ang = trace.HitNormal:Angle()
		ang.pitch = ang.pitch + 90

		sf:SetAngles( ang )
		sf:SetModel( model )
		sf:Spawn()

		sf:SetPos( trace.HitPos - trace.HitNormal * sf:OBBMins().z )

		-- Lots of ownership stuff
		-- Old but still supported officially
		sf.owner = ply

		-- NPP / Other PP's hook onto this for ownership usually.
		ply:AddCleanup( typ, sf )

		ply:AddCount( typ, sf )

		-- Questionable use cases
		-- Based on: https://github.com/garrynewman/garrysmod/blob/master/garrysmod/lua/includes/extensions/entity.lua#L53
		sf:SetVar( "Player", ply )
		sf:SetVar( "Owner", ply )

		-- Directly set CPPI Owner incase PP doesn't hook onto any of the above.
		-- CPPI docs: http://ulyssesmod.net/archive/CPPI_v1-3.pdf
		if CPPI and sf.CPPISetOwner then
			sf:CPPISetOwner( ply )
		end

		local weld
		local tEnt = trace.Entity

		-- World fails the IsValid check.
		-- Normal ents, like props, will pass this. We definitely want to weld to those.
		if IsValid( tEnt ) then
			weld = constraint.Weld( sf, trace.Entity, 0, trace.PhysicsBone, 0, false, true )

		-- We're spawning on the world. Just freeze in place.
		else
			local phys = sf:GetPhysicsObject()
			if IsValid( phys ) then
				phys:EnableMotion( false )
			end
		end

		undo.Create( typ )
			undo.AddEntity( sf )

			if weld then
				undo.AddEntity( weld )
			end

			undo.SetPlayer( ply )
			undo.SetCustomUndoText( "Undone " .. tostring( acceptable_types[ typ ] ) .. ( sf.EntIndex and " [ " .. sf:EntIndex() .. " ]" or "" ) )
		undo.Finish()

		return sf
	end

	local function getCodeCache(ply, filename, hash, codeSize)
		local cacheEntry = codecache[ply][filename] or {}
		for k,v in pairs(cacheEntry) do
			if v.hash == hash and v.size == codeSize then
				return v
			end
		end
		return nil
	end

	local function addCodeCache(ply, filename, hash, codeSize)
		if not IsValid(ply) then
			return
		end
		if codecache[ply][filename] == nil then
			codecache[ply][filename] = {}
		end
		local cacheEntry = codecache[ply][filename]
		local cache = { filename = filename, hash = hash, size = codeSize, time = CurTime() }
		table.insert(cacheEntry, cache)
		return cache
	end

	local function sweepCodeCache()
		local expiryTime = math.min(SF.cacheExpiryTime:GetInt() * 60, 60)
		for ply, cachedFiles in pairs(codecache) do
			for fname, entries in pairs(cachedFiles) do
				for k, entry in pairs(entries) do
					if CurTime() - entry.time >= expiryTime then
						codecache[ply][fname][k] = nil
						--print("Removing expired cache entry: " .. fname .. ", hash: " .. entry.hash)
					end
				end
			end
		end
	end

	net.Receive( "starfall_upload", function ( len, ply )
		local updata = uploaddata[ ply ]
		if not updata then
			ErrorNoHalt( "SF: Player " .. ply:GetName() .. " tried to upload code without being requested (expect this message multiple times)\n" )
			return
		end

		local readType = net.ReadUInt(2)
		if readType == 0 then
			-- Start of file.
			local fname = net.ReadString()
			local hash = net.ReadString()
			local codeSize = net.ReadUInt(18)
			--print("Receiving file: " .. fname .. " (Hash: " .. hash .. ")")
			updata.files[fname] = ""
			addCodeCache(ply, fname, hash, codeSize)
		elseif readType == 1 then
			-- Chunk
			local fname = net.ReadString()
			local data = net.ReadString()
			updata.files[fname] = updata.files[fname] .. data
			--print("Received chunk for: " .. fname .. ", size: " .. #data .. " bytes")
		elseif readType == 2 then
			-- End of file
			local fname = net.ReadString()
			local hash = net.ReadString()
			local code = updata.files[fname]
			local cache = getCodeCache(ply, fname, hash, #code)
			cache.code = code
		elseif readType == 3 then
			-- End of list
			updata.callback( updata.mainfile, updata.files )
			uploaddata[ ply ] = nil
		else
			error("Unexpected read type: " .. tostring(readType))
		end

		-- Also cleanup cached entries older than 10 minutes, if they
		-- will be used again the time updates.
		if readType == 3 then
			sweepCodeCache()
		end

	end )

	net.Receive( "starfall_uploadlist", function(len, ply)

		local updata = uploaddata[ ply ]
		if not updata then
			ErrorNoHalt( "SF: Player " .. ply:GetName() .. " tried to upload code without being requested (expect this message multiple times)\n" )
			return
		end

		local missing = {}
		local mainfile = net.ReadString()
		local count = net.ReadUInt(16)

		updata.mainfile = mainfile

		-- Create a list of files we need from the client.
		for i = 1, count do
			local fname = net.ReadString()
			local hash = net.ReadString()
			local codeSize = net.ReadUInt(18)
			if cacheMissing == true then
				-- Entire cache missing, don't bother looking for individual files.
				table.insert(missing, { filename = fname, hash = hash, codeSize = codeSize })
				--print("File " .. fname .. " is missing in cache")
			else
				local cached = getCodeCache(ply, fname, hash, codeSize)
				if cached == nil then
					--print("No cache found for " .. fname)
					table.insert(missing, { filename = fname, hash = hash, codeSize = codeSize })
				else
					--print("Using cache for " .. fname)
					updata.files[ fname ] = cached.code
					cached.time = CurTime() -- Keep alive as long its in use.
				end
			end
		end

		if #missing > 0 then
			-- Request missing files.
			net.Start("starfall_requestfiles")
			net.WriteUInt(#missing, 16)
			for _,v in pairs(missing) do
				--print("Requesting missing file from client: " .. v.filename)
				net.WriteString(v.filename)
				net.WriteString(v.hash)
				net.WriteUInt(v.codeSize, 18)
			end
			net.Send(ply)
		else
			-- Everything was cached, we can directly invoke the callback.
			--print("Cache is up to date for entry: " .. mainfile)
			updata.callback( updata.mainfile, updata.files )
			uploaddata[ ply ] = nil
		end

	end)

else

	-- Send list of data.
	local currentlist = nil

	net.Receive( "starfall_requpload", function ( len )
		local ok, list = SF.Editor.BuildIncludesTable()
		if not ok then
			if list then
				SF.AddNotify( LocalPlayer(), list, NOTIFY_ERROR, 7, NOTIFYSOUND_ERROR1 )
			end
			currentlist = nil
			return
		else
			currentlist = list
		end

		--print("Server requested code upload, sending file index.")

		local fileCount = table.Count(currentlist.files)

		net.Start( "starfall_uploadlist" )
		net.WriteString(currentlist.mainfile)
		net.WriteUInt(fileCount, 16)
		for fname, code in pairs(currentlist.files) do
			net.WriteString(fname)
			net.WriteString(currentlist.hashes[fname])
			net.WriteUInt(#code, 18)
		end
		net.SendToServer()
	end)

	net.Receive( "starfall_requestfiles", function ( len )

		if currentlist == nil then
			ErrorNoHalt( "Server requested files before building the index." )
			return
		end

		--print("Received server request for files.")

		local requested = {}

		local fileCount = net.ReadUInt(16)
		for i = 1, fileCount do
			local fname = net.ReadString()
			local hash = net.ReadString()
			local codeSize = net.ReadUInt(18)
			table.insert(requested, { filename = fname, hash = hash, codeSize = codeSize })
		end

		for _,v in pairs(requested) do
			-- Chunk info
			--print("Sending file: " .. v.filename .. "(Hash: " .. v.hash .. ", size: " .. v.codeSize .. ")")

			net.Start("starfall_upload")
			net.WriteUInt(0, 2) -- Start of stream
			net.WriteString(v.filename)
			net.WriteString(v.hash)
			net.WriteUInt(v.codeSize, 18)
			net.SendToServer()

			-- Send all chunks.
			local codeData = currentlist.files[v.filename]
			local offset = 1
			repeat

				local data = codeData:sub( offset, offset + 50000 )

				--print("Sending chunk (" .. v.filename .. ") offset: " .. tostring(offset) .. ", len: " .. tostring(#data))

				net.Start( "starfall_upload" )
				net.WriteUInt(1, 2) -- Chunk piece.
				net.WriteString( v.filename )
				net.WriteString( data )
				net.SendToServer()

				offset = offset + #data
			until offset > #codeData

			net.Start( "starfall_upload" )
				net.WriteUInt(2, 2) -- End of file
				net.WriteString( v.filename )
				net.WriteString( v.hash )
			net.SendToServer()
		end

		net.Start( "starfall_upload" )
			net.WriteUInt(3, 2) -- List complete
		net.SendToServer()

		currentlist = nil

	end)

	local sounds = {
		[ NOTIFYSOUND_DRIP1 ] = "ambient/water/drip1.wav",
		[ NOTIFYSOUND_DRIP2 ] = "ambient/water/drip2.wav",
		[ NOTIFYSOUND_DRIP3 ] = "ambient/water/drip3.wav",
		[ NOTIFYSOUND_DRIP4 ] = "ambient/water/drip4.wav",
		[ NOTIFYSOUND_DRIP5 ] = "ambient/water/drip5.wav",
		[ NOTIFYSOUND_ERROR1 ] = "buttons/button10.wav",
		[ NOTIFYSOUND_CONFIRM1 ] = "buttons/button3.wav",
		[ NOTIFYSOUND_CONFIRM2 ] = "buttons/button14.wav",
		[ NOTIFYSOUND_CONFIRM3 ] = "buttons/button15.wav",
		[ NOTIFYSOUND_CONFIRM4 ] = "buttons/button17.wav"
	}

	function SF.AddNotify ( ply, msg, type, duration, sound )
		if not IsValid( ply ) then return end

		if ply ~= LocalPlayer() then
			return
		end

		GAMEMODE:AddNotify( msg, type, duration )

		if sound and sounds[ sound ] then
			surface.PlaySound( sounds[ sound ] )
		end
	end

	net.Receive( "starfall_addnotify", function ()
		SF.AddNotify( LocalPlayer(), net.ReadString(), net.ReadUInt( 8 ), net.ReadFloat(), net.ReadUInt( 8 ) )
	end )

	net.Receive( "starfall_console_print", function ()
		print( net.ReadString() )
	end )
end

-- ------------------------------------------------------------------------- --

if SERVER then
	util.AddNetworkString( "starfall_client_lib_data" )

	hook.Add( "PlayerAuthed", "starfall_send_lib_data", function ( ply )
		net.Start( "starfall_client_lib_data" )
		net.Send( ply )
	end )

	function SF.Libraries.LoadAll ()
		MsgN( "-SF - Loading Libraries" )

		local l
		MsgN( "- Loading shared libraries" )
		l = file.Find( "starfall/libs_sh/*.lua", "LUA" )
		for _, filename in pairs( l ) do
			print( "-  Loading " .. filename )
			include( "starfall/libs_sh/" .. filename )
			AddCSLuaFile( "starfall/libs_sh/" .. filename )
		end
		MsgN( "- End loading shared libraries" )

		MsgN( "- Loading SF server-side libraries" )
		l = file.Find( "starfall/libs_sv/*.lua", "LUA" )
		for _, filename in pairs( l ) do
			print( "-  Loading " .. filename )
			include( "starfall/libs_sv/" .. filename )
		end
		MsgN( "- End loading server-side libraries" )

		MsgN( "- Adding client-side libraries to send list" )
		l = file.Find( "starfall/libs_cl/*.lua", "LUA" )
		for _, filename in pairs( l ) do
			print( "-  Adding " .. filename )
			AddCSLuaFile( "starfall/libs_cl/" .. filename )
		end
		MsgN( "- End loading client-side libraries" )

		MsgN( "-End Loading SF Libraries" )

		hook.Run( "sf_libs_loaded" )
		SF.Libraries.CallHook( "postload" )
	end

	SF.Libraries.LoadAll()
else
	net.Receive( "starfall_client_lib_data", function ()
		SF.Libraries.LoadAll()
	end )

	function SF.Libraries.LoadAll ()
		MsgN( "-SF - Loading Libraries" )

		local l
		MsgN( "- Loading shared libraries" )
		l = file.Find( "starfall/libs_sh/*.lua", "LUA" )
		for _, filename in pairs( l ) do
			print( "-  Loading " .. filename )
			include( "starfall/libs_sh/" .. filename )
		end
		MsgN( "- End loading shared libraries" )

		MsgN( "- Loading client-side libraries" )
		l = file.Find( "starfall/libs_cl/*.lua", "LUA" )
		for _, filename in pairs( l ) do
			print( "-  Loading " .. filename )
			include( "starfall/libs_cl/" .. filename )
		end
		MsgN( "- End loading client-side libraries" )

		MsgN( "-End Loading SF Libraries" )

		hook.Run( "sf_libs_loaded" )
		SF.Libraries.CallHook( "postload" )
	end
end
