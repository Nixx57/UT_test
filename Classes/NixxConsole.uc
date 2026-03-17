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
var config bool bSpawnMonsters;

var float SpawnMonsterTimer;

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

var PositionData PreviousLocations[32];
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

	if (bSpawnMonsters && Me != None)
	{
		SpawnMonsterTimer -= Delta;
		if (SpawnMonsterTimer <= 0)
		{
			SpawnMonsterTimer = 10.0;
			SpawnRandomMonster();
		}
	}

	Begin(Delta);
}

//================================================================================
// MAIN BOT.
//================================================================================
function ResetLocationBuffer()
{
	local int i;
	LocationIndex = 0;
	for (i = 0; i < ArrayCount(PreviousLocations); i++)
    {
        PreviousLocations[i].Location = vect(0,0,0);
        PreviousLocations[i].Time = 0;
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
	local Pawn OldTarget;

	OldTarget = CurrentTarget;

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
					if (Me.Level.Game != None && Me.Level.Game.IsA('Assault') && Me.PlayerReplicationInfo.Team != Assault(Me.Level.Game).Defender.TeamIndex)
					{
						if (CurrentTarget == None || VSize(Target.Location - Me.Location) < VSize(CurrentTarget.Location - Me.Location))
							CurrentTarget = Target;
					}
				}
			}
		}
	}

	if (CurrentTarget != OldTarget)
		ResetLocationBuffer();

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

	return false;
}

