-------------------------------------------------------------------------------
-- Render library
-------------------------------------------------------------------------------

--- Called when a frame is requested to be drawn. You may want to unhook from this if you don't need
-- to render anything for a bit
-- @name render
-- @class hook
-- @client

--- Render library. Screens are 512x512 units. Most functions require
-- that you be in the rendering hook to call, otherwise an error is
-- thrown. +x is right, +y is down
-- @entity starfall_screen
-- @field TEXT_ALIGN_LEFT
-- @field TEXT_ALIGN_CENTER
-- @field TEXT_ALIGN_RIGHT
-- @field TEXT_ALIGN_TOP
-- @field TEXT_ALIGN_BOTTOM

local render_library, _ = SF.Libraries.RegisterLocal("render")

render_library.TEXT_ALIGN_LEFT = TEXT_ALIGN_LEFT
render_library.TEXT_ALIGN_CENTER = TEXT_ALIGN_CENTER
render_library.TEXT_ALIGN_RIGHT = TEXT_ALIGN_RIGHT
render_library.TEXT_ALIGN_TOP = TEXT_ALIGN_TOP
render_library.TEXT_ALIGN_BOTTOM = TEXT_ALIGN_BOTTOM

--- Vertex format
-- @name Vertex Format
-- @class table
-- @field x X coordinate
-- @field y Y coordinate
-- @field u U coordinate (optional, default is 0)
-- @field v V coordinate (optional, default is 0)

local render = render
local surface = surface
local clamp = math.Clamp
local max = math.max
local cam = cam
local dgetmeta = debug.getmetatable
local matrix_meta = SF.VMatrix.Metatable --debug.getregistry().VMatrix

local v_unwrap = SF.VMatrix.Unwrap

local currentcolor
local MATRIX_STACK_LIMIT = 8
local matrix_stack = {}

SF.Libraries.AddHook("prepare",function(instance, hook)
	if hook == "render" then
		currentcolor = Color(0,0,0,0)
	end
end)

SF.Libraries.AddHook("cleanup", function(instance, hook)
	for i=#matrix_stack,1,-1 do
		cam.PopModelMatrix()
		matrix_stack[i] = nil
	end
end)

local texturecache = {}

local validfonts = {
	DebugFixed = true,
	DebugFixedSmall = true,
	DefaultFixedOutline = true,
	MenuItem = true,
	Default = true,
	TabLarge = true,
	DefaultBold = true,
	DefaultUnderline = true,
	DefaultSmall = true,
	DefaultSmallDropShadow = true,
	DefaultVerySmall = true,
	DefaultLarge = true,
	UiBold = true,
	MenuLarge = true,
	ConsoleText = true,
	Marlett = true,
	Trebuchet18 = true,
	Trebuchet19 = true,
	Trebuchet20 = true,
	Trebuchet22 = true,
	Trebuchet24 = true,
	HUDNumber = true,
	HUDNumber1 = true,
	HUDNumber2 = true,
	HUDNumber3 = true,
	HUDNumber4 = true,
	HUDNumber5 = true,
	HudHintTextLarge = true,
	HudHintTextSmall = true,
	CenterPrintText = true,
	HudSelectionText = true,
	DefaultFixed = true,
	DefaultFixedDropShadow = true,
	CloseCaption_Normal = true,
	CloseCaption_Bold = true,
	CloseCaption_BoldItalic = true,
	TitleFont = true,
	TitleFont2 = true,
	ChatFont = true,
	TargetID = true,
	TargetIDSmall = true,
	HL2MPTypeDeath = true,
	BudgetLabel = true,
}

surface.CreateFont("sf_screen_font_Default_16_400_9_0000", {size = 16, weight = 400,
		antialias=false, additive = false, font = "Default",
		shadow = false, outline = false, blur = 0})

local defined_fonts = {
	["sf_screen_font_Default_16_400_9_0000"] = true
}

local defaultFont = "sf_screen_font_Default_16_400_9_0000"

local poly_methods, poly_metamethods = SF.Typedef("Polygon")
local wrappoly, unwrappoly = SF.CreateWrapper(poly_metamethods)

local function checkvertex(vert)
	return {
		x = SF.CheckType(vert.x or vert[1],"number",1),
		y = SF.CheckType(vert.y or vert[2],"number",1),
		u = tonumber(vert.u or vert[3]) or 0,
		v = tonumber(vert.v or vert[4]) or 0,
	}
end

function poly_metamethods:__index(k)
	SF.CheckType(self,poly_metamethods)
	SF.CheckType(k,"number")
	local poly = unwrappoly(self)
	if not poly then return nil end
	if k <= 0 or k > #poly then return nil end
	return table.Copy(poly[k])
end

function poly_metamethods:__len()
	SF.CheckType(self,poly_metamethods)
	local poly = unwrappoly(self)
	return poly and #poly or nil
end

function poly_metamethods:__newindex(k,v)
	SF.CheckType(self,poly_metamethods)
	SF.CheckType(k,"number")
	SF.CheckType(v,"table")
	local poly = unwrappoly(self)
	if not poly then return end
	if k <= 0 or k > (#poly)+1 then return SF.throw( "poly index out of bounds: " .. k .. " out of " .. #poly, 2 ) end
	poly[k] = checkvertex(v)
end

-- ------------------------------------------------------------------ --

--- Pushes a matrix onto the matrix stack.
-- @param m The matrix
function render_library.pushMatrix(m)
	SF.CheckType(m,matrix_meta)
	local renderdata = SF.instance.data.render
	if not renderdata.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	local id = #matrix_stack
	if id + 1 > MATRIX_STACK_LIMIT then SF.throw( "Pushed too many matricies", 2 ) end
	local newmatrix
	if matrix_stack[id] then
		newmatrix = matrix_stack[id] * v_unwrap(m)
	else
		newmatrix = v_unwrap(m)
	end
	matrix_stack[id+1] = newmatrix
	cam.PushModelMatrix(newmatrix)
end

--- Pops a matrix from the matrix stack.
function render_library.popMatrix()
	local renderdata = SF.instance.data.render
	if not renderdata.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	if #matrix_stack <= 0 then SF.throw( "Popped too many matricies", 2 ) end
	matrix_stack[#matrix_stack] = nil
	cam.PopModelMatrix()
end

--- Sets the draw color
-- @param clr Color type
function render_library.setColor ( clr )
	SF.CheckType( clr, SF.Types[ "Color" ] )
	currentcolor = clr
	surface.SetDrawColor( clr )
	surface.SetTextColor( clr )
end

--- Looks up a texture ID by file name.
-- @param tx Texture file path
function render_library.getTextureID ( tx )
	local id = surface.GetTextureID( tx )
	if id then
		texturecache[ id ] = { tx }
		local cacheentry = texturecache[ id ]
		local mat = Material( tx ) -- Hacky way to get ITexture, if there is a better way - do it!
		cacheentry[ 2 ] = CreateMaterial( "SF_TEXTURE_" .. id, "UnlitGeneric", {
			[ "$nolod" ] = 1,
			[ "$ignorez" ] = 1,
			[ "$vertexcolor" ] = 1,
			[ "$vertexalpha" ] = 1
		} )
		cacheentry[ 2 ]:SetTexture( "$basetexture", mat:GetTexture( "$basetexture" ) )
		return id
	end
end

--- Sets the texture
-- @param id Texture id
function render_library.setTexture ( id )
	if not SF.instance.data.render.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	if not id then
		draw.NoTexture()
	elseif texturecache[ id ] then
		surface.SetMaterial( texturecache[ id ][ 2 ] )
	end
end

--- Clears the surface
-- @param clr Color type to clear with
function render_library.clear ( clr )
    if clr == nil then
        if not SF.instance.data.render.isRendering then SF.throw( "Not in a rendering hook.", 2 ) end
        render.Clear( 0, 0, 0, 255 )
    else
        SF.CheckType( clr, SF.Types[ "Color" ] )
        if not SF.instance.data.render.isRendering then SF.throw( "Not in a rendering hook.", 2 ) end
        render.Clear( clr.r, clr.g, clr.b, clr.a )
    end
end

--- Draws a rectangle using the current color. 
-- @param x Top left corner x coordinate
-- @param y Top left corner y coordinate
-- @param w Width
-- @param h Height
function render_library.drawRect(x,y,w,h)
	if not SF.instance.data.render.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	surface.DrawRect(x,y,w,h)
end

--- Draws a rectangle outline using the current color.
-- @param x Top left corner x coordinate
-- @param y Top left corner y coordinate
-- @param w Width
-- @param h Height
function render_library.drawRectOutline(x,y,w,h)
	if not SF.instance.data.render.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	surface.DrawOutlinedRect(x,y,w,h)
end

--- Draws a circle outline
-- @param x Center x coordinate
-- @param y Center y coordinate
-- @param r Radius
function render_library.drawCircle(x,y,r)
	if not SF.instance.data.render.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	surface.DrawCircle(x,y,r,currentcolor)
end

--- Draws a textured rectangle.
-- @param x Top left corner x coordinate
-- @param y Top left corner y coordinate
-- @param w Width
-- @param h Height
function render_library.drawTexturedRect(x,y,w,h)
	if not SF.instance.data.render.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	surface.DrawTexturedRect(x,y,w,h)
end

--- Draws a textured rectangle with UV coordinates
-- @param x Top left corner x coordinate
-- @param y Top left corner y coordinate
-- @param w Width
-- @param h Height
-- @param startU Texture mapping at rectangle origin
-- @param startV Texture mapping at rectangle origin
-- @param endV Texture mapping at rectangle end
-- @param endV Texture mapping at rectangle end
function render_library.drawTexturedRectUV(x,y,w,h,startU,startV,endU,endV)
	if not SF.instance.data.render.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	surface.DrawTexturedRectUV(x,y,w,h,startU,startV,endU,endV)
end

--- Draws a rotated, textured rectangle.
-- @param x X coordinate of center of rect
-- @param y Y coordinate of center of rect
-- @param w Width
-- @param h Height
-- @param rot Rotation in degrees
function render_library.drawTexturedRectRotated(x,y,w,h,rot)
	if not SF.instance.data.render.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	surface.DrawTexturedRectRotated(x, y, w, h, rot)
end

--- Draws a line
-- @param x1 X start coordinate
-- @param y1 Y start coordinate
-- @param x2 X end coordinate
-- @param y2 Y end coordinate
function render_library.drawLine(x1,y1,x2,y2)
	if not SF.instance.data.render.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	surface.DrawLine(x1,y1,x2,y2)
end

-- Creates a font. Does not require rendering hook
-- @param font Base font to use
-- @param size Font size
-- @param weight Font weight (default: 400)
-- @param antialias Antialias font?
-- @param additive If true, adds brightness to pixels behind it rather than drawing over them.
-- @param shadow Enable drop shadow?
-- @param outline Enable outline?
-- @param A table representing the font (doesn't contain anything)
function render_library.createFont(font,size,weight,antialias,additive,shadow,outline,blur)
	if not validfonts[font] then SF.throw( "invalid font", 2 ) end
	
	size = tonumber(size) or 16
	weight = tonumber(weight) or 400
	blur = tonumber(blur) or 0
	antialias = antialias and true or false
	additive = additive and true or false
	shadow = shadow and true or false
	outline = outline and true or false
	
	local name = string.format("sf_screen_font_%s_%d_%d_%d_%d%d%d%d",
		font, size, weight, blur,
		antialias and 1 or 0,
		additive and 1 or 0,
		shadow and 1 or 0,
		outline and 1 or 0)
	
	if not defined_fonts[name] then
		surface.CreateFont(name, {size = size, weight = weight,
			antialias=antialias, additive = additive, font = font,
			shadow = shadow, outline = outline, blur = blur})
		defined_fonts[name] = true
	end
	return name
end

--- Gets the size of the specified text. Don't forget to use setFont before calling this function
-- @param text Text to get the size of
-- @return width of the text
-- @return height of the text
function render_library.getTextSize( text )
	SF.CheckType(text,"string")
	
	surface.SetFont(SF.instance.data.render.font or defaultFont)
	return surface.GetTextSize( text )
end

--- Sets the font
-- @param font The font to use
function render_library.setFont(font)
	if not defined_fonts[font] then SF.throw( "Font does not exist.", 2 ) end
	SF.instance.data.render.font = font
	--surface.SetFont(font)
end

--- Gets the default font
-- @return Default font
function render_library.getDefaultFont()
	return defaultFont
end

--- Draws text using a font
-- @param font Font table returned by createFont
-- @param x X coordinate
-- @param y Y coordinate
-- @param text Text to draw
-- @param alignment Text alignment
function render_library.drawText(x,y,text,alignment)
	if not SF.instance.data.render.isRendering then SF.throw( "Not in rendering hook.", 2 ) end
	SF.CheckType(text,"string")
	
	local font = SF.instance.data.render.font or defaultFont
	
	draw.DrawText(text, font, tonumber(x) or 0, tonumber(y) or 0, currentcolor, tonumber(alignment) or TEXT_ALIGN_LEFT)
end

--- Creates a vertex for use with polygons. This just creates a table; it doesn't really do anything special
-- @param x x coordinate
-- @param y y coordinate
-- @param u u texture coordinate
-- @param v v texture coordinate
-- @return vertex table
function render_library.vertex(x,y,u,v)
	return {x=x, y=y, u=u, v=v}
end

--- Compiles a 2D poly. This is needed so that poly don't have to be
-- type-checked each frame. Polys can be indexed by a number, in which
-- a copy of the vertex at that spot is returned. They can also be assigned
-- a new vertex at 1 <= i <= #poly+1. And the length of the poly can be taken.
-- @param verts Array of verticies to convert.
-- @return compiled polygon
function render_library.createPoly(verts)
	SF.CheckType(verts,"table")
	local poly = {}
	local wrappedpoly = wrappoly(poly)
	for i=1,#verts do
		local v = verts[i]
		SF.CheckType(v,"table")
		poly[i] = checkvertex(v)
	end
	return wrappedpoly
end

--- Draws a polygon. Takes a compiled/uncompiled poly to draw.
-- Note that if you do use an uncompiled poly, you will use up ops
-- very quickly!
-- @param poly Compiled poly or array of vertexes
function render_library.drawPoly(poly)
	if dgetmeta(poly) ~= poly_metamethods then
		SF.CheckType(poly,"table")
		local verts = poly
		poly = {}
		for i=1,#verts do
			local v = verts[i]
			SF.CheckType(v,"table")
			poly[i] = checkvertex(v)
		end
	else
		poly = unwrappoly(poly)
	end
	surface.DrawPoly(poly)
end

--- Gets a 2D cursor position where ply is aiming.
-- @param ply player to get cursor position from
-- @return x position
-- @return y position
function render_library.cursorPos( ply )
	-- Taken from EGPLib
	local Normal, Pos, monitor, Ang
	local screen = SF.instance.data.entity
	if not screen then return nil end
	
	ply = SF.Entities.Unwrap( ply )
	
	-- Get monitor screen pos & size
	monitor = WireGPU_Monitors[ screen:GetModel() ]
		
	-- Monitor does not have a valid screen point
	if not monitor then return nil end
		
	Ang = screen:LocalToWorldAngles( monitor.rot )
	Pos = screen:LocalToWorld( monitor.offset )
		
	Normal = Ang:Up()
	
	local Start = ply:GetShootPos()
	local Dir = ply:GetAimVector()
	
	local A = Normal:Dot(Dir)
	
	-- If ray is parallel or behind the screen
	if A == 0 or A > 0 then return nil end
	
	local B = Normal:Dot(Pos-Start) / A
		if (B >= 0) then
		local HitPos = WorldToLocal( Start + Dir * B, Angle(), Pos, Ang )
		local x = (0.5+HitPos.x/(monitor.RS*512/monitor.RatioX)) * 512
		local y = (0.5-HitPos.y/(monitor.RS*512)) * 512	
		if x < 0 or x > 512 or y < 0 or y > 512 then return nil end -- Aiming off the screen 
		return x, y
	end
	
	return nil
end

--- Returns information about the screen, such as dimentions and rotation.
-- Note: this does a table copy so move it out of your draw hook
-- @return A table describing the screen.
function render_library.getScreenInfo()
	local gpu = SF.instance.data.render.gpu
	if not gpu then return end
	local info, _, _ = gpu:GetInfo()
	return table.Copy(info)
end

--- Returns the screen surface's world position and angle
-- @return The screen position
-- @return The screen angle
function render_library.getScreenPos()
	local gpu = SF.instance.data.render.gpu
	if not gpu then return end
	local _, pos, rot = gpu:GetInfo()
	return pos, rot
end

---
-- @name Screen information table
-- @class table
-- @field Name Pretty name of model
-- @field offset Offset of screen from prop
-- @field RS Resolution/scale
-- @field RatioX Inverted Aspect ratio (height divided by width)
-- @field x1 Corner of screen in local coordinates (relative to offset?)
-- @field x2 Corner of screen in local coordinates (relative to offset?)
-- @field y1 Corner of screen in local coordinates (relative to offset?)
-- @field y2 Corner of screen in local coordinates (relative to offset?)
-- @field z Screen plane offset in local coordinates (relative to offset?)
-- @field rot Screen rotation
