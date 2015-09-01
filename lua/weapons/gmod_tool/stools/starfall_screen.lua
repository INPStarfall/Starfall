TOOL.Category		= "Visuals/Screens"
TOOL.Wire_MultiCategories = { "Chips, Gates" } -- Also add this to the chips, gates category so that it can be found near the processor
TOOL.Name			= "Starfall - Screen"
TOOL.Command		= nil
TOOL.ConfigName		= ""
TOOL.Tab			= "Wire"

-- ------------------------------- Sending / Recieving ------------------------------- --
include( "starfall/sflib.lua" )

local RequestSend

TOOL.ClientConVar[ "Model" ] = "models/hunter/plates/plate2x2.mdl"
cleanup.Register( "starfall_screen" )

if SERVER then
	util.AddNetworkString( "starfall_screen_requpload" )
	util.AddNetworkString( "starfall_screen_upload" )
	
	net.Receive( "starfall_screen_upload", function ( len, ply )
		local ent = net.ReadEntity()
		if not ent or not ent:IsValid() then
			ErrorNoHalt( "SF: Player " .. ply:GetName() .. " tried to send code to a nonexistant entity.\n" )
			return
		end
		
		if ent:GetClass() ~= "starfall_screen" then
			ErrorNoHalt( "SF: Player " .. ply:GetName() .. " tried to send code to a non-starfall screen entity.\n" )
			return
		end
		
		local mainfile = net.ReadString()
		local numfiles = net.ReadUInt( 16 )
		local task = {
			mainfile = mainfile,
			files = {},
		}
		
		for i = 1, numfiles do
			local filename = net.ReadString()
			local code = net.ReadString()
			task.files[ filename ] = code
		end
		
		ent:CodeSent( ply, task )
	end )
	
	RequestSend = function ( ply, ent )
		net.Start( "starfall_screen_requpload" )
		net.WriteEntity( ent )
		net.Send( ply )
	end
	
	CreateConVar( "sbox_maxstarfall_screen", 3, { FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE } )
else
	language.Add( "Tool.starfall_screen.name", "Starfall - Screen" )
	language.Add( "Tool.starfall_screen.desc", "Spawns a starfall screen" )
	language.Add( "Tool.starfall_screen.0", "Primary: Spawns a screen / uploads code, Secondary: Opens editor" )
	language.Add( "sboxlimit_starfall_Screen", "You've hit the Starfall Screen limit!" )
	language.Add( "undone_Starfall Screen", "Undone Starfall Screen" )
end

function TOOL:LeftClick ( trace )
	if not trace.HitPos then return false end
	if trace.Entity:IsPlayer() then return false end
	if CLIENT then return true end

	local ply = self:GetOwner()

	if trace.Entity:IsValid() and trace.Entity:GetClass() == "starfall_screen" then
		local ent = trace.Entity
		if not SF.RequestCode( ply, function ( mainfile, files )
			if not mainfile then return end
			if not IsValid( ent ) then return end
			ent:CodeSent( ply, files, mainfile )
		end ) then
			SF.AddNotify( ply, "Cannot upload SF code, please wait for the current upload to finish.", NOTIFY_ERROR, 7, NOTIFYSOUND_ERROR1 )
		end
		return true
	end
	
	self:SetStage( 0 )

	if not self:GetSWEP():CheckLimit( "starfall_screen" ) then return false end

	local sf = SF.MakeSF( ply, "starfall_screen", trace, self:GetClientInfo( "Model" ) )

	if not SF.RequestCode( ply, function ( mainfile, files )
		if not mainfile then return end
		if not IsValid( sf ) then return end
		sf:CodeSent( ply, files, mainfile )
	end ) then
		SF.AddNotify( ply, "Cannot upload SF code, please wait for the current upload to finish.", NOTIFY_ERROR, 7, NOTIFYSOUND_ERROR1 )
	end

	return true
end

