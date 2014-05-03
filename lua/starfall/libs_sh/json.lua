--- JSON Library

--- JSON library. Encodes/Decodes Tables to/from Strings
-- @shared
local json_library, _ = SF.Libraries.Register( "json" )

function json_library.encode( table )
	if not table then return end

	return util.TableToJSON( table )
end

function json_library.decode( string )
	if not string then return end	

	return util.JSONToTable( string )	
end