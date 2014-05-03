--- Compression Library

--- Compression library. Compresses/Decompresses Strings
-- @shared
local compress_library, _ = SF.Libraries.Register( "compress" )

function compress_library.compress( string )
	if not string then return end

	return util.Compress( string )
end

function compress_library.decompress( string )
	if not string then return end	

	return util.Decompress( string )	
end