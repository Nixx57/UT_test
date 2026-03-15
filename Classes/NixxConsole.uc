//=====================================================================================
// BOT START.
//=====================================================================================
class NixxConsole extends UTConsole config(NixxConsole);

var config bool bAutoAim;
var config int MySetSlowSpeed;
var config bool bUseSplash;
var config bool bAimPlayers;
var config bool bRotateSlow;
var config bool bDebug;
var config bool bShowOverlay;

var PlayerPawn Me;
var Pawn CurrentTarget;
var int LastFireMode;
var Vector AltOffset;

var Actor TargetToFollow;
var string Status;
var Actor NextNode;
var float LastDodgeTime;

struct PositionData
{
    var Vector Location;
    var float Time;
};

var PositionData PreviousLocations[16];
var int LocationIndex;

// Ladder randomization
var string CollectedMaps[64];
var int NumCollectedMaps;

event PostRender (Canvas Canvas)
{
	Super.PostRender(Canvas); 

	if( bShowOverlay )
	{
		DrawMySettings(Canvas);
	}
}

event Tick( float Delta )
{
	Super.Tick( Delta );

	if ( (Root != None) && bShowMessage )
		Root.DoTick( Delta );

	Me = Viewport.Actor;
	CustomLadderInv();

	Begin(Delta);
}

//================================================================================
// MAIN BOT.
//================================================================================
function NixxConsole()
{
	local int i;
	LocationIndex = 0;
	for (i = 0; i < ArrayCount(PreviousLocations); i++)
    {
        PreviousLocations[i].Location = vect(0,0,0);
        PreviousLocations[i].Time = Me.Level.TimeSeconds;
    }
}

function Begin(float Delta)
{
	if (Me == None || Me.PlayerReplicationInfo == None)
	{
		Return;
	}

	if (Me.bFire == 1)
	{
		LastFireMode = 1;
	}
	else if (Me.bAltFire == 1)
	{
		LastFireMode = 2;
	}
		
	if(!bAutoAim || Me.IsInState('GameEnded'))
		Return;
	
	if(Me.Weapon != None && !Me.Weapon.IsA('Translocator'))
		PawnRelated(Delta);
}




function UpdatePreviousLocations(Pawn Target, float DeltaTime)
{
	PreviousLocations[LocationIndex].Location = Target.Location;
	PreviousLocations[LocationIndex].Time = Me.Level.TimeSeconds; // Le temps de jeu actuel
	LocationIndex = (LocationIndex + 1) % ArrayCount(PreviousLocations);
}

function PawnRelated(float Delta)
{
	local Pawn Target;

	if(CurrentTarget != None)
	{
		if(!VisibleTarget(CurrentTarget) || !ValidTarget(CurrentTarget))
		{
			CurrentTarget = None;
		}
	}

	if(CurrentTarget == None)
	{
		foreach Me.Level.AllActors(Class'Pawn', Target)
		{
			if ( ValidTarget(Target) )
			{	
				if ( VisibleTarget(Target) )
				{	
					if(CurrentTarget == None)
					{
						CurrentTarget = Target;
					}
					if ( VSize(Target.Location - Me.Location) < VSize(CurrentTarget.Location - Me.Location) )
					{
						CurrentTarget = Target;
					}
				}
			}
		}
	}

	if (CurrentTarget == None)
	{
		// No pawn target, try to find a turret or assault objective to shoot at
		foreach Me.Level.AllActors(Class'Pawn', Target)
		{
			if (Target.Health > 0 && VisibleTarget(Target) && !Target.IsInState('DamagedState') && !Target.IsInState('Deactivated'))
			{
				if (Target.IsA('TeamCannon'))
				{
					if (!Me.GameReplicationInfo.bTeamGame || !TeamCannon(Target).SameTeamAs(Me.PlayerReplicationInfo.Team))
					{
						if (CurrentTarget == None || VSize(Target.Location - Me.Location) < VSize(CurrentTarget.Location - Me.Location))
							CurrentTarget = Target;
					}
				}
				else if (Target.IsA('FortStandard') && !FortStandard(Target).bTriggerOnly)
				{
					if (Me.Level.Game.IsA('Assault') && Me.PlayerReplicationInfo.Team != Assault(Me.Level.Game).Defender.TeamIndex)
					{
						if (CurrentTarget == None || VSize(Target.Location - Me.Location) < VSize(CurrentTarget.Location - Me.Location))
							CurrentTarget = Target;
					}
				}
			}
		}
	}

	if(CurrentTarget != None)
	{
    	UpdatePreviousLocations(CurrentTarget, Delta);
		SetPawnRotation(CurrentTarget, Delta);
	}
}



function bool VisibleTarget (Pawn Target)
{
	local float VectorsX[3];
	local float VectorsY[3];
	local float VectorsZ[3];
	local Vector Start, Check;
	local int x,y,z;

	if(Me.LineOfSightTo(Target) || Me.CanSee(Target))
	{
		return true;
	}

	Start = MuzzleCorrection(Target);

	VectorsX[0] = Target.Location.X + (-1.0 * Target.CollisionRadius);
	VectorsX[1] = Target.Location.X;
	VectorsX[2] = Target.Location.X + (1.0 * Target.CollisionRadius);

	VectorsY[0] = Target.Location.Y + (-1.0 * Target.CollisionRadius);
	VectorsY[1] = Target.Location.Y;
	VectorsY[2] = Target.Location.Y + (1.0 * Target.CollisionRadius);

	VectorsZ[0] = Target.Location.Z + (-1.0 * Target.CollisionHeight);
	VectorsZ[1] = Target.Location.Z;
	VectorsZ[2] = Target.Location.Z + (1.0 * Target.CollisionHeight);

	for(x=0; x<=2; x++)
	{
		for(y=0; y<=2; y++)
		{
			for(z=0; z<=2; z++)
			{
				Check.X = VectorsX[x];
				Check.Y = VectorsY[y];
				Check.Z = VectorsZ[z];
				if(Me.FastTrace(Check, Start)) 
				{
					return true;
				}
			}
		}
	}
}

function bool ValidTarget (Pawn Target)
{
	If(Target.IsA('ScriptedPawn')) //If is a monster (Monster Hunt)
	{
		if(ScriptedPawn(Target).AttitudeTo(Me) < 4 &&
		!Target.IsInState('Dying') && Target.Health > 0)
		{
			return true;
		}
	}

	If(bAimPlayers)
	{
		if ( 
			(Target != None) && // Target variable is Not Empty
			(Target != Me) && //Target is Not ower own Player
			(!Target.bHidden) && // Target is Not hidden
			(Target.bIsPlayer) && // Target is an actual player
			(Target.Health > 0) && // Target is still alive
			(!Target.IsInState('Dying')) && // Target is Not Dying
			(!Target.IsA('StaticPawn')) && // Target is Not a Static Box or Crate
			(Target.PlayerReplicationInfo != None) && // Target has Replication info
			(!Target.PlayerReplicationInfo.bIsSpectator) && // Target is Not a spectator
			(!Target.PlayerReplicationInfo.bWaitingPlayer) // Target is Not somebody that is pending to get into the game
		)
		{
			if ( Me.GameReplicationInfo.bTeamGame )
			{
				// Check to see if Target is on the Opposit Team
				if ( Target.PlayerReplicationInfo.Team != Me.PlayerReplicationInfo.Team )
				{
					Return True;
				}
				else
				{
					Return False;
				}
			}
			else
			{
				Return True;
				// If it is not a Teambased game every Target is an Enemy
			}
		}
		else
		{
			Return False;
		}
	}		
}

function SetPawnRotation (Pawn Target, float Delta)
{
	local Vector Start;
	local Vector End;
	local Vector Predict;
	local Projectile Ball;
	local Pawn BallTarget;

	
	Start=MuzzleCorrection(Target);
	End=Target.Location;
	End += GetTargetOffset(Target);

	Predict = End + BulletSpeedCorrection(Target);

	if(Me.FastTrace(Predict, Start))
	{
		End = Predict;
	}

	if(Me.Weapon.IsA('ShockRifle') || Me.Weapon.IsA('ASMD'))
	{
		foreach Me.Level.AllActors(Class'Projectile', Ball)
		{
			if(Ball.IsA('ShockProj') || Ball.IsA('TazerProj'))
			{
				foreach Me.Level.AllActors(Class'Pawn', BallTarget)
				{	
					if (ValidTarget(BallTarget) && VSize(BallTarget.Location - Ball.Location) < (250 + BallTarget.CollisionRadius) && Me.LineOfSightTo(Ball))
					{	
						End = Ball.Location;
						break;
					}						
				}
			}
		}
	}

	SetMyRotation(End,Start,Delta);
}

function Vector MuzzleCorrection (Pawn Target)
{
	local Vector Correction,X,Y,Z;

	GetAxes(Me.ViewRotation,X,Y,Z);

	if (Me.Weapon != None)
	{
		Correction = Me.Location + Me.Weapon.CalcDrawOffset() + Me.Weapon.FireOffset.X * X + Me.Weapon.FireOffset.Y * Y + Me.Weapon.FireOffset.Z * Z;
	}
	
	return Correction;
}

function Vector GetTargetOffset (Pawn Target)
{
	local Vector Start;
	local Vector End;
	local Vector vAuto;
	local Actor HitActor;

	local Vector HitLocation, HitNormal;

	Start=MuzzleCorrection(Target);
	End=Target.Location;
	vAuto = vect(0,0,0);

	if(bUseSplash && 
	((LastFireMode == 1 && Me.Weapon.bRecommendSplashDamage) || (LastFireMode == 2 && Me.Weapon.bRecommendAltSplashDamage)) && 
	Target.Velocity != vect(0,0,0) &&
	Target.Velocity.Z == 0)
	{
		vAuto.Z = -0.9 * Target.CollisionHeight;
	}
	else
	{
		vAuto.Z = 0.5 * Target.CollisionHeight;
	}
	

	HitActor = Me.Trace(HitLocation, HitNormal, End + vAuto, Start);
	if (HitActor != None && (HitActor == Target || HitActor.IsA('Projectile')) ) //if can hit target (and ignore projectile between player and target)
	{
		return vAuto;
	}

	HitActor = Me.Trace(HitLocation, HitNormal, End + AltOffset, Start);
	if(HitActor != None && (HitActor == Target || HitActor.IsA('Projectile')))
	{
		return AltOffset;
	}

	AltOffset.X = RandRange(-1.0, 1.0) * Target.CollisionRadius;
	AltOffset.Y = RandRange(-1.0, 1.0) * Target.CollisionRadius;
	AltOffset.Z = RandRange(-1.0, 1.0) * Target.CollisionHeight;
}

function Vector CalculateCustomVelocity(Pawn Target)
{
    local Vector Velocity, AverageVelocity;
    local float TimeDifference;
	local int i, ValidSamples;
    
    AverageVelocity = vect(0,0,0);
	ValidSamples = 0;
    
    for(i=0; i < ArrayCount(PreviousLocations)-1; i++)
    {
        TimeDifference = PreviousLocations[(LocationIndex+i+1)% ArrayCount(PreviousLocations)].Time - PreviousLocations[(LocationIndex+i)% ArrayCount(PreviousLocations)].Time;
    	if (TimeDifference > 0)
    	{
	    	Velocity = (PreviousLocations[(LocationIndex+i+1)% ArrayCount(PreviousLocations)].Location - PreviousLocations[(LocationIndex+i)% ArrayCount(PreviousLocations)].Location) / TimeDifference;
	    	AverageVelocity += Velocity;
			ValidSamples++;
        }
    }

	if (ValidSamples > 0)
	{
		AverageVelocity = AverageVelocity / ValidSamples;
	}
	else
	{
		AverageVelocity = vect(0,0,0);
	}

    return AverageVelocity;
}

function Vector CalculateCustomAcceleration(Pawn Target)
{
    local Vector Acceleration, AverageAcceleration, CurrentVelocity, PreviousVelocity;
    local float TimeDifferenceCurrent, TimeDifferencePrevious;
	local int i, CurrentDataIndex, PreviousDataIndex, PreviousPreviousDataIndex, ValidSamples;

    AverageAcceleration = vect(0,0,0);
	ValidSamples = 0;

    for(i = 0; i < ArrayCount(PreviousLocations) - 2; i++)
    {
        CurrentDataIndex = (LocationIndex - 1 - i + ArrayCount(PreviousLocations)) % ArrayCount(PreviousLocations);
        PreviousDataIndex = (LocationIndex - 2 - i + ArrayCount(PreviousLocations)) % ArrayCount(PreviousLocations);
        PreviousPreviousDataIndex = (LocationIndex - 3 - i + ArrayCount(PreviousLocations)) % ArrayCount(PreviousLocations);

        if (CurrentDataIndex >= 0 && CurrentDataIndex < ArrayCount(PreviousLocations) &&
            PreviousDataIndex >= 0 && PreviousDataIndex < ArrayCount(PreviousLocations) &&
            PreviousPreviousDataIndex >= 0 && PreviousPreviousDataIndex < ArrayCount(PreviousLocations))
        {
            TimeDifferenceCurrent  = PreviousLocations[CurrentDataIndex].Time - PreviousLocations[PreviousDataIndex].Time;
            TimeDifferencePrevious = PreviousLocations[PreviousDataIndex].Time - PreviousLocations[PreviousPreviousDataIndex].Time;

            if (TimeDifferenceCurrent > 0 && TimeDifferencePrevious > 0)
            {
                CurrentVelocity  = (PreviousLocations[CurrentDataIndex].Location - PreviousLocations[PreviousDataIndex].Location) / TimeDifferenceCurrent;
                PreviousVelocity = (PreviousLocations[PreviousDataIndex].Location - PreviousLocations[PreviousPreviousDataIndex].Location) / TimeDifferencePrevious;

                Acceleration = (CurrentVelocity - PreviousVelocity) / ((TimeDifferenceCurrent + TimeDifferencePrevious) / 2);
                AverageAcceleration += Acceleration;
				ValidSamples++;
            }
        }
    }

	if (ValidSamples > 0)
    {
		AverageAcceleration = AverageAcceleration / ValidSamples;
    }
    else
    {
        AverageAcceleration = vect(0,0,0);
    }


    return AverageAcceleration;
}

function Vector BulletSpeedCorrection (Pawn Target)
{
    local float BulletSpeed, TargetDist, ToF;
    local float GravZ, ZOffset;
    local Vector Correction, Start, AimSpot, CustomVelocity, CustomAcceleration;
	local Class<Projectile> ProjectileClass;

    Start = MuzzleCorrection(Target);

	if ( (LastFireMode == 1) &&  !Me.Weapon.bInstantHit )
	{
		ProjectileClass = Me.Weapon.ProjectileClass;
		BulletSpeed = ProjectileClass.default.speed;
	}

	if ( (LastFireMode == 2) &&  !Me.Weapon.bAltInstantHit )
	{
		ProjectileClass = Me.Weapon.AltProjectileClass;
		BulletSpeed = ProjectileClass.default.speed;
	}

    if (Me.Weapon != None)
    {
        if ( (LastFireMode == 1) &&  !Me.Weapon.bInstantHit )
        {
            ProjectileClass = Me.Weapon.ProjectileClass;
            BulletSpeed = ProjectileClass.default.speed;
        }

        if ( (LastFireMode == 2) &&  !Me.Weapon.bAltInstantHit )
        {
            ProjectileClass = Me.Weapon.AltProjectileClass;
            BulletSpeed = ProjectileClass.default.speed;
        }

        if ( BulletSpeed > 0 )
        {
            TargetDist = VSize(Target.Location - Start);
            ToF = TargetDist / BulletSpeed;
			CustomVelocity = CalculateCustomVelocity(Target);
			CustomAcceleration = CalculateCustomAcceleration(Target);

			if (ProjectileClass.default.Physics == PHYS_Falling)
			{
				// All PHYS_Falling projectiles get Velocity.Z += 200 on top of aimed direction, plus gravity
				// ZOffset = net Z deviation of the projectile vs a straight-line path at time ToF
				GravZ = Target.Region.Zone.ZoneGravity.Z;
				ZOffset = 200.0 * ToF + 0.5 * GravZ * Square(ToF);
			}

            AimSpot = Target.Location + CustomVelocity*ToF + CustomAcceleration * Square(ToF) * 0.5;

			if(Me.FastTrace(AimSpot, Start))
			{
				TargetDist = VSize(AimSpot - Start);
				ToF = (ToF + (TargetDist / BulletSpeed)) / 2;

				Correction = CustomVelocity * ToF + CustomAcceleration * Square(ToF) * 0.5;

				// Recompute arc compensation with refined ToF
				if (ZOffset != 0)
				{
					ZOffset = 200.0 * ToF + 0.5 * GravZ * Square(ToF);
					Correction.Z -= ZOffset;
				}

				return Correction;
			}
        }
    }

    return vect(0,0,0);
}

function SetMyRotation (Vector End, Vector Start, float Delta)
{
    local Rotator Rot;

	Rot=Normalize(rotator(End - Start));

	if(bRotateSlow)
	{
		Rot=RotateSlow(Normalize(Me.ViewRotation),Rot);
	}
	
	Me.ViewRotation=Rot;
}

function Rotator RotateSlow (Rotator RotA, Rotator RotB)
{
	local Rotator RotC;
	local int Pitch;
	local int Yaw;
	local int Roll;
	local bool Bool1;
	local bool Bool2;
	local bool Bool3;

	Bool1=Abs(RotA.Pitch - RotB.Pitch) <= MySetSlowSpeed;
	Bool2=Abs(RotA.Yaw - RotB.Yaw) <= MySetSlowSpeed;
	Bool3=Abs(RotA.Roll - RotB.Roll) <= MySetSlowSpeed;
	
	if ( RotA.Pitch < RotB.Pitch )
	{
		Pitch=1;
	} 
	else 
	{
		Pitch=-1;
	}
	
	if ( (RotA.Yaw > 0) && (RotB.Yaw > 0) )
	{
		if ( RotA.Yaw < RotB.Yaw )
		{
			Yaw=1;
		} 
		else 
		{
			Yaw=-1;
		}
	} 
	else 
	{
		if ( (RotA.Yaw < 0) && (RotB.Yaw < 0) )
		{
			if ( RotA.Yaw < RotB.Yaw )
			{
				Yaw=1;
			} 
			else 
			{
				Yaw=-1;
			}
		} 
		else 
		{
			if ( (RotA.Yaw < 0) && (RotB.Yaw > 0) )
			{
				if ( Abs(RotA.Yaw) + RotB.Yaw < 32768 )
				{
					Yaw=1;
				} 
				else 
				{
					Yaw=-1;
				}
			} 
			else 
			{
				if ( (RotA.Yaw > 0) && (RotB.Yaw < 0) )
				{
					if ( RotA.Yaw + Abs(RotB.Yaw) < 32768 )
					{
						Yaw=-1;
					} 
					else 
					{
						Yaw=1;
					}
				}
			}
		}
	}
	
	if ( RotA.Roll < RotB.Roll )
	{
		Roll=1;
	} 
	else 
	{
		Roll=-1;
	}
	
	if ( !Bool1 )
	{
		RotC.Pitch=RotA.Pitch + Pitch * MySetSlowSpeed;
	} 
	else 
	{
		RotC.Pitch=RotB.Pitch;
	}
	
	if ( !Bool2 )
	{
		RotC.Yaw=RotA.Yaw + Yaw * MySetSlowSpeed;
	} 
	else 
	{
		RotC.Yaw=RotB.Yaw;
	}
	
	if ( !Bool3 )
	{
		RotC.Roll=RotA.Roll + Roll * MySetSlowSpeed;
	}
	else 
	{
		RotC.Roll=RotB.Roll;
	}
	
	return Normalize(RotC);
}

//================================================================================
// UI
//================================================================================

function DrawMySettings (Canvas Canvas)
{
	local string Str[10], Str2[10];
	local int i, posY;

	Canvas.Font = Canvas.SmallFont;
	posY = Canvas.ClipY / 2;
	
	Str[0] = "[NixxConsole]";
	Str[1] = "----------";
	Str[2] = "AutoAim  : " $ String(bAutoAim);
	Str[3] = "Use Splash  : " $ String(bUseSplash);
	Str[4] = "Rotate Slow  : " $ String(bRotateSlow);
	Str[5] = "Aim Players  : " $ String(bAimPlayers);
	Str[6] = "----------";
	Str[7] = "RotationSpeed  : " $ String(MySetSlowSpeed);
	Str[8] = "FireMode  : " $ String(LastFireMode);
	Str[9] = "----------";

	for( i = 0;i < ArrayCount(Str);i++ )
	{			
		Canvas.SetPos(20, posY);
		Canvas.DrawText(Str[i]);
		posY += 20;
	}

	/////////////////////////////////
	// DEBUG
	/////////////////////////////////

	if( bDebug )
	{
		Str2[0] = "---DEBUG---";
		Str2[1] = "bFire  : " $ String(Me.bFire);
		Str2[2] = "bAltFire  : " $ String(Me.bAltFire);
		Str2[3] = "-----------";
		Str2[4] = "-----------";
		Str2[5] = "-----------";
		Str2[6] = "-----------";
		Str2[7] = "-----------";
		Str2[8] = "-----------";
		Str2[9] = "-----------";

		for( i = 0; i < ArrayCount(Str2);i++ )
		{			
			Canvas.SetPos(20, posY);
			Canvas.DrawText(Str2[i]);
			posY += 20;
		}
	}
}

// //================================================================================
// // DODGE
// //================================================================================

function TryDodge()
{
	// Not implemented
}

//================================================================================
// OTHERS FUNCTIONS.
//================================================================================

function ReplaceLadderTeam()
{
	local Inventory Inv;
	local LadderInventory LadderObj;

	if ( Me == None )
	return;

	// Find LadderInventory on the player
	for ( Inv = Me.Inventory; Inv != None; Inv = Inv.Inventory )
	{
		if ( Inv.IsA('LadderInventory') )
		{
			LadderObj = LadderInventory(Inv);
			break;
		}
	}

	if ( LadderObj != None && LadderObj.Team != class'NixxTeamInfo' )
	{
		LadderObj.Team = class'NixxTeamInfo';
	}
}

function CustomLadderInv()
{
	ReplaceLadderTeam();

	if ( !Me.IsA('TBoss') )
	{
		Me.UpdateURL("Class", "BotPack.TBoss", true);
		Me.UpdateURL("Skin", "BossSkins.Boss", true);
		Me.UpdateURL("Face", "BossSkins.Xan", true);
		Me.UpdateURL("Voice", "BotPack.VoiceBoss", true);
		
		Me.Level.ServerTravel("?Restart", true);
	}
}

// Enumerate all installed maps matching a prefix (e.g. "DM-"), skipping tutorials.
function CollectMaps(string MapPrefix)
{
	local string FirstMap, NextMap;

	NumCollectedMaps = 0;
	FirstMap = Me.GetMapName(MapPrefix, "", 0);

	if (FirstMap == "")
		return;

	if (InStr(Caps(FirstMap), "TUTORIAL") == -1)
	{
		CollectedMaps[NumCollectedMaps] = FirstMap;
		NumCollectedMaps++;
	}

	NextMap = Me.GetMapName(MapPrefix, FirstMap, 1);
	while (NextMap != "" && !(NextMap ~= FirstMap) && NumCollectedMaps < ArrayCount(CollectedMaps))
	{
		if (InStr(Caps(NextMap), "TUTORIAL") == -1)
		{
			CollectedMaps[NumCollectedMaps] = NextMap;
			NumCollectedMaps++;
		}
		NextMap = Me.GetMapName(MapPrefix, NextMap, 1);
	}
}

// Fisher-Yates shuffle of the CollectedMaps buffer.
function ShuffleMaps()
{
	local int i, j;
	local string Temp;

	for (i = NumCollectedMaps - 1; i > 0; i--)
	{
		j = Rand(i + 1);
		Temp = CollectedMaps[i];
		CollectedMaps[i] = CollectedMaps[j];
		CollectedMaps[j] = Temp;
	}
}

function int FillLadder(class<Ladder> L, string MapPrefix)
{
	local int i, j, OriginalMatches, Replaced;
	local string MapFile, Title;

	OriginalMatches = L.default.Matches;
	j = 0; // index into CollectedMaps

	for (i = 0; i < OriginalMatches && j < NumCollectedMaps; i++)
	{
		// Skip tutorial maps — keep them in their original ladder slot
		if (InStr(Caps(L.default.Maps[i]), "TUTORIAL") != -1
			|| InStr(Caps(L.default.MapTitle[i]), "TUTORIAL") != -1)
			continue;

		// GetMapName returns "DM-Tempest.unr"; strip prefix to get "Tempest.unr"
		MapFile = Mid(CollectedMaps[j], Len(MapPrefix));
		Title   = Left(MapFile, InStr(MapFile, "."));

		L.default.Maps[i]           = MapFile;
		L.default.MapTitle[i]       = Title;
		L.default.MapAuthors[i]     = "";
		L.default.MapDescription[i] = "Randomized match on " $ Title $ ".";

		j++;
	}

	Replaced = j;
	return Replaced;
}

function Msg (string Message)
{
	if ( Me != None )
	{
		Me.ClientMessage(Message);
	}
}


//================================================================================
// COMMANDS.
//================================================================================

exec function doAutoAim ()
{
	bAutoAim = !bAutoAim;
	Msg("AutoAim = " $ string(bAutoAim));
}

exec function SetRotationSpeed(int num)
{
	MySetSlowSpeed = num;

	Msg("Rotation Speed = " $ string(MySetSlowSpeed));
}

exec function IncreaseSpeed()
{
	if(MySetSlowSpeed < 0)
	{
		MySetSlowSpeed = 0;
	}
	else
	{
		MySetSlowSpeed += 100;
	}

	Msg("Rotation Speed = " $ string(MySetSlowSpeed));
}

exec function ReduceSpeed()
{
	if(MySetSlowSpeed <= 0)
	{
		MySetSlowSpeed = 0;
	}
	else
	{
		MySetSlowSpeed -= 100;
	}

	Msg("Rotation Speed = " $ string(MySetSlowSpeed));
}

exec function UseSplash()
{
	bUseSplash = !bUseSplash;
	Msg("Use Splash = " $ string(bUseSplash));
}

exec function UseRotateSlow()
{
	bRotateSlow = !bRotateSlow;
	Msg("Rotate Slow = "$ string(bRotateSlow));
}

exec function AimPlayers()
{
	bAimPlayers = !bAimPlayers;
	Msg("bAimPlayers = "$ string(bAimPlayers));
}

exec function UseDebug()
{
	bDebug = !bDebug;
	Msg("bDebug = "$string(bDebug));
}

exec function SuperBotTeam()
{
	local Pawn Target;
	
	foreach Me.Level.AllActors(Class'Pawn', Target)
	{
		
		if 
		( 
			(Target != None) && // Target variable is Not Empty
			(Target != Me) && //Target is Not ower own Player
			(Target.PlayerReplicationInfo != None) && // Target has Replication info
			(!Target.PlayerReplicationInfo.bIsSpectator) && // Target is Not a spectator
			(!Target.PlayerReplicationInfo.bWaitingPlayer) && // Target is Not somebody that is pending to get into the game
			(Me.GameReplicationInfo.bTeamGame) &&
			(Target.PlayerReplicationInfo.Team == Me.PlayerReplicationInfo.Team)
		)
		{
			Bot(Target).CombatStyle = RandRange(-1,1); //Xan Style
			Bot(Target).BaseAggressiveness = FRand();
			Bot(Target).Aggressiveness = FRand();
			Bot(Target).Skill = 7;
			Bot(Target).Accuracy = 1;
			Bot(Target).bJumpy = True;
			Bot(Target).Alertness = 1;
			Bot(Target).CampingRate = FRand();
			Bot(Target).StrafingAbility = 1;
		}
	}
	Msg("SuperBot Team on");
	
}

exec function GetSkills()
{
	local Pawn Target;

	foreach Me.Level.AllActors(Class'Pawn', Target)
	{
		
		if 
		( 
			(Target != None) && // Target variable is Not Empty
			(Target != Me) && //Target is Not ower own Player
			(Target.PlayerReplicationInfo != None) && // Target has Replication info
			(!Target.PlayerReplicationInfo.bIsSpectator) && // Target is Not a spectator
			(!Target.PlayerReplicationInfo.bWaitingPlayer) // Target is Not somebody that is pending to get into the game
		)
		{
			Msg("NAME = "$Target.PlayerReplicationInfo.PlayerName);
			Msg("Skill : "$Bot(Target).Skill);
			Msg("Accuracy : "$Bot(Target).Accuracy);
			Msg("bJumpy : "$Bot(Target).bJumpy);
			Msg("Alertness : "$Bot(Target).Alertness);
			Msg("CampingRate : "$Bot(Target).CampingRate);
			Msg("StrafingAbility : "$Bot(Target).StrafingAbility);
			Msg("BaseAggressiveness : "$Bot(Target).BaseAggressiveness);
			Msg("Aggressiveness : "$Bot(Target).Aggressiveness);
		}
	}
}


exec function GodModeTeam(int Apply)
{
	local Pawn Target;

	if( Apply == 1 )
	{
		foreach Me.Level.AllActors(Class'Pawn', Target)
		{
			
			if 
			( 
				(Target != None) && // Target variable is Not Empty
				(Target != Me) && //Target is Not ower own Player
				(Target.PlayerReplicationInfo != None) && // Target has Replication info
				(!Target.PlayerReplicationInfo.bIsSpectator) && // Target is Not a spectator
				(!Target.PlayerReplicationInfo.bWaitingPlayer) && // Target is Not somebody that is pending to get into the game
				(Me.GameReplicationInfo.bTeamGame) &&
				(Target.PlayerReplicationInfo.Team == Me.PlayerReplicationInfo.Team)
			)
			{
				Target.ReducedDamageType = 'All';
			}
		}
		Msg("God Mode Team on");
	}
	else if(Apply == 0)
	{
		foreach Me.Level.AllActors(Class'Pawn', Target)
		{
			if 
			( 
				(Target != None) && // Target variable is Not Empty
				(Target != Me) && //Target is Not ower own Player
				(Target.PlayerReplicationInfo != None) && // Target has Replication info
				(!Target.PlayerReplicationInfo.bIsSpectator) && // Target is Not a spectator
				(!Target.PlayerReplicationInfo.bWaitingPlayer) && // Target is Not somebody that is pending to get into the game
				(Me.GameReplicationInfo.bTeamGame) &&
				(Target.PlayerReplicationInfo.Team == Me.PlayerReplicationInfo.Team)
			)
			{
				Target.ReducedDamageType = '';
			}
		}
		Msg("God Mode Team off");
	}
}

exec function RandomizeLadders()
{
	local int NumDM, NumCTF, NumDOM, NumAS, NumChal;

	if (Me == None)
	{
		Msg("Player not available.");
		return;
	}

	// ----- Deathmatch -----
	CollectMaps("DM-");
	ShuffleMaps();
	NumDM = FillLadder(class'LadderDM', "DM-");
	FillLadder(class'LadderDMGOTY', "DM-");

	// ----- Challenge (also DM- maps, re-shuffle for different set) -----
	ShuffleMaps();
	NumChal = FillLadder(class'LadderChal', "DM-");

	// ----- Capture the Flag -----
	CollectMaps("CTF-");
	ShuffleMaps();
	NumCTF = FillLadder(class'LadderCTF', "CTF-");
	FillLadder(class'LadderCTFGOTY', "CTF-");

	// ----- Domination -----
	CollectMaps("DOM-");
	ShuffleMaps();
	NumDOM = FillLadder(class'LadderDOM', "DOM-");

	// ----- Assault -----
	CollectMaps("AS-");
	ShuffleMaps();
	NumAS = FillLadder(class'LadderAS', "AS-");

	Msg("Ladders randomized! DM:" $ NumDM $ " CTF:" $ NumCTF $ " DOM:" $ NumDOM $ " AS:" $ NumAS $ " Chal:" $ NumChal);
}

exec function ShowOverlay()
{
	bShowOverlay = !bShowOverlay;
	Msg("bShowOverlay = "$string(bShowOverlay));
}

// exec function RandomDest()
// {
// 	NixxBoss(Me).PathGoal = Me.FindRandomDest().Location;
// }

// exec function Stop()
// {
// 	NixxBoss(Me).PathGoal = vect(0,0,0);
// }

defaultproperties
{
	bAutoAim=True
	MySetSlowSpeed=2000
	bUseSplash=True
	bAimPlayers=True
	bShowOverlay=True
	LastFireMode=1
}