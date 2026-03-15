class NixxTeamInfo expands RatedTeamInfo;

function Individualize( Bot NewBot, int n, int NumBots, bool bEnemy, float BaseDifficulty)
{
      Super.Individualize(NewBot, n, NumBots, bEnemy, BaseDifficulty);

      NewBot.CombatStyle = RandRange(-1,1);
      NewBot.BaseAggressiveness = FRand();
      NewBot.Aggressiveness = FRand();
      NewBot.InitializeSkill(7);
      NewBot.Accuracy = 1;
      NewBot.bJumpy = True;
      NewBot.Alertness = 1;
      NewBot.CampingRate = FRand();
      NewBot.StrafingAbility = 1;
}

defaultproperties
{
      TeamName="The Corrupt"
      TeamBio="An elite squad of cybernetic warriors, forged in the heat of the Tournament. Led from the shadows, The Corrupt fights with ruthless precision and unmatched coordination."
      TeamSymbol=Texture'EpicCustomModels.TCowMeshSkins.AtomicCowFace'
      BotNames(0)="Vector"
      BotNames(1)="Cathode"
      BotNames(2)="Matrix"
      BotNames(3)="Fury"
      BotNames(4)="Lilith"
      BotNames(5)="Tensor"
      BotNames(6)=""
      BotNames(7)=""
      BotClassifications(0)="Warrior"
      BotClassifications(1)="Warrior"
      BotClassifications(2)="Warrior"
      BotClassifications(3)="Warrior"
      BotClassifications(4)="Warrior"
      BotClassifications(5)="Warrior"
      BotClassifications(6)=""
      BotClassifications(7)=""
      BotClasses(0)="BotPack.TMale2Bot"
      BotClasses(1)="BotPack.TFemale2Bot"
      BotClasses(2)="BotPack.TMale2Bot"
      BotClasses(3)="BotPack.TFemale2Bot"
      BotClasses(4)="BotPack.TFemale2Bot"
      BotClasses(5)="BotPack.TMale2Bot"
      BotClasses(6)=""
      BotClasses(7)=""
      BotSkins(0)="hkil"
      BotSkins(1)="fwar"
      BotSkins(2)="hkil"
      BotSkins(3)="fwar"
      BotSkins(4)="fwar"
      BotSkins(5)="hkil"
      BotSkins(6)=""
      BotSkins(7)=""
      BotFaces(0)="Vector"
      BotFaces(1)="Cathode"
      BotFaces(2)="Matrix"
      BotFaces(3)="Fury"
      BotFaces(4)="Lilith"
      BotFaces(5)="Tensor"
      BotFaces(6)=""
      BotFaces(7)=""
      BotBio(0)=""
      BotBio(1)=""
      BotBio(2)=""
      BotBio(3)=""
      BotBio(4)=""
      BotBio(5)=""
      BotBio(6)=""
      BotBio(7)=""
      MaleClass=Class'Botpack.TMale2'
      MaleSkin="SoldierSkins.hkil"
      FemaleClass=Class'Botpack.TFemale2'
      FemaleSkin="SGirlSkins.fwar"
}
