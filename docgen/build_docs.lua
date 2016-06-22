
setfenv = setfenv or function ( fn, env )
	local i = 1
	while true do
		local name = debug.getupvalue( fn, i )
		if name == "_ENV" then
			debug.upvaluejoin( fn, i, function ()
				return env
			end, 1 )
			break
		elseif not name then
			break
		end

		i = i + 1
	end

	return fn
end

getfenv = getfenv or function ( fn )
	local i = 1
	while true do
		local name, val = debug.getupvalue( fn, i )
		if name == "_ENV" then
			return val
		elseif not name then
			break
		end
		i = i + 1
	end
end

string.gfind = string.gfind or string.gmatch

table.getn = table.getn or function ( t ) return #t end

require "luadoc"

local outputdir = arg[1] or "../doc/"
local sourcecode = arg[2] or "../lua/starfall"

return luadoc.main({sourcecode}, {
	output_dir = outputdir,
	basepath = sourcecode,
	--template_dir = "luadoc/doclet/html/",
	nomodules = false,
	nofiles = true,
	verbose = false,
	taglet = "tagletsf",
	doclet = "docletsfhtml",
})
