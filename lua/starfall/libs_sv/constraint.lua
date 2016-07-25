
-------------------------------------------------------------------------------
-- Constraint functions
-------------------------------------------------------------------------------

assert( SF.GetTypeDef( "Entity" ) )

--- Constraint library. Used for various entity constraints
-- @name constraint
-- @server
-- @class library
-- @libtbl constraint_lib
local constraint_lib, _ = SF.Libraries.Register( "constraint" )

local wrap, unwrap = SF.WrapObject, SF.UnwrapObject

local valid = SF.Entities.IsValid
--TODO: Uncomment when #371 is merged
--local valid = SF.GetTypeDef( "Entity" ).IsValid

do
	local P = SF.Permissions
	P.registerPrivilege( "constraint.advballsocket", "Advanced Ballsocket", "Allows the user to create an advanced ballsocket between two entities" )
	P.registerPrivilege( "constraint.axis", "Axis", "Allows the user to create an axis between two entities" )
	P.registerPrivilege( "constraint.ballsocket", "Ballsocket", "Allows the user to create a ballsocket between two entities" )
	P.registerPrivilege( "constraint.elastic", "Elastic", "Allows the user to create an elastic between two entities" )
	P.registerPrivilege( "constraint.hydraulic", "Hydraulic", "Allows the user to create a hydraulic between two entities" )
	P.registerPrivilege( "constraint.keepupright", "Keepupright", "Allows the user to create a keepupright constraint" )
	P.registerPrivilege( "constraint.motor", "Motor", "Allows the user to create a motor between two entities" )
	P.registerPrivilege( "constraint.muscle", "Muscle", "Allows the user to create a muscle between two entities" )
	P.registerPrivilege( "constraint.nocollide", "NoCollide", "Allows the user to nocollide two entities" )
	P.registerPrivilege( "constraint.pulley", "Pulley", "Allows the user to create a pully between two entities" )
	P.registerPrivilege( "constraint.rope", "Rope", "Allows the user to create a rope between two entities" )
	P.registerPrivilege( "constraint.slider", "Slider", "Allows the user to create a slider between two entities" )
	P.registerPrivilege( "constraint.weld", "Weld", "Allows the user to create a weld between two entities" )
	P.registerPrivilege( "constraint.winch", "Winch", "Allows the user to create a winch between two entities" )

	P.registerPrivilege( "constraint.remove", "Remove Constraint", "Allows the user to remove constraints between entities" )
	P.registerPrivilege( "constraint.get", "Get Constraint", "Allows the user to get the entity constraints between other entities" )
end

--- Creates an advanced ballsocket between two entities
-- @param ent1 The first entity
-- @param ent2 The second entity
-- @param pos1 The position relative to ent1
-- @param pos2 The position relative to ent2
-- @param min The minimum angle that the advanced ballsocket is constrained to
-- @param max The maximum angle that the advanced ballsocket is constrained to
-- @param forceLimit The force that is required to break the advanced ballsocket, 0 means it will never break; defaults to 0
-- @param torqueLimit The torque that is required to break the advanced ballsocket, 0 means it will never break; defaults to 0
-- @param friction The fricitonal vector that is applied to the advanced ballsocket; defaults to Vector( 0, 0, 0 )
-- @param nocollide Whether the entities are nocollided with each other; defaults to true
-- @param bone1 Bone of the first entity; defaults to 0
-- @param bone2 Bone of the second entity; defaults to 0
-- @return The advanced ballsocket constraint if it is created
function constraint_lib.advBallsocket( ent1, ent2, pos1, pos2, min, max, forceLimit, torqueLimit, friction, nocollide, bone1, bone2 )
	SF.CheckType( ent1, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( ent2, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( pos1, SF.GetTypeDef( "Vector" ) )
	SF.CheckType( pos2, SF.GetTypeDef( "Vector" ) )
	SF.CheckType( min, SF.GetTypeDef( "Angle" ) )
	SF.CheckType( max, SF.GetTypeDef( "Angle" ) )
	if forceLimit then SF.CheckType( forceLimit, "number" ) else forceLimit = 0 end
	if torqueLimit then SF.CheckType( torqueLimit, "number" ) else torqueLimit = 0 end
	if friction ~= nil then SF.CheckType( friction, SF.GetTypeDef( "Vector" ) ) else friction = Vector( 0, 0, 0 ) end
	if nocollide ~= nil then SF.CheckType( nocollide, "boolean" ) else nocollide = true end
	if bone1 then SF.CheckType( bone1, "number" ) else bone1 = 0 end
	if bone2 then SF.CheckType( bone2, "number" ) else bone2 = 0 end

	ent1 = unwrap( ent1 )
	ent2 = unwrap( ent2 )
	if not valid( ent1 ) then return end
	if not valid( ent2 ) then return end

	if not SF.Permissions.check( SF.instance.owner, ent1, "constraint.advballsocket" ) then SF.throw( "Insufficient permissions", 2 ) end
	if not SF.Permissions.check( SF.instance.owner, ent2, "constraint.advballsocket" ) then SF.throw( "Insufficient permissions", 2 ) end

	--TODO: Determine what rotateonly does; second to last argument
	local constraintEnt = constraint.AdvBallsocket( ent1, ent2, bone1, bone2, unwrap( pos1 ), unwrap( pos2 ), forceLimit, torqueLimit, min.p, min.y, min.r, max.p, max.y, max.r, friction.x, friction.y, friction.z, nil, false )

	return constraintEnt == false and nil or wrap( constraintEnt )
end

--- Creates an axis between two entities
-- @param ent1 The first entity
-- @param ent2 The second entity
-- @param pos1 The position relative to ent1
-- @param pos2 The position relative to ent2
-- @param forceLimit The force that is required to break the axis, 0 means it will never break; defaults to 0
-- @param torqueLimit The torque that is required to break the axis, 0 means it will never break; defaults to 0
-- @param friction The amount of frictional force to apply; defaults to 0
-- @param nocollide Whether the entities are nocollided with each other; defaults to true
-- @param localAxis If included, pos2 will not be used in the final constraint
-- @param bone1 Bone of the first entity; defaults to 0
-- @param bone2 Bone of the second entity; defaults to 0
-- @return The axis constraint if it is created
function constraint_lib.axis ( ent1, ent2, pos1, pos2, forceLimit, torqueLimit, friction, nocollide, localAxis, bone1, bone2 )
	SF.CheckType( ent1, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( ent2, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( pos1, SF.GetTypeDef( "Vector" ) )
	SF.CheckType( pos2, SF.GetTypeDef( "Vector" ) )
	if forceLimit then SF.CheckType( forceLimit, "number" ) else forceLimit = 0 end
	if torqueLimit then SF.CheckType( torqueLimit, "number" ) else torqueLimit = 0 end
	if friction then SF.CheckType( friction, "number" ) else friction = 0 end
	if nocollide ~= nil then SF.CheckType( nocollide, "boolean" ) else nocollide = true end
	if localAxis then SF.CheckType( localAxis, SF.GetTypeDef( "Vector" ) ) end
	if bone1 then SF.CheckType( bone1, "number" ) else bone1 = 0 end
	if bone2 then SF.CheckType( bone2, "number" ) else bone2 = 0 end

	ent1 = unwrap( ent1 )
	ent2 = unwrap( ent2 )
	if not valid( ent1 ) then return end
	if not valid( ent2 ) then return end

	if not SF.Permissions.check( SF.instance.owner, ent1, "constraint.axis" ) then SF.throw( "Insufficient permissions", 2 ) end
	if not SF.Permissions.check( SF.instance.owner, ent2, "constraint.axis" ) then SF.throw( "Insufficient permissions", 2 ) end

	local constraintEnt = constraint.Axis( ent1, ent2, 0, 0, unwrap( pos1 ), unwrap( pos2 ), forceLimit, torqueLimit, friction, nocollide, localAxis, false )

	return constraintEnt == false and nil or wrap( constraintEnt )
end

--- Creates a ballsocket between two entities
-- @param ent1 The first entity
-- @param ent2 The second entity
-- @param pos1 The position relative to ent1
-- @param forceLimit The force that is required to break the axis, 0 means it will never break; defaults to 0
-- @param torqueLimit The torque that is required to break the axis, 0 means it will never break; defaults to 0
-- @param nocollide Whether the entities are nocollided with each other; defaults to true
-- @param bone1 Bone of the first entity; defaults to 0
-- @param bone2 Bone of the second entity; defaults to 0
-- @return The ballsocket constraint if it is created
function constraint_lib.ballsocket ( ent1, ent2, pos1, forceLimit, torqueLimit, nocollide, bone1, bone2 )
	SF.CheckType( ent1, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( ent2, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( pos1, SF.GetTypeDef( "Vector" ) )
	if forceLimit then SF.CheckType( forceLimit, "number" ) else forceLimit = 0 end
	if torqueLimit then SF.CheckType( torqueLimit, "number" ) else torqueLimit = 0 end
	if nocollide ~= nil then SF.CheckType( nocollide, "boolean" ) else nocollide = true end
	if bone1 then SF.CheckType( bone1, "number" ) else bone1 = 0 end
	if bone2 then SF.CheckType( bone2, "number" ) else bone2 = 0 end

	ent1 = unwrap( ent1 )
	ent2 = unwrap( ent2 )
	if not valid( ent1 ) then return end
	if not valid( ent2 ) then return end

	if not SF.Permissions.check( SF.instance.owner, ent1, "constraint.ballsocket" ) then SF.throw( "Insufficient permissions", 2 ) end
	if not SF.Permissions.check( SF.instance.owner, ent2, "constraint.ballsocket" ) then SF.throw( "Insufficient permissions", 2 ) end

	local constraintEnt = constraint.Ballsocket( ent1, ent2, bone1, bone2, unwrap( pos1 ), forceLimit, torqueLimit, nocollide )

	return constraintEnt == false and nil or wrap( constraintEnt )
end

--- Creates an elastic between two entities
-- @param ent1 The first entity
-- @param ent2 The second entity
-- @param pos1 The position relative to ent1
-- @param pos2 The position relative to ent2
-- @param constant The constant force that is applied to the elastic
-- @param damping The torque that is required to break the axis, 0 means it will never break; defaults to 0
-- @param rdamping
-- @param material The material of the elastic
-- @param width The width of the elastic; defaults to 0
-- @param stretchonly Boolean whether the elastic can only stretch
-- @param bone1 Bone of the first entity; defaults to 0
-- @param bone2 Bone of the second entity; defaults to 0
-- @return The elastic constraint if it is created
function constraint_lib.elastic ( ent1, ent2, pos1, pos2, constant, damping, rdamping, material, width, stretchonly, bone1, bone2 )
	SF.CheckType( ent1, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( ent2, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( pos1, SF.GetTypeDef( "Vector" ) )
	SF.CheckType( pos2, SF.GetTypeDef( "Vector" ) )
	SF.CheckType( constant, "number" )
	SF.CheckType( damping, "number" )
	SF.CheckType( rdamping, "number" )
	SF.CheckType( material, "string" )
	SF.CheckType( width, "number" )
	SF.CheckType( stretchonly, "boolean" )
	if bone1 then SF.CheckType( bone1, "number" ) else bone1 = 0 end
	if bone2 then SF.CheckType( bone2, "number" ) else bone2 = 0 end

	ent1 = unwrap( ent1 )
	ent2 = unwrap( ent2 )
	if not valid( ent1 ) then return end
	if not valid( ent2 ) then return end

	if not SF.Permissions.check( SF.instance.owner, ent1, "constraint.elastic" ) then SF.throw( "Insufficient permissions", 2 ) end
	if not SF.Permissions.check( SF.instance.owner, ent2, "constraint.elastic" ) then SF.throw( "Insufficient permissions", 2 ) end

	local constraintEnt = constraint.Ballsocket( ent1, ent2, bone1, bone2, unwrap( pos1 ), unwrap( pos2 ), constant, damping, rdamping, material, width, stretchonly )

	return constraintEnt == false and nil or wrap( constraintEnt )
end

--- Creates a hydraulic between two entities
-- @param ent1 The first entity
-- @param ent2 The second entity
-- @param pos1 The position relative to ent1
-- @param pos2 The position relative to ent2
-- @param length1 The length of the hydraulic when it is retracted
-- @param length2 The length of the hydraulic when it is extended
-- @param width The width of the hydraulic; defaults to 0
-- @param key The key binding, see <a href="http://wiki.garrysmod.com/page/Enums/KEY">KEY Enumerations<\a> ( Use numerical values, not the variable )
-- @param fixed Whether the hydraulic is fixed
-- @param speed The rate at which the hydraulic extends / retracts
-- @param material The material of the hydraulic
-- @param bone1 Bone of the first entity; defaults to 0
-- @param bone2 Bone of the second entity; defaults to 0
-- @return The hydraulic constraint if it is created
-- @return The rope constraint if it is created
-- @return The slider constraint if it is created
function constraint_lib.hydraulic ( ent1, ent2, pos1, pos2, length1, length2, width, key, fixed, speed, material, bone1, bone2 )
	SF.CheckType( ent1, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( ent2, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( pos1, SF.GetTypeDef( "Vector" ) )
	SF.CheckType( pos2, SF.GetTypeDef( "Vector" ) )
	SF.CheckType( length1, "number" )
	SF.CheckType( length2, "number" )
	if width then SF.CheckType( width, "number" ) else width = 0 end
	SF.CheckType( key, "number" )
	SF.CheckType( fixed, "number" )
	SF.CheckType( speed, "number" )
	SF.CheckType( material, "string" )
	if bone1 then SF.CheckType( bone1, "number" ) else bone1 = 0 end
	if bone2 then SF.CheckType( bone2, "number" ) else bone2 = 0 end

	ent1 = unwrap( ent1 )
	ent2 = unwrap( ent2 )
	if not valid( ent1 ) then return end
	if not valid( ent2 ) then return end

	if not SF.Permissions.check( SF.instance.owner, ent1, "constraint.hydraulic" ) then SF.throw( "Insufficient permissions", 2 ) end
	if not SF.Permissions.check( SF.instance.owner, ent2, "constraint.hydraulic" ) then SF.throw( "Insufficient permissions", 2 ) end

	local constraintEnt, rope, controller, slider = constraint.Hydraulic( SF.instance.owner(), ent1, ent2, bone1, bone2, unwrap( pos1 ), unwrap( pos2 ), length1, length2, width, key, fixed, speed, material )

	return constraintEnt == false and nil or wrap( constraintEnt ), constraintEnt == false and nil or wrap( rope ), constraintEnt == false and nil or wrap( slider )
end

--- Creates a keep upright constraint
-- @param ent The entity to keep upright
-- @param ang The target angle
-- @param angularLimit The amount of force that is required to rotate the object
-- @param bone Bone of the entity; defaults to 0
-- @return The keep upright constraint if it is created
function constraint_lib.keepupright ( ent, ang, angularLimit, bone )
	SF.CheckType( ent, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( ang, SF.GetTypeDef( "Angle" ) )
	SF.CheckType( angularLimit, "number" )
	if bone then SF.CheckType( bone, "number" ) else bone = 0 end
	
	ent = unwrap( ent )
	if not valid( ent ) then return end

	if not SF.Permissions.check( SF.instance.owner, ent, "constraint.keepupright" ) then SF.throw( "Insufficient permissions", 2 ) end

	local constraintEnt = constraint.Keepupright( ent, unwrap( ang ), bone, angularLimit )

	return constraintEnt == false and nil or wrap( constraintEnt )
end

--- Creates a motor between two entities
-- @param ent1 The first entity
-- @param ent2 The second entity
-- @param pos1 The position relative to ent1
-- @param pos2 The position relative to ent2
-- @param friction The frictional force that is applied to the entities; defaults to 0
-- @param torque The torque that the motor applies to the entities
-- @param forcetime
-- @param nocollide Whether the two entities should nocollide with eachother; defaults to true
-- @param toggle Whether the motor will toggle its active state
-- @param forceLimit The force that is required to break the advanced ballsocket, 0 means it will never break; defaults to 0
-- @param direction
-- @param localAxis If included, pos2 will not be used in the final constraint
-- @param fwd The keybind for "forward", see <a href="http://wiki.garrysmod.com/page/Enums/KEY">KEY Enumerations<\a> ( Use numerical values, not the variable )
-- @param bwd The keybind for "backwards", see <a href="http://wiki.garrysmod.com/page/Enums/KEY">KEY Enumerations<\a> ( Use numerical values, not the variable )
-- @param bone1 Bone of the first entity; defaults to 0
-- @param bone2 Bone of the second entity; defaults to 0
-- @return The motor constraint if it is created
-- @return The axis constraint if it is created
function constraint_lib.motor( ent1, ent2, pos1, pos2, friction, torque, forcetime, nocollide, toggle, forceLimit, direction, localAxis, pl, fwd, bwd, bone1, bone2 )
	SF.CheckType( ent1, SF.GetTypeDef( "Entitiy" ) )
	SF.CheckType( ent2, SF.GetTypeDef( "Entitiy" ) )
	SF.CheckType( pos1, SF.GetTypeDef( "Vector" ) )
	SF.CheckType( pos2, SF.GetTypeDef( "Vector" ) )
	if friction then SF.CheckType( friction, "number" ) else friction = 0 end
	SF.CheckType( torque, "number" )
	SF.CheckType( forcetime, "number" )
	if nocollide ~= nil then SF.CheckType( nocollide, "boolean" ) else nocollide = true end
	SF.CheckType( toggle, "boolean" )
	if forceLimit then SF.CheckType( forceLimit, "number" ) else forceLimit = 0 end
	SF.CheckType( direction, "number" )
	if localAxis then SF.CheckType( localAxis, SF.GetTypeDef( "Vector" ) ) end
	SF.CheckType( fwd, "number" )
	SF.CheckType( bwd, "number" )
	if bone1 then SF.CheckType( bone1, "number" ) else bone1 = 0 end

	ent1 = unwrap( ent1 )
	ent2 = unwrap( ent2 )
	if not valid( ent1 ) then return end
	if not valid( ent2 ) then return end

	if not SF.Permissions.check( SF.instance.owner, ent1, "constraint.motor" ) then SF.throw( "Insufficient permissions", 2 ) end
	if not SF.Permissions.check( SF.instance.owner, ent2, "constraint.motor" ) then SF.throw( "Insufficient permissions", 2 ) end

	local constraintEnt, axis = constraint.Motor( ent1, ent2, bone1, bone2, unwrap( pos1 ), unwrap( pos2 ), friction, torque, forcetime, nocollide, toggle, SF.instance.owner, forceLimit, fwd, bwd, direction, localAxis )

	return constraintEnt == false and nil or wrap( constraintEnt ), constraintEnt == false and nil or wrap( axis )
end

--- Creates a muscle between two entities
-- @param ent1 The first entity
-- @param ent2 The second entity
-- @param pos1 The position relative to ent1
-- @param pos2 The position relative to ent2
-- @param length1 The length of the muscle when it is retracted
-- @param length2 The length of the muscle when it is extended
-- @param width The width of the muscle
-- @param key The key binding to use with the muscle, see <a href="http://wiki.garrysmod.com/page/Enums/KEY">KEY Enumerations<\a> ( Use numerical values, not the variable )
-- @param fixed Whether the constraint is fixed
-- @param period
-- @param amplitude
-- @param starton
-- @param material The material of the rope
-- @param bone1 Bone of the first entity; defaults to 0
-- @param bone2 Bone of the second entity; defaults to 0
function constraint_lib.muscle ( ent1, ent2, pos1, pos2, length1, length2, width, key, fixed, period, amplitude, starton, material, bone1, bone2 )
	
end

--- Returns the constraint of a specified type between two entities if it exists
-- @param ent1 The first entity
-- @param ent2 The second entity
-- @param type The string name of the constraint to look for
-- @param bone1 Bone of the first entity; defaults to 0
-- @param bone2 Bone of the second entity; defaults to 0
-- @return The constraint entity
function constraint_lib.find ( ent1, ent2, type, bone1, bone2 )
	SF.CheckType( ent1, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( ent2, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( type, "string" )
	if bone1 then SF.CheckType( bone1, "number" ) else bone1 = 0 end
	if bone2 then SF.CheckType( bone2, "number" ) else bone2 = 0 end

	ent1 = unwrap( ent1 )
	ent2 = unwrap( ent2 )
	if not valid( ent1 ) then return end
	if not valid( ent2 ) then return end

	if not SF.Permissions.check( SF.instance.owner, ent1, "constraint.get" ) then SF.throw( "Insufficient permissions", 2 ) end
	if not SF.Permissions.check( SF.instance.owner, ent2, "constraint.get" ) then SF.throw( "Insufficient permissions", 2 ) end

	local constraintEnt = constraint.Find( ent1, ent2, bone1, bone2, type )

	return wrap( constraintEnt )
end

--- Returns the first constraint of a specific type directly connected to the entity
-- @param ent The entity to check
-- @param type The string name of the constraint to look for
-- @return The constraint table
function constraint_lib.findConstraint ( ent, type )
	SF.CheckType( ent, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( type, "string" )

	ent = unwrap( ent )
	if not valid( ent ) then return {} end

	if not SF.Permissions.check( SF.instance.owner, ent, "constraint.get" ) then SF.throw( "Insufficient permissions", 2 ) end

	return SF.Sanitize( constraint.FindConstraint( ent, type ) )
end

--- Returns the other entity that the constraint is attached to
-- @param ent The entity to check
-- @param type The string name of the constraint to look for
-- @return The other entity
function constraint_lib.findConstraintEntity ( ent, type )
	SF.CheckType( ent, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( type, "string" )

	ent = unwrap( ent )
	if not valid( ent ) then return end

	if not SF.Permissions.check( SF.instance.owner, ent, "constraint.get" ) then SF.throw( "Insufficient permissions", 2 ) end

	return wrap( constraint.findConstraintEntity( ent, type ) )
end

--- Returns a table of all constraints of a specific type
-- @param ent The entity to check
-- @param type The string name of the constraint to look for
-- @return Table of all constraints of that type
function constraint_lib.findConstraints ( ent, type )
	SF.CheckType( ent, SF.GetTypeDef( "Entity" ) )
	SF.CheckType( type, "string" )

	ent = unwrap( ent )
	if not valid( ent ) then return {} end

	if not SF.Permissions.check( SF.instance.owner, ent, "constraint.get" ) then SF.throw( "Insufficient permissions", 2 ) end

	return SF.Sanitize( constraint.FindConstraints( ent, type ) )
end

--- Creates a table of entities recursively constrained to an entity
-- @param ent Base entity of search
-- @param default Default table to return
-- @return Table of constrained entities
function constraint_lib.getAllConstrainedEntities ( ent, default )
	SF.CheckType( ent, SF.GetTypeDef( "Entity" ) )
	if default ~= nil then SF.CheckType( default, "table" ) else default = {} end

	ent = unwrap( ent )
	if not valid( ent ) then return {} end

	local constrainedEnts = constraint.GetAllConstrainedEntities( ent, {} )

	constrainedEnts = SF.Sanitize( constrainedEnts )

	if #constrainedEnts == 0 then
		constrainedEnts = default
	end

	return constrainedEnts
end

--- Creates a table of constraints on an entity
-- @param ent Target entity
-- @return Table of entity constraints
function constraint_lib.getTable ( ent )
	SF.CheckType( ent, SF.GetTypeDef( "Entity" ) )

	if not SF.Permissions.check( SF.instance.owner, ent, "constraint.get" ) then SF.throw( "Insufficient permissions", 2 ) end

	ent = unwrap( ent )
	if not valid( ent ) then return {} end

	local constraints = constraint.GetTable( ent )

	local ret = SF.Sanitize( constraints )

	return ret
end

--- Returns whether the entity has constraints attached to it
-- @param ent The entity to check
-- @return Boolean whether the entity has constraints
function constraint_lib.hasConstraints ( ent )
	SF.CheckType( ent, SF.GetTypeDef( "Entity" ) )
	ent = unwrap( ent )
	if not valid( ent ) then return false end

	if not SF.Permissions.check( SF.instance.owner, ent, "constraint.get" ) then SF.throw( "Insufficient permissions", 2 ) end

	return constraint.hasConstraints( ent )
end
