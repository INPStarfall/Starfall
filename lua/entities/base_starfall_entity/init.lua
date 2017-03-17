AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

function ENT:Initialize ()
	baseclass.Get( "base_gmodentity" ).Initialize( self )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self.instance = nil
end

function ENT:OnRemove ()
	if not self.instance then return end

	hook.Run( "sf_deinitialize", self:EntIndex( ) )
	self:runScriptHook( "Removed" )

	if self.instance then self.instance:deinitialize() end
	self.instance = nil
end

function ENT:onRestore ()
end

function ENT:BuildDupeInfo ()
	return WireLib.BuildDupeInfo( self ) or {}
end

function ENT:ApplyDupeInfo ( ply, ent, info, GetEntByID )
	WireLib.ApplyDupeInfo ( ply, ent, info, GetEntByID )
end

function ENT:PreEntityCopy ()
	local i = self:BuildDupeInfo()
	if i then
		duplicator.StoreEntityModifier( self, "SFDupeInfo", i )
	end
end

local function EntLookup(created)
	return function(id, def)
		local ent = created[id]
		return (IsValid(ent) and ent or def)
	end
end

function ENT:PostEntityPaste ( ply, ent, created )
	if ent.EntityMods and ent.EntityMods.SFDupeInfo then
		ent:ApplyDupeInfo( ply, ent, ent.EntityMods.SFDupeInfo, EntLookup(created) )
	end
end