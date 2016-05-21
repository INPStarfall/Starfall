TOOL.Category		= "Chips, Gates"
TOOL.Name			= "Starfall - Processor"
TOOL.Command		= nil
TOOL.ConfigName		= ""
TOOL.Tab			= "Wire"

-- ------------------------------- Sending / Recieving ------------------------------- --
include( "starfall/sflib.lua" )

TOOL.ClientConVar[ "Model" ] = "models/spacecode/sfchip.mdl"
cleanup.Register( "starfall_processor" )

if SERVER then
	CreateConVar( "sbox_maxstarfall_processor", 10, { FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE } )
else
	language.Add( "Tool.starfall_processor.name", "Starfall - Processor" )
	language.Add( "Tool.starfall_processor.desc", "Spawns a starfall processor (Press shift+f to switch to screen and back again)" )
	language.Add( "Tool.starfall_processor.0", "Primary: Spawns a processor / uploads code, Secondary: Opens editor" )
	language.Add( "sboxlimit_starfall_processor", "You've hit the Starfall processor limit!" )
	language.Add( "undone_Starfall Processor", "Undone Starfall Processor" )
end

function TOOL:LeftClick ( trace )
	if not trace.HitPos then return false end
	if trace.Entity:IsPlayer() then return false end
	if CLIENT then return true end

	local ply = self:GetOwner()

	if trace.Entity:IsValid() and trace.Entity:GetClass() == "starfall_processor" then
		local ent = trace.Entity
		if not SF.RequestCode( ply, function ( mainfile, files )
			if not mainfile then return end
			if not IsValid( ent ) then return end -- Probably removed during transfer
			ent:Compile( files, mainfile )
		end ) then
			SF.AddNotify( ply, "Cannot upload SF code, please wait for the current upload to finish.", NOTIFY_ERROR, 7, NOTIFYSOUND_ERROR1 )
		end
		return true
	end
	
	self:SetStage( 0 )

	local model = self:GetClientInfo( "Model" )
	if not self:GetSWEP():CheckLimit( "starfall_processor" ) then return false end


	if not SF.RequestCode( ply, function ( mainfile, files )
		if not mainfile then return end

		local ppdata = {}

		SF.Preprocessor.ParseDirectives( mainfile, files[ mainfile ], {}, ppdata )
		if ppdata.models and ppdata.models[ mainfile ] and ppdata.models[ mainfile ] ~= "" then
			model = ppdata.models[ mainfile ]
		end

		local sf = SF.MakeSF( ply, "starfall_processor", trace, model )

		sf:Compile( files, mainfile )
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

function TOOL:DrawHUD () end

function TOOL:Think () end

if CLIENT then

	local function get_active_tool ( ply, tool )
		-- find toolgun
		local activeWep = ply:GetActiveWeapon()
		if not IsValid( activeWep ) or activeWep:GetClass() ~= "gmod_tool" or activeWep.Mode ~= tool then return end

		return activeWep:GetToolObject( tool )
	end

	local modelHologram = nil

	hook.Add( "Think", "SF_Update_modelHologram_Processor", function () 
		if modelHologram == nil or not modelHologram:IsValid() then
			modelHologram = ents.CreateClientProp()
			modelHologram:SetRenderMode( RENDERMODE_TRANSALPHA )
			modelHologram:SetColor( Color( 255, 255, 255, 170 ) )
			modelHologram:Spawn()
		end

		local tool = get_active_tool( LocalPlayer(), "starfall_processor" )
		-- For some reason == nil doesn't return true. Because the function actually returns NULL when a player is NOT driving.
		if tool and LocalPlayer():GetVehicle() == NULL then
			local model = tool.ClientConVar[ "HologramModel" ] or tool:GetClientInfo( "Model" )
			if model and model ~= "" and modelHologram:GetModel() ~= model then
				modelHologram:SetModel( model )
			end

			local min = modelHologram:OBBMins()
			local trace = LocalPlayer():GetEyeTrace()

			if trace.Hit and not ( IsValid( trace.Entity ) and ( trace.Entity:IsPlayer() or trace.Entity:GetClass() == "starfall_processor" ) ) then
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
	
	hook.Add( "PlayerBindPress", "wire_adv", function ( ply, bind, pressed )
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
	end )

	local lastclick = CurTime()
	
	local function GotoDocs ( button )
		gui.OpenURL( "http://sf.inp.io" ) -- old one: http://colonelthirtytwo.net/sfdoc/
	end
	
	function TOOL.BuildCPanel ( panel )
		panel:AddControl( "Header", { Text = "#Tool.starfall_processor.name", Description = "#Tool.starfall_processor.desc" } )
		
		local gateModels = list.Get( "Starfall_gate_Models" )
		table.Merge( gateModels, list.Get( "Wire_gate_Models" ) )
		
		local modelPanel = WireDermaExts.ModelSelect( panel, "starfall_processor_Model", gateModels, 2 )
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
