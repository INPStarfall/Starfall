-------------------------------------------------------------------------------
-- Builtins.
-- Functions built-in to the default environment
-------------------------------------------------------------------------------

local dgetmeta = debug.getmetatable

--- Built in values. These don't need to be loaded; they are in the default environment.
-- @name builtin
-- @shared
-- @class library
-- @libtbl SF.DefaultEnvironment

-- ------------------------- Lua Ports ------------------------- --
-- This part is messy because of LuaDoc stuff.

local function pascalToCamel ( t, r )
	local r = r or {}
	for k, v in pairs( t ) do
		k = k:gsub( "^%l", string.lower )
		r[ k ] = v
	end
	return r
end

--- Same as Lua's tostring
-- @name SF.DefaultEnvironment.tostring
-- @class function
-- @param obj
-- @return obj as string
SF.DefaultEnvironment.tostring = tostring
--- Same as Lua's tonumber
-- @name SF.DefaultEnvironment.tonumber
-- @class function
-- @param obj
-- @return obj as number
SF.DefaultEnvironment.tonumber = tonumber

--- Same as Lua's ipairs
-- @name SF.DefaultEnvironment.ipairs
-- @class function
-- @param tbl Table to iterate over
-- @return Iterator function
-- @return Table tbl
-- @return 0 as current index
SF.DefaultEnvironment.ipairs = ipairs

--- Same as Lua's pairs
-- @name SF.DefaultEnvironment.pairs
-- @class function
-- @param tbl Table to iterate over
-- @return Iterator function
-- @return Table tbl
-- @return nil as current index
SF.DefaultEnvironment.pairs = pairs

--- Same as Lua's type
-- @name SF.DefaultEnvironment.type
-- @class function
-- @param obj Object to get type of
-- @return The name of the object's type.
SF.DefaultEnvironment.type = function ( obj )
	local tp = getmetatable( obj )
	return type( tp ) == "string" and tp or type( obj )
end
--- Same as Lua's next
-- @name SF.DefaultEnvironment.next
-- @class function
-- @param tbl Table to get the next key-value pair of
-- @param k Previous key (can be nil)
-- @return Key or nil
-- @return Value or nil
SF.DefaultEnvironment.next = next
--- Same as Lua's assert.
-- @name SF.DefaultEnvironment.assert
-- @class function
-- @param condition
-- @param msg
SF.DefaultEnvironment.assert = function ( condition, msg ) if not condition then SF.throw( msg or "assertion failed!", 2 ) end end
--- Same as Lua's unpack
-- @name SF.DefaultEnvironment.unpack
-- @class function
-- @param tbl
-- @return Elements of tbl
SF.DefaultEnvironment.unpack = unpack

--- Same as Lua's setmetatable. Doesn't work on most internal metatables
-- @name SF.DefaultEnvironment.setmetatable
-- @class function
-- @param tbl The table to set the metatable of
-- @param meta The metatable to use
-- @return tbl with metatable set to meta
SF.DefaultEnvironment.setmetatable = setmetatable

--- Same as Lua's getmetatable. Doesn't work on most internal metatables
-- @param tbl Table to get metatable of
-- @return The metatable of tbl
SF.DefaultEnvironment.getmetatable = function( tbl )
	SF.CheckType( tbl, "table" )
	return getmetatable( tbl )
end

--- Constant that denotes whether the code is executed on the client
-- @name SF.DefaultEnvironment.CLIENT
-- @class field
SF.DefaultEnvironment.CLIENT = CLIENT
--- Constant that denotes whether the code is executed on the server
-- @name SF.DefaultEnvironment.SERVER
-- @class field
SF.DefaultEnvironment.SERVER = SERVER

--- Returns the current count for this Think's CPU Time.
-- This value increases as more executions are done, may not be exactly as you want.
-- If used on screens, will show 0 if only rendering is done. Operations must be done in the Think loop for them to be counted.
-- @return Current quota used this Think
function SF.DefaultEnvironment.quotaUsed ()
	return SF.instance.cpuTime.buffer[ SF.instance.cpuTime.bufferI ]
end

--- Gets the Average CPU Time in the buffer
-- @return Average CPU Time of the buffer.
function SF.DefaultEnvironment.quotaAverage ()
	return SF.instance.cpuTime:getBufferAverage()
end

--- Gets the CPU Time max.
-- CPU Time is stored in a buffer of N elements, if the average of this exceeds quotaMax, the chip will error.
-- @return Max SysTime allowed to take for execution of the chip in a Think.
function SF.DefaultEnvironment.quotaMax ()
	return SF.instance.context.cpuTime.getMax()
end

-- The below modules have the Gmod functions removed (the ones that begin with a capital letter),
-- as requested by Divran

-- Filters Gmod Lua files based on Garry's naming convention.
local function filterGmodLua ( lib, original, gm )
	original = original or {}
	gm = gm or {}
	for name, func in pairs( lib ) do
		if name:match( "^[A-Z]" ) then
			gm[ name ] = func
		else
			original[ name ] = func
		end
	end
	return original, gm
end

-- String library
local string_methods, string_metatable = SF.Typedef( "Library: string" )
filterGmodLua( string, string_methods )
string_metatable.__newindex = function () end

--- Lua's (not GLua's) string library
-- @name SF.DefaultEnvironment.string
-- @class table
SF.DefaultEnvironment.string = setmetatable( {}, string_metatable )

-- Math library
local math_methods, math_metatable = SF.Typedef( "Library: math" )
filterGmodLua( math, math_methods )
math_metatable.__newindex = function () end
math_methods.clamp = math.Clamp
math_methods.round = math.Round
math_methods.randfloat = math.Rand
math_methods.calcBSplineN = nil

--- Lua's ( not GLua's ) math library, plus clamp, round, and randfloat
-- @name SF.DefaultEnvironment.math
-- @class table
SF.DefaultEnvironment.math = setmetatable( {}, math_metatable )

local os_methods, os_metatable = SF.Typedef( "Library: os" )
filterGmodLua( os, os_methods )
os_metatable.__newindex = function () end

--- GLua's os library. http://wiki.garrysmod.com/page/Category:os
-- @name SF.DefaultEnvironment.os
-- @class table
SF.DefaultEnvironment.os = setmetatable( {}, os_metatable )

local table_methods, table_metatable = SF.Typedef( "Library: table" )
filterGmodLua( table,table_methods )
table_metatable.__newindex = function () end

--- Lua's (not GLua's) table library
-- @name SF.DefaultEnvironment.table
-- @class table
SF.DefaultEnvironment.table = setmetatable( {}, table_metatable )

-- ------------------------- Functions ------------------------- --

--- Gets a list of all libraries
-- @return Table containing the names of each available library
function SF.DefaultEnvironment.getLibraries ()
	local ret = {}
	for k,v in pairs( SF.Libraries.libraries ) do
		ret[ #ret + 1 ] = k
	end
	return ret
end

--- Local type checking function for the iter function.
-- @param typ The Starfall Library or Type to check.
-- @throws Error should the input typ not be a valid Starfall Library or Type.
local function iterCheckType ( typ )
    local meta = dgetmeta( typ )
    if not (
    meta and meta.__metatable
            and type( meta.__metatable ) == "string" and SF.GetTypeDef( meta.__metatable )
            and meta.__realType and meta.__realType == SF.GetTypeDef( meta.__metatable ).__realType
    ) then
        SF.throw( "iter: Invalid Library or Type", 3 )
    end
end

--- Used the same as Lua's pairs but iterates over the given library's or type's default fields
-- @param typ The Starfall Library or Type to iterate over
-- @usage
-- \-- Default Environment, would also work with getfenv()
--
-- for k, v in iter( _G ) do
-- \   -- CODE
-- end
--
-- \-- or for example:
--
-- for k, v in iter( render ) do
-- \   -- CODE
-- end
function SF.DefaultEnvironment.iter ( typ )
	SF.CheckType( typ, "table" )

	iterCheckType( typ )

	local nxt = function ( t, index )
		iterCheckType( t )
		local meta = dgetmeta( t )
		return next( meta.__methods, index )
	end

	return nxt, typ, nil
end


if SERVER then
	--- Prints a message to the player's chat.
	-- @shared
	-- @param ... Values to print
	function SF.DefaultEnvironment.print ( ... )
		local str = ""
		local tbl = { ... }
		for i = 1, #tbl do str = str .. tostring( tbl[ i ] ) .. ( i == #tbl and "" or "\t" ) end
		SF.instance.player:ChatPrint( str )
	end
else
	-- Prints a message to the player's chat.
	function SF.DefaultEnvironment.print ( ... )
		if SF.instance.player ~= LocalPlayer() then return end
		local str = ""
		local tbl = { ... }
		for i = 1 , #tbl do str = str .. tostring( tbl[ i ] ) .. ( i == #tbl and "" or "\t" ) end
		LocalPlayer():ChatPrint( str )
	end
end

local function printTableX ( target, t, indent, alreadyprinted )
	for k,v in SF.DefaultEnvironment.pairs( t ) do
		if SF.GetType( v ) == "table" and not alreadyprinted[ v ] then
			alreadyprinted[ v ] = true
			target:ChatPrint( string.rep( "\t", indent ) .. tostring( k ) .. ":" )
			printTableX( target, v, indent + 1, alreadyprinted )
		else
			target:ChatPrint( string.rep( "\t", indent ) .. tostring( k ) .. "\t=\t" .. tostring( v ) )
		end
	end
end

--- Prints a table to player's chat
-- @param tbl Table to print
function SF.DefaultEnvironment.printTable ( tbl )
	if CLIENT and SF.instance.player ~= LocalPlayer() then return end
	SF.CheckType( tbl, "table" )

	printTableX( ( SERVER and SF.instance.player or LocalPlayer() ), tbl, 0, { t = true } )
end

local function parseInclude ( file )
	if file:find( "%*%*" ) ~= nil then
		if file:find( "%*%*.*/" ) ~= nil then
			SF.throw( file:match( "(%*%*[^/]*[/*^/*]*)$" ) .. " is invalid, did you mean '" .. file:match( "(%*%*.*[/*.*]*)$" ):gsub( "%*%*", "%*" ) .. "'?", 2 )
		end
		file = file:gsub( "%*%*", "[^/*/*]" )
	else
		file = file:gsub( "%*", "[^/]*" ) .. "$"
	end

	return file
end

local function sfRequire ( file )
	local loaded = SF.instance.data.reqloaded
	if not loaded then
		loaded = {}
		SF.instance.data.reqloaded = loaded
	end

	if loaded[ file ] then
		return loaded[ file ]
	else
		local func = SF.instance.scripts[ file ]
		if not func then SF.throw( "Can't find file '" .. file .. "' ( Did you forget to --@include it? )", 2 ) end
		loaded[ file ] = func() or true
		return loaded[ file ]
	end
end

--- Runs an included script and caches the result.
-- Works pretty much like standard Lua require()
-- @param file The file to include. Make sure to --@include it
-- @param loadpriority Table of files that should be loaded before any others in the directory, only used if more than one file is specified.
-- @return Return value of the script
function SF.DefaultEnvironment.require ( file, loadpriority )
	SF.CheckType( file, "string" )
	if loadpriority ~= nil then SF.CheckType( loadpriority, "table" ) end

	file = parseInclude( file )

	local parsedLoadPriority = {}

	for _, fileName in pairs( loadpriority or {} ) do
		parsedLoadPriority.insert( parseInclude( fileName ) )
	end

	local returns = {}

	for _, pattern in pairs( parsedLoadPriority or {} ) do
		for fileName, _ in pairs( SF.instance.scripts ) do
			if fileName:find( pattern ) ~= nil and not returns[ fileName ] then
				returns[ fileName ] = sfRequire( fileName )
			end
		end
	end

	for fileName, _ in pairs( SF.instance.scripts ) do
		if fileName:find( file ) ~= nil and not returns[ fileName ] then
			returns[ fileName ] = sfRequire( fileName )
		end
	end

	return returns
end

local function sfDofile ( file )
	SF.CheckType( file, "string" )
	local func = SF.instance.scripts[ file ]
	if not func then SF.throw( "Can't find file '" .. file .. "' ( Did you forget to --@include it? )", 2 ) end
	return func()
end

--- Runs an included script, but does not cache the result.
-- Pretty much like standard Lua dofile()
-- @param file The file(s) to include. Make sure to --@include it
-- @param loadpriority Table of files that should be loaded before any others in the directory, only used if more than one file is specified.
-- @return Return value of the script
function SF.DefaultEnvironment.dofile ( file, loadpriority )
	SF.CheckType( file, "string" )
	if loadpriority ~= nil then SF.CheckType( loadpriority, "table" ) end

	file = parseInclude( file )

	local parsedLoadPriority = {}

	for _, fileName in pairs( loadpriority or {} ) do
		parsedLoadPriority.insert( parseInclude( fileName ) )
	end

	local returns = {}

	for _, pattern in pairs( parsedLoadPriority or {} ) do
		for fileName, _ in pairs( SF.instance.scripts ) do
			if fileName:find( pattern ) ~= nil and not returns[ fileName ] then
				returns[ fileName ] = sfDofile( fileName )
			end
		end
	end

	for fileName, _ in pairs( SF.instance.scripts ) do
		if fileName:find( file ) ~= nil and not returns[ fileName ] then
			returns[ fileName ] = sfDofile( fileName )
		end
	end

	return returns
end

--- GLua's loadstring
-- Works like loadstring, except that it executes by default in the main environment
-- @param str String to execute
-- @return Function of str
function SF.DefaultEnvironment.loadstring ( str )
	local func = CompileString( str, "SF: " .. tostring( SF.instance.env ), false )
	
	-- CompileString returns an error as a string, better check before setfenv
	if type( func ) == "function" then
		return setfenv( func, SF.instance.env )
	end
	
	return func
end

local SF_Methods = {}

--- Lua's setfenv
-- Works like setfenv, but is restricted on functions
-- @param func Function to change environment of
-- @param tbl New environment
-- @return func with environment set to tbl
function SF.DefaultEnvironment.setfenv ( func, tbl )
	if type( func ) ~= "function" then SF.throw( "Main Thread is protected!", 2 ) end
	if SF_Methods[ func ] then SF.throw( "SF methods are protected.", 2 ) end
	return setfenv( func, tbl )
end

--- Simple version of Lua's getfenv
-- Returns the current environment
-- @return Current environment
function SF.DefaultEnvironment.getfenv ()
	return getfenv()
end

--- Try to execute a function and catch possible exceptions
-- Similar to xpcall, but a bit more in-depth
-- @param func Function to execute
-- @param catch Function to execute in case func fails
function SF.DefaultEnvironment.try ( func, catch )
	local ok, err = pcall( func )
	if ok then return end

	if type( err ) == "table" then
		if err.uncatchable then
			error( err )
		end
	end
	catch( err )
end

--- Throws an exception
-- @param msg Message
-- @param level Which level in the stacktrace to blame. Defaults to one of invalid
-- @param uncatchable Makes this exception uncatchable
function SF.DefaultEnvironment.throw ( msg, level, uncatchable )
	local info = debug.getinfo( 1 + ( level or 1 ), "Sl" )
	local filename = info.short_src:match( "^SF:(.*)$" )
	if not filename then
		info = debug.getinfo( 2, "Sl" )
		filename = info.short_src:match( "^SF:(.*)$" )
	end
	local err = {
		uncatchable = false,
		file = filename,
		line = info.currentline,
		message = msg,
		uncatchable = uncatchable
	}
	error( err )
end

--- Throws a raw exception.
-- @param msg Exception message
function SF.DefaultEnvironment.error ( msg )
	error( msg or "an unspecified error occured", 2 )
end

--- Execute a console command
-- @param cmd Command to execute
function SF.DefaultEnvironment.concmd ( cmd )
	if CLIENT and SF.instance.player ~= LocalPlayer() then return end -- only execute on owner of screen
	SF.CheckType( cmd, "string" )
	SF.instance.player:ConCommand( cmd )
end

-- ------------------------- Restrictions ------------------------- --
-- Restricts access to builtin type's metatables

local _R = debug.getregistry()
local function restrict( instance, hook, name, ok, err )
	_R.Vector.__metatable = "Vector"
	_R.Angle.__metatable = "Angle"
	_R.VMatrix.__metatable = "VMatrix"
end

local function unrestrict( instance, hook, name, ok, err )
	_R.Vector.__metatable = nil
	_R.Angle.__metatable = nil
	_R.VMatrix.__metatable = nil
end

SF.Libraries.AddHook( "prepare", restrict )
SF.Libraries.AddHook( "cleanup", unrestrict )

-- Creates a list of all the methods used in SF to blacklist in setfenv
SF.Libraries.AddHook( "postload", function ( ... ) 
	for _, tbl in pairs( SF.Types ) do
		for _, method in pairs( tbl.__methods ) do
			if type( method ) == "function" then
				SF_Methods[ method ] = true
			end
		end
	end
end )

-- ------------------------- Hook Documentation ------------------------- --

--- Think hook. Called once per game tick
-- @name think
-- @class hook
-- @shared
