TOOL.Category		= "Wire - Control"
TOOL.Name			= "Starfall - Processor"
TOOL.Command		= nil
TOOL.ConfigName		= ""
TOOL.Tab			= "Wire"

-- ------------------------------- Sending / Recieving ------------------------------- --
include("starfall/sflib.lua")

local MakeSF

TOOL.ClientConVar[ "Model" ] = "models/spacecode/sfchip.mdl"
cleanup.Register( "starfall_processor" )

if SERVER then
	CreateConVar('sbox_maxstarfall_processor', 10, {FCVAR_REPLICATED,FCVAR_NOTIFY,FCVAR_ARCHIVE})
	
	function MakeSF( pl, Pos, Ang, model)
		if not pl:CheckLimit( "starfall_processor" ) then return false end

		local sf = ents.Create( "starfall_processor" )
		if not IsValid(sf) then return false end

		sf:SetAngles( Ang )
		sf:SetPos( Pos )
		sf:SetModel( model )
		sf:Spawn()

		sf.owner = pl

		pl:AddCount( "starfall_processor", sf )

		return sf
	end
else
	language.Add( "Tool.starfall_processor.name", "Starfall - Processor" )
	language.Add( "Tool.starfall_processor.desc", "Spawns a starfall processor (Press shift+f to switch to screen and back again)" )
	language.Add( "Tool.starfall_processor.0", "Primary: Spawns a processor / uploads code, Secondary: Opens editor" )
	language.Add( "sboxlimit_starfall_processor", "You've hit the Starfall processor limit!" )
	language.Add( "undone_Starfall Processor", "Undone Starfall Processor" )
end

function TOOL:LeftClick( trace )
	if not trace.HitPos then return false end
	if trace.Entity:IsPlayer() then return false end
	if CLIENT then return true end

	local ply = self:GetOwner()

	if trace.Entity:IsValid() and trace.Entity:GetClass() == "starfall_processor" then
		local ent = trace.Entity
		if ( CPPI and not ent:CPPICanTool( self:GetOwner(), "starfall_processor" ) ) or 
			( not CPPI and self:GetOwner() ~= ent.owner  ) then return end
		if not SF.RequestCode( ply, function( mainfile, files )
			if not mainfile then return end
			if not IsValid( ent ) then return end -- Probably removed during transfer
			ent:Compile( files, mainfile )
		end ) then
			SF.AddNotify( ply, "Cannot upload SF code, please wait for the current upload to finish.", NOTIFY_ERROR, 7, NOTIFYSOUND_ERROR1 )
		end
		return true
	end
	
	self:SetStage(0)

	local model = self:GetClientInfo( "Model" )
	if not self:GetSWEP():CheckLimit( "starfall_processor" ) then return false end

	local Ang = trace.HitNormal:Angle()
	Ang.pitch = Ang.pitch + 90

	local sf = MakeSF( ply, trace.HitPos, Ang, model)

	local min = sf:OBBMins()
	sf:SetPos( trace.HitPos - trace.HitNormal * min.z )

	local const = WireLib.Weld(sf, trace.Entity, trace.PhysicsBone, true)

	undo.Create( "Starfall Processor" )
		undo.AddEntity( sf )
		undo.AddEntity( const )
		undo.SetPlayer( ply )
	undo.Finish()

	ply:AddCleanup( "starfall_processor", sf )
	
	if not SF.RequestCode( ply, function( mainfile, files )
		if not mainfile then return end
		if not IsValid( sf ) then return end -- Probably removed during transfer
		sf:Compile( files, mainfile )
	end ) then
		SF.AddNotify( ply, "Cannot upload SF code, please wait for the current upload to finish.", NOTIFY_ERROR, 7, NOTIFYSOUND_ERROR1 )
	end

	return true
end

function TOOL:RightClick( trace )
	if SERVER then 
		self:GetOwner():SendLua("SF.Editor.open()") 
		if trace.Entity:IsValid() and trace.Entity:GetClass() == "starfall_processor" then
			local ent = trace.Entity
			if ( CPPI and not ent:CPPICanTool( self:GetOwner(), "starfall_processor" ) ) or 
				( not CPPI and self:GetOwner() ~= ent.owner  ) then return end

			if not ent.source then return end

			net.Start( "starfall_download" )
				net.WriteEntity( ent )
				net.WriteTable( { ent.mainfile } )
				net.WriteTable( ent.source )
			net.Send( self:GetOwner() )
		end
	end
	return false
end

function TOOL:Reload(trace)
	return false
end

function TOOL:DrawHUD()
end

function TOOL:Think()
end

if CLIENT then
	local function get_active_tool(ply, tool)
		-- find toolgun
		local activeWep = ply:GetActiveWeapon()
		if not IsValid(activeWep) or activeWep:GetClass() ~= "gmod_tool" or activeWep.Mode ~= tool then return end

		return activeWep:GetToolObject(tool)
	end
	
	hook.Add("PlayerBindPress", "wire_adv", function(ply, bind, pressed)
		if not pressed then return end
	
		if bind == "impulse 100" and ply:KeyDown( IN_SPEED ) then
			local self = get_active_tool( ply, "starfall_processor" )
			if not self then
				self = get_active_tool( ply, "starfall_screen" )
				if not self then return end
				
				RunConsoleCommand( "gmod_tool", "starfall_processor" ) -- switch back to processor
				return true
			end
			
			RunConsoleCommand( "gmod_tool", "starfall_screen" ) -- switch to screen
			return true
		end
	end)

	local lastclick = CurTime()
	
	local function GotoDocs(button)
		gui.OpenURL("http://sf.inp.io") -- old one: http://colonelthirtytwo.net/sfdoc/
	end
	
	function TOOL.BuildCPanel(panel)
		panel:AddControl( "Header", { Text = "#Tool.starfall_processor.name", Description = "#Tool.starfall_processor.desc" } )
		
		local gateModels = list.Get( "Starfall_gate_Models" )
		table.Merge( gateModels, list.Get( "Wire_gate_Models" ) )
		
		local modelPanel = WireDermaExts.ModelSelect( panel, "starfall_processor_Model", gateModels, 2 )
		panel:AddControl("Label", {Text = ""})
		
		local docbutton = vgui.Create("DButton" , panel)
		panel:AddPanel(docbutton)
		docbutton:SetText("Starfall Documentation")
		docbutton.DoClick = GotoDocs
		
		local filebrowser = vgui.Create("wire_expression2_browser")
		panel:AddPanel(filebrowser)
		filebrowser:Setup("starfall")
		filebrowser:SetSize(235,400)
		function filebrowser:OnFileOpen(filepath, newtab)
			SF.Editor.editor:Open(filepath, nil, newtab)
		end
		
		local openeditor = vgui.Create("DButton", panel)
		panel:AddPanel(openeditor)
		openeditor:SetText("Open Editor")
		openeditor.DoClick = SF.Editor.open
	end
end
