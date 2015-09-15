-------------------------------------------------------------------------------
-- File functions
-------------------------------------------------------------------------------

--- File functions. Allows modification of files.
-- @shared
local file_library, _ = SF.Libraries.Register( "file" )

file.CreateDir( "sf_filedata/" )

--- Reads a file from path
-- @param path Filepath relative to data/sf_filedata/. Cannot contain '..'
-- @return Contents, or nil if error
-- @return Error message if applicable
function file_library.read ( path )
	if not SF.Permissions.check( SF.instance.player, "file.read", path ) then SF.throw( "Insufficient permissions", 2 ) end
	SF.CheckType( path, "string" )
	if path:find( "..", 1, true ) then SF.throw( "path contains '..'", 2 ) return end
	local contents = file.Read( "sf_filedata/" .. path, "DATA" )
	if contents then return contents else SF.throw( "file not found", 2 ) return end
end

--- Writes to a file
-- @param path Filepath relative to data/sf_filedata/. Cannot contain '..'
-- @return True if OK, nil if error
-- @return Error message if applicable
function file_library.write ( path, data )
	if not SF.Permissions.check( SF.instance.player, "file.write", path ) then SF.throw( "Insufficient permissions", 2 ) end
	SF.CheckType( path, "string" )
	SF.CheckType( data, "string" )
	if path:find( "..", 1, true ) then SF.throw( "path contains '..'", 2 ) return end
	file.Write( "sf_filedata/" .. path, data )
	return true
end

--- Appends a string to the end of a file
-- @param path Filepath relative to data/sf_filedata/. Cannot contain '..'
-- @param data String that will be appended to the file.
-- @return Error message if applicable
function file_library.append ( path, data )
	if not SF.Permissions.check( SF.instance.player, "file.write", path ) then SF.throw( "Insufficient permissions", 2 ) end
	SF.CheckType( path, "string" )
	SF.CheckType( data, "string" )
	if path:find( "..", 1, true ) then SF.throw( "path contains '..'", 2 ) return end
	file.Append( "sf_filedata/" .. path, data )
	return true
end

--- Checks if a file exists
-- @param path Filepath relative to data/sf_filedata/. Cannot contain '..'
-- @return True if exists, false if not, nil if error
-- @return Error message if applicable
function file_library.exists ( path )
	if not SF.Permissions.check( SF.instance.player, "file.exists", path ) then SF.throw( "Insufficient permissions", 2 ) end
	SF.CheckType( path, "string" )
	if path:find( "..", 1, true ) then SF.throw( "path contains '..'", 2 ) return end
	return file.Exists( "sf_filedata/" .. path, "DATA" )
end

--- Deletes a file
-- @param path Filepath relative to data/sf_filedata/. Cannot contain '..'
-- @return True if successful, nil if error
-- @return Error message if applicable
function file_library.delete ( path )
	if not SF.Permissions.check( SF.instance.player, "file.write", path ) then SF.throw( "Insufficient permissions", 2 ) end
	SF.CheckType( path, "string" )
	if path:find( "..", 1, true ) then SF.throw( "path contains '..'", 2 ) return end
	if not file.Exists( "sf_filedata/" .. path, "DATA" ) then SF.throw( "file not found", 2 ) return end
	file.Delete( path )
	return true
end

--- Creates a directory
-- @param path Filepath relative to data/sf_filedata/. Cannot contain '..'
function file_library.createDir ( path )
	if not SF.Permissions.check( SF.instance.player, "file.write", path ) then SF.throw( "Insufficient permissions", 2 ) end
	SF.CheckType( path, "string" )
	if path:find( "..", 1, true ) then SF.throw( "path contains '..'", 2 ) return end
	file.CreateDir( "sf_filedata/" .. path )
end