function TOOL:RightClick ( trace )
	if SERVER then self:GetOwner():SendLua( "SF.Editor.open()" ) end
	return false
end

function TOOL:Reload ( trace )
	return false
end

function TOOL:DrawHUD ()
end

function TOOL:Think ()
end

if CLIENT then
	local lastclick = CurTime()

	local function get_active_tool ( ply, tool )
		-- find toolgun
		local activeWep = ply:GetActiveWeapon()
		if not IsValid( activeWep ) or activeWep:GetClass() ~= "gmod_tool" or activeWep.Mode ~= tool then return end

		return activeWep:GetToolObject( tool )
	end
	
	local modelHologram = nil

	hook.Add( "Think", "SF_Update_modelHologram_Screen", function () 
		if modelHologram == nil or not modelHologram:IsValid() then
			modelHologram = ents.CreateClientProp()
			modelHologram:SetRenderMode( RENDERMODE_TRANSALPHA )
			modelHologram:SetColor( Color( 255, 255, 255, 170 ) )
			modelHologram:Spawn()
		end

		local tool = get_active_tool( LocalPlayer(), "starfall_screen" )
		if tool then
			local model = tool:GetClientInfo( "Model" )
			if model and model ~= "" and modelHologram:GetModel() ~= model then
				modelHologram:SetModel( model )
			end

			local min = modelHologram:OBBMins()
			local trace = LocalPlayer():GetEyeTrace()

			if trace.Hit and not ( IsValid( trace.Entity ) and ( trace.Entity:IsPlayer() or trace.Entity:GetClass() == "starfall_screen" ) ) then
				modelHologram:SetPos( trace.HitPos - trace.HitNormal * min.z )
				modelHologram:SetAngles( trace.HitNormal:Angle() + Angle( 90, 0, 0 ) )
				modelHologram:SetNoDraw( false )
			else
				modelHologram:SetNoDraw( true )
			end
		else
			modelHologram:SetNoDraw( true )
		end

	end )

	local function GotoDocs ( button )
		gui.OpenURL( "http://sf.inp.io" ) -- old one: http://colonelthirtytwo.net/sfdoc/
	end
	
	function TOOL.BuildCPanel ( panel )
		panel:AddControl( "Header", { Text = "#Tool.starfall_screen.name", Description = "#Tool.starfall_screen.desc" } )
		
		local modelpanel = WireDermaExts.ModelSelect( panel, "starfall_screen_Model", list.Get( "WireScreenModels" ), 2 )
		panel:AddControl( "Label", { Text = "" } )
		
		local docbutton = vgui.Create( "DButton" , panel )
		panel:AddPanel( docbutton )
		docbutton:SetText( "Starfall Documentation" )
		docbutton.DoClick = GotoDocs
		
		local filebrowser = vgui.Create( "StarfallFileBrowser" )
		panel:AddPanel( filebrowser )
		filebrowser.tree:setup( "starfall" )
		filebrowser:SetSize( 235,400 )
		
		local lastClick = 0
		filebrowser.tree.DoClick = function ( self, node )
			if CurTime() <= lastClick + 0.5 then
				if not node:GetFileName() or string.GetExtensionFromFilename( node:GetFileName() ) ~= "txt" then return end
				local fileName = string.gsub( node:GetFileName(), "starfall/", "", 1 )
				local code = file.Read( node:GetFileName(), "DATA" )

				for k, v in pairs( SF.Editor.getTabHolder().tabs ) do
					if v.filename == fileName and v.code == code then
						SF.Editor.selectTab( v )
						SF.Editor.open()
						return
					end
				end

				SF.Editor.addTab( fileName, code )
				SF.Editor.open()
			end
			lastClick = CurTime()
		end
		
		local openeditor = vgui.Create( "DButton", panel )
		panel:AddPanel( openeditor )
		openeditor:SetText( "Open Editor" )
		openeditor.DoClick = SF.Editor.open
	end
end