function bool ValidTarget (Pawn Target)
{
	If(Target.IsA('ScriptedPawn')) //If is a monster (Monster Hunt)
	{
		if((ScriptedPawn(Target).AttitudeTo(Me) < 4 && ScriptedPawn(Target).AttitudeTo(Me) != 0) &&
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
	local Vector Start, End, vAuto, HitLocation, HitNormal, extent;
	local Actor HitActor;

	Start=MuzzleCorrection(Target);
	End=Target.Location;
	vAuto = vect(0,0,0);

	if(bUseSplash && 
	((LastFireMode == 1 && Me.Weapon.bRecommendSplashDamage) || (LastFireMode == 2 && Me.Weapon.bRecommendAltSplashDamage)) && 
	Target.Velocity != vect(0,0,0) &&
	Target.Velocity.Z == 0)
	{
		vAuto.Z = -0.75 * Target.CollisionHeight;
	}
	else
	{
		vAuto.Z = 0.5 * Target.CollisionHeight;
	}

	if (Me.Weapon != None && ((LastFireMode == 1 && !Me.Weapon.bInstantHit) || (LastFireMode == 2 && !Me.Weapon.bAltInstantHit)))
	{
		if (LastFireMode == 1 && Me.Weapon.ProjectileClass != None)
		{
			extent.X = Me.Weapon.ProjectileClass.default.CollisionRadius;
			extent.Y = Me.Weapon.ProjectileClass.default.CollisionRadius;
			extent.Z = Me.Weapon.ProjectileClass.default.CollisionHeight;
		}
		else if (LastFireMode == 2 && Me.Weapon.AltProjectileClass != None)
		{
			extent.X = Me.Weapon.AltProjectileClass.default.CollisionRadius;
			extent.Y = Me.Weapon.AltProjectileClass.default.CollisionRadius;
			extent.Z = Me.Weapon.AltProjectileClass.default.CollisionHeight;
		}
	}

	HitActor = Me.Trace(HitLocation, HitNormal, End + vAuto, Start, true, extent);
	if (HitActor != None && (HitActor == Target || HitActor.IsA('Projectile')) ) //if can hit target (and ignore projectile between player and target)
	{
		return vAuto;
	}

	HitActor = Me.Trace(HitLocation, HitNormal, End + AltOffset, Start, true, extent);
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
    local float TimeDifference, Weight, TotalWeight;
	local int i, ValidSamples;
    
    AverageVelocity = vect(0,0,0);
	ValidSamples = 0;
	TotalWeight = 0;
    
    for(i=0; i < ArrayCount(PreviousLocations)-1; i++)
    {
        TimeDifference = PreviousLocations[(LocationIndex+i+1)% ArrayCount(PreviousLocations)].Time - PreviousLocations[(LocationIndex+i)% ArrayCount(PreviousLocations)].Time;
    	if (TimeDifference > 0)
    	{
	    	Velocity = (PreviousLocations[(LocationIndex+i+1)% ArrayCount(PreviousLocations)].Location - PreviousLocations[(LocationIndex+i)% ArrayCount(PreviousLocations)].Location) / TimeDifference;
			Weight = float(i + 1); // newer samples get higher weight
	    	AverageVelocity += Velocity * Weight;
			TotalWeight += Weight;
			ValidSamples++;
        }
    }

	if (ValidSamples >= 3)
	{
		AverageVelocity = AverageVelocity / TotalWeight;
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
    local float TimeDifferenceCurrent, TimeDifferencePrevious, Weight, TotalWeight;
	local int i, CurrentDataIndex, PreviousDataIndex, PreviousPreviousDataIndex, ValidSamples;

    AverageAcceleration = vect(0,0,0);
	ValidSamples = 0;
	TotalWeight = 0;

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
				Weight = float(ArrayCount(PreviousLocations) - 1 - i); // i=0 is newest, gets highest weight
                AverageAcceleration += Acceleration * Weight;
				TotalWeight += Weight;
				ValidSamples++;
            }
        }
    }

	if (ValidSamples >= 3)
    {
		AverageAcceleration = AverageAcceleration / TotalWeight;
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
	local int iter;

    Start = MuzzleCorrection(Target);

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
				GravZ = Target.Region.Zone.ZoneGravity.Z;

			// Iterative ToF refinement (3 passes)
			AimSpot = Target.Location;
			for (iter = 0; iter < 3; iter++)
			{
				AimSpot = Target.Location + CustomVelocity * ToF + CustomAcceleration * Square(ToF) * 0.5;
				if (!Me.FastTrace(AimSpot, Start))
					break;
				TargetDist = VSize(AimSpot - Start);
				ToF = TargetDist / BulletSpeed;
			}

			Correction = CustomVelocity * ToF + CustomAcceleration * Square(ToF) * 0.5;

			// If predicted spot is behind a wall, halve the correction until valid
			while (!Me.FastTrace(Target.Location + Correction, Start))
			{
				Correction *= 0.5;
				if (VSize(Correction) < 1.0)
				{
					Correction = vect(0,0,0);
					break;
				}
			}

			if (Me.FastTrace(Target.Location + Correction, Start))
			{
				// Arc compensation for PHYS_Falling projectiles (+200 Z boost + gravity)
				if (GravZ != 0)
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
		Rot=RotateSlow(Normalize(Me.ViewRotation),Rot,Delta);
	}
	
	Me.ViewRotation=Rot;
}

function Rotator RotateSlow (Rotator RotA, Rotator RotB, float Delta)
{
	local Rotator RotC;
	local int Pitch;
	local int Yaw;
	local int Roll;
	local bool Bool1;
	local bool Bool2;
	local bool Bool3;
	local int Step;

	Step = MySetSlowSpeed * Delta * 60.0; // framerate-independent (normalized to 60fps)
	if (Step < 1)
		Step = 1;

	Bool1=Abs(RotA.Pitch - RotB.Pitch) <= Step;
	Bool2=Abs(RotA.Yaw - RotB.Yaw) <= Step;
	Bool3=Abs(RotA.Roll - RotB.Roll) <= Step;
	
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
		RotC.Pitch=RotA.Pitch + Pitch * Step;
	} 
	else 
	{
		RotC.Pitch=RotB.Pitch;
	}
	
	if ( !Bool2 )
	{
		RotC.Yaw=RotA.Yaw + Yaw * Step;
	} 
	else 
	{
		RotC.Yaw=RotB.Yaw;
	}
	
	if ( !Bool3 )
	{
		RotC.Roll=RotA.Roll + Roll * Step;
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
	Str[6] = "Spawn Monsters  : " $ String(bSpawnMonsters);
	Str[7] = "----------";
	Str[8] = "RotationSpeed  : " $ String(MySetSlowSpeed);
	Str[9] = "FireMode  : " $ String(LastFireMode);

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

	if( !Me.bAdmin && (Me.Level.Netmode != NM_Standalone) )
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

	if( !Me.bAdmin && (Me.Level.Netmode != NM_Standalone) )
		return;

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

function SpawnRandomMonster()
{
	local NavigationPoint Nav;
	local int NavCount, PickedIndex, i;
	local Vector SpawnLoc;
	local class<ScriptedPawn> MonsterClass;
	local ScriptedPawn Monster;
	local string MonsterNames[39];
	local int NumMonsters;

	if (Me == None)
		return;

	if( !Me.bAdmin && (Me.Level.Netmode != NM_Standalone) )
		return;

	MonsterNames[0]  = "UnrealShare.Brute";
	MonsterNames[1]  = "UnrealI.Behemoth";
	MonsterNames[2]  = "UnrealShare.LesserBrute";
	MonsterNames[3]  = "UnrealShare.Cow";
	MonsterNames[4]  = "UnrealShare.BabyCow";
	MonsterNames[5]  = "UnrealShare.Devilfish";
	MonsterNames[6]  = "UnrealShare.Fly";
	MonsterNames[7]  = "UnrealI.GasBag";
	MonsterNames[8]  = "UnrealI.GiantGasbag";
	MonsterNames[9]  = "UnrealI.Krall";
	MonsterNames[10] = "UnrealI.KrallElite";
	MonsterNames[11] = "UnrealI.LeglessKrall";
	MonsterNames[12] = "UnrealShare.Manta";
	MonsterNames[13] = "UnrealShare.CaveManta";
	MonsterNames[14] = "UnrealI.GiantManta";
	MonsterNames[15] = "UnrealI.Mercenary";
	MonsterNames[16] = "UnrealI.MercenaryElite";
	MonsterNames[17] = "UnrealShare.Nali";
	MonsterNames[18] = "UnrealShare.NaliPriest";
	MonsterNames[19] = "UnrealI.Pupae";
	MonsterNames[20] = "UnrealI.Queen";
	MonsterNames[21] = "UnrealShare.Skaarj";
	MonsterNames[22] = "UnrealI.SkaarjTrooper";
	MonsterNames[23] = "UnrealI.SkaarjGunner";
	MonsterNames[24] = "UnrealI.SkaarjInfantry";
	MonsterNames[25] = "UnrealI.SkaarjOfficer";
	MonsterNames[26] = "UnrealI.SkaarjSniper";
	MonsterNames[27] = "UnrealShare.SkaarjWarrior";
	MonsterNames[28] = "UnrealI.IceSkaarj";
	MonsterNames[29] = "UnrealI.SkaarjAssassin";
	MonsterNames[30] = "UnrealI.SkaarjBerserker";
	MonsterNames[31] = "UnrealI.SkaarjLord";
	MonsterNames[32] = "UnrealShare.SkaarjScout";
	MonsterNames[33] = "UnrealShare.Slith";
	MonsterNames[34] = "UnrealI.Squid";
	MonsterNames[35] = "UnrealShare.Tentacle";
	MonsterNames[36] = "UnrealI.Titan";
	MonsterNames[37] = "UnrealI.StoneTitan";
	MonsterNames[38] = "UnrealI.Warlord";
	NumMonsters = 39;

	// Count navigation points
	NavCount = 0;
	foreach Me.Level.AllActors(class'NavigationPoint', Nav)
	{
		NavCount++;
	}

	if (NavCount == 0)
		return;

	// Pick a random navigation point
	PickedIndex = Rand(NavCount);
	i = 0;
	foreach Me.Level.AllActors(class'NavigationPoint', Nav)
	{
		if (i == PickedIndex)
			break;
		i++;
	}

	// Pick a random monster class
	MonsterClass = class<ScriptedPawn>(DynamicLoadObject(MonsterNames[Rand(NumMonsters)], class'Class'));
	if (MonsterClass == None)
		return;

	// Spawn at nav point, offset Z by CollisionHeight so it doesn't clip into the floor
	SpawnLoc = Nav.Location;
	SpawnLoc.Z += MonsterClass.default.CollisionHeight;

	Monster = Me.Spawn(MonsterClass,,, SpawnLoc);
	if (Monster != None)
		Msg("Spawned " $ Monster.Class.Name);
	else
		Msg("Failed to spawn monster.");
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

exec function SpawnMonsters()
{
	bSpawnMonsters = !bSpawnMonsters;
	if (bSpawnMonsters)
		SpawnMonsterTimer = 10.0;
	Msg("SpawnMonsters = " $ string(bSpawnMonsters));
}

exec function ShowOverlay()
{
	bShowOverlay = !bShowOverlay;
	Msg("bShowOverlay = "$string(bShowOverlay));
}

defaultproperties
{
	bAutoAim=True
	MySetSlowSpeed=2000
	bUseSplash=True
	bAimPlayers=True
	bShowOverlay=True
	bSpawnMonsters=False
	LastFireMode=1
}