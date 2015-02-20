-------------------------------------------------------------------------------
-- SF Preprocessor.
-- Processes code for compile time directives.
-------------------------------------------------------------------------------

-- TODO: Make an @include-only parser

SF.Preprocessor = {}
SF.Preprocessor.directives = {}

--- Sets a global preprocessor directive.
-- @param directive The directive to set.
-- @param func The callback. Takes the directive arguments, the file name, instance.ppdata and the instance
function SF.Preprocessor.SetGlobalDirective ( directive, func )
	SF.Preprocessor.directives[ directive ] = func
end

local function FindComments ( line )
	local ret, count, pos, found = {}, 0, 1
	repeat
		found = line:find( '["%-%[%]]', pos )
		if found then -- We found something
			local oldpos = pos
			
			local char = line:sub( found, found )
			if char == "-" then
				if line:sub( found, found + 1 ) == "--" then
					-- Comment beginning
					if line:sub( found, found + 3 ) == "--[[" then
						-- Block Comment beginning
						count = count + 1
						ret[ count ] = { type = "start", pos = found }
						pos = found + 4
					else
						-- Line comment beginning
						count = count + 1
						ret[ count ] = { type = "line", pos = found }
						pos = found + 2
					end
				else
					pos = found + 1
				end
			elseif char == "[" then
				local level = line:sub( found + 1 ):match( "^(=*)" )
				if level then
					level = string.len(level)
				else
					level = 0
				end
				
				if line:sub( found + level + 1, found + level + 1 ) == "[" then
					-- Block string start
					count = count + 1
					ret[ count ] = { type = "stringblock", pos = found, level = level }
					pos = found + level + 2
				else
					pos = found + 1
				end
			elseif char == "]" then
				local level = line:sub( found + 1 ):match( "^(=*)" )
				if level then level = string.len( level ) else level = 0 end
				
				if line:sub( found + level + 1, found + level + 1 ) == "]" then
					-- Ending
					count = count + 1
					ret[ count ] = { type = "end", pos = found, level = level }
					pos = found + level + 2
				else
					pos = found + 1
				end
			elseif char == "\"" then
				if line:sub( found - 1, found - 1 ) == "\\" and line:sub( found - 2, found - 1 ) ~= "\\\\" then
					-- Escaped character
					pos = found + 1
				else
					-- String
					count = count + 1
					ret[ count ] = { type = "string", pos = found }
					pos = found + 1
				end
			end
			
			if oldpos == pos then error( "Regex found something, but nothing handled it" ) end
		end
	until not found
	return ret, count
end

--- Parses a source file for directives.
-- @param filename The file name of the source code
-- @param source The source code to parse.
local function parseDirectives ( filename, source )
	local ending
	local endingLevel

	local directives = {}

	local str = source
	while str ~= "" do
		local line
		line, str = string.match( str, "^([^\n]*)\n?(.*)$" )

		for _,comment in ipairs( FindComments( line ) ) do
			if ending then
				if comment.type == ending then
					if endingLevel then
						if comment.level and comment.level == endingLevel then
							ending = nil
							endingLevel = nil
						end
					else
						ending = nil
					end
				end
			elseif comment.type == "start" then
				ending = "end"
			elseif comment.type == "string" then
				ending = "string"
			elseif comment.type == "stringblock" then
				ending = "end"
				endingLevel = comment.level
			elseif comment.type == "line" then
				local directive, args = string.match( line, "--@([^ ]+)%s*(.*)$" )
				if directive then
					if not directives[ directive ] then directives[ directive ] = {} end
					table.insert( directives[ directive ], args )
				end
			end
		end

		if ending == "newline" then ending = nil end
	end
	return directives
end

--- Parses a source file for directives
-- @param filename The file name of the source code.
-- @param source The source code to parse.
-- @param preprocs The preprocessors to search for, can be a string for one, a table for multiple, and nil for all
-- @return Table of preprocs and their args
function SF.Preprocessor.GetDirectives ( filename, source, preprocs )
	local parsedDirectives = parseDirectives( filename, source )

	local preprocs_type = type( preprocs )
	if preprocs_type == "string" then --1 specified preproc
		return parsedDirectives[ preprocs ]
	elseif preprocs_type == "table" then --Table of specified preprocs
		local ret = {}
		for _, preproc in pairs( preprocs ) do
			ret[ preproc ] = parsedDirectives[ preproc ]
		end
		return ret
	elseif preprocs == nil then --All preprocs in the file
		return parsedDirectives
	end
end

--- Parses a source file for directives
-- @param filename The file name of the source code.
-- @param source The source code to parse.
-- @param directives A table of additional directives to use.
-- @param data The data table passed to the directives.
-- @param instance The instance
-- @param preprocs The preprocessors to search for, can be a table for multiple, and nil for all
-- @return Table of preprocs and their args
function SF.Preprocessor.ParseDirectives ( filename, source, directives, data, instance, preprocs )
	local parsedDirectives = SF.Preprocessor.GetDirectives( filename, source )

	local ok, err = true, {}

	if preprocs then
		local _parsed = {}
		for _, preproc in pairs( preprocs ) do
			_parsed[ preproc ] = parsedDirectives[ preproc ]
		end
		parsedDirectives = _parsed
	end

	for preproc, v in pairs( parsedDirectives or {} ) do
		for _, args in pairs( v ) do
			local func = directives[ preproc ] or SF.Preprocessor.directives[ preproc ]
			if func then
				local _ok, _err = func( args, filename, data, instance )
				if _ok == false then
					ok = false
					err[ preproc ] = _err
				end
			end
		end
	end

	return ok, err
end

local function directive_include ( args, filename, data )
	if CLIENT and args then
		if not data.includes then data.includes = {} end
		if not data.includes[ filename ] then data.includes[ filename ] = {} end

		local incl = data.includes[ filename ]

		if args:find( "%*" ) == nil then
			incl[ #incl + 1 ] = args
			return
		end

		if args:find( "%*%*" ) ~= nil then
			if args:find( "%*%*.*/" ) ~= nil then
				return false, args:match( "(%*%*.*)$" ) .. " is invalid, did you mean '" .. args:match( "(%*%*.*.*)$" ):gsub( "%*%*", "%*" ) .. "'?"
			end
			--Include recursively
			args = args:gsub( "%*%*", "*" )
			local function find ( search )
				local files, dirs = file.Find( "starfall/" .. search, "DATA" )
				for _, file in pairs( files ) do
					incl[ #incl + 1 ] = search:match( "(.*/).*$" ) .. file
				end

				for _, dir in pairs( dirs ) do
					find( search:match( "(.*/)[.*]$" ) .. dir .. "/*" )
				end
			end
			find( args )
		else
			local smashedWords = {}

			local i = 1

			for word in args:gmatch( "([^/]*)" ) do
				if word ~= "" then
					smashedWords[ i ] = ( smashedWords[ i ] and smashedWords[ i ] .. "/" .. word ) or word
					if word:find( "*" ) ~= nil then
						i = i + 1
					end
				end
			end

			local function find ( level, search )
				local files, dirs = file.Find( "starfall/" .. search, "DATA" )
				if level < #smashedWords then --It's a directory
					for _, dir in pairs( dirs ) do
						find( level + 1, ( search:match( "(.*/)[.*]$" ) or "" ) .. dir .. "/" .. smashedWords[ level + 1 ] )
					end
				else --It's a file
					for _, file in pairs( files ) do
						incl[ #incl + 1 ] = ( search:match( "(.*/).*$" ) or "" ) .. file
					end
				end
			end
			find( 1, smashedWords[ 1 ] )
		end
	end
end
SF.Preprocessor.SetGlobalDirective( "include", directive_include )

local function directive_name( args, filename, data )
	if not data.scriptnames then data.scriptnames = {} end
	data.scriptnames[ filename ] = args
end
SF.Preprocessor.SetGlobalDirective( "name", directive_name )

local function directive_sharedscreen( args, filename, data )
	if not data.sharedscreen then
		data.sharedscreen = true
	end
end
SF.Preprocessor.SetGlobalDirective( "sharedscreen", directive_sharedscreen )

local function directive_model( args, filename, data )
	if not data.models then data.models = {} end
	data.models[ filename ] = args
end
SF.Preprocessor.SetGlobalDirective( "model", directive_model )

--- Mark a file to be included in the upload.
-- This is required to use the file in require() and dofile()
-- @name include
-- @class directive
-- @param path Path to the file
-- @usage
-- \--@include lib/**.txt
-- --** includes files recursivley
-- \--@include lib/*/init.txt
-- --* is treated as a wildcard that only applies to the directory that it is in
-- \--@include lib/afile.txt
-- --No *'s are treated like exact paths
-- 
-- require( "lib/someLibrary.txt" )
-- -- CODE

--- Set the name of the script.
-- This will become the name of the tab and will show on the overlay of the processor
-- @name name
-- @class directive
-- @param name Name of the script
-- @usage
-- \--@name Awesome script
-- -- CODE

--- For screens, make the script run on the server, as well.
-- You can use "if SERVER" and "if CLIENT" to determine if the script is currently being run on the server or the client, respectively.
-- @name sharedscreen
-- @class directive
--@usage
-- \--@sharedscreen
--
-- if SERVER then
-- \	-- Do important calculations
-- \	-- Send net message
-- else
-- \	-- Display result of important calculations
-- end

--- Set the model of the processor entity.
-- This does not set the model of the screen entity
-- @name model
-- @class directive
-- @param model String of the model
-- @usage
-- \--@model models/props_junk/watermelon01.mdl
-- -- CODE
