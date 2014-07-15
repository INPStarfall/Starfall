-- copies examples folder from addon to data folder

local function moveFolder( path )
	file.CreateDir( path )
	local files, directories = file.Find( "data/" .. path .. "*", "GAME" )
	for _, name in pairs( files ) do
		file.Write( path .. name, file.Read( "data/" .. path .. name, "GAME" ))
	end
	for _, name in pairs( directories ) do
		moveFolder( path .. name .. "/" )
	end
end


if not ConVarExists( "sf_examples_copied" ) and file.IsDir( "data/starfall/examples", "GAME" ) and not file.IsDir( "starfall/examples", "DATA" ) then
	CreateClientConVar( "sf_examples_copied", 1, true, false ) -- Creates Convar to prevent repeated copying
	if not file.IsDir( "starfall", "DATA" ) then
		file.CreateDir( "starfall" )
	end
	moveFolder( "starfall/examples/" )
end
