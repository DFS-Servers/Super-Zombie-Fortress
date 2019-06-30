// Plugin Version
#define PLUGIN_VERSION "2.3.0"
// 2.minor.fix

//
// Quick Settings
//
#define BACKSTABDURATION_FULL 5.5
#define BACKSTABDURATION_REDUCED 3.5
#define DISTANCE_GOO 4.0
#define TIME_GOO 7.0
#define GOO_INCREASE_RATE 2
#define PICKUP_COOLDOWN 1.25

//
// Global Variables/States
//
bool zf_bEnabled;
bool zf_bNewRound;
int zf_lastSurvivor;
bool g_bTriggerEntity[2048] = true;
Handle g_hGoo = INVALID_HANDLE;

//
// SDK Calls
//
Handle g_hSDKGetMaxHealth = INVALID_HANDLE;
Handle g_hSDKRemoveWearable = INVALID_HANDLE;
Handle g_hSDKEquipWearable = INVALID_HANDLE;
Handle g_hSDKGetEquippedWearable = INVALID_HANDLE;

//
// Cookies
//
Handle cookieNoMusicForPlayer;
Handle cookiePreferredTeam;
Handle cookieFirstTimeSurvivor;
Handle cookieFirstTimeZombie;
Handle cookieFirstTimeVersusTank;


//
// Round Variables/States
//
bool g_bRoundActive = false;
bool g_bFirstRound = true;
bool g_bCapturingLastPoint = false;
int g_StartTime = 0;
int g_AdditionalTime = 0;
int g_iControlPointsInfo[20][2];
int g_iControlPoints = 0;
// -- survivor related
int zf_spawnSurvivorsKilledCounter;
int zf_spawnZombiesKilledCounter;
int zf_spawnZombiesKilledSpree;
int zf_spawnZombiesKilledSurvivor[MAXPLAYERS+1] = 0;
int zf_pointsCaptured;
// -- infected related
bool g_bTankRefreshed = false;
bool g_bTankOnce = false;
bool g_bZombieRage = false;
bool g_bZombieRageAllowRespawn = false;
float g_fTankDamageDealt = 0.0;
float g_fZombieDamageScale = 1.0;
float g_flTankCooldown = 0.0;
float g_flRageCooldown = 0.0;
float g_flSelectSpecialCooldown = 0.0;
int g_iZombieTank = 0;
int g_iGooId = 0;
int g_iStartSurvivors = 0;
int g_iZombiesRespawnedSinceFrenzy = 0;

//
// Client Variables/State
//
int zf_hordeBonus[MAXPLAYERS+1];
int zf_rageTimer[MAXPLAYERS+1];
int g_iPreferredTeam[MAXPLAYERS+1] = 0;
int g_iHitBonusCombo[MAXPLAYERS+1] = 0;
int g_iStuckCount[MAXPLAYERS+1] = 0;
float g_flStopChatSpam[MAXPLAYERS+1] = 0.0;
float g_flSetSize[MAXPLAYERS+1] = 1.0;
bool zf_screamerNearby[MAXPLAYERS+1] = false;
bool g_bStartedAsZombie[MAXPLAYERS+1];
bool g_bBackstabbed[MAXPLAYERS+1] = false;
bool g_bInControlPoint[MAXPLAYERS+1] = false;
TFClassType g_tfClassLastSurvivorClass[MAXPLAYERS+1] = TFClass_Unknown;
int g_iPickupWeaponSlotFromSpawn[MAXPLAYERS+1] = -1;
// -- survivor related
int g_iCarryingItem[MAXPLAYERS+1] = -1;
int g_iMoraleSkipTicks[MAXPLAYERS+1] = 0;
int g_iSurvivorMorale[MAXPLAYERS+1] = 0;
float g_fDamageTakenLife[MAXPLAYERS+1] = 0.0;
float g_fDamageDealtLife[MAXPLAYERS+1] = 0.0;
float g_fDamageDealtAgainstTank[MAXPLAYERS+1] = 0.0;
float g_fLastCallout[MAXPLAYERS+1] = 0.0;
float g_fLastRarePickup[MAXPLAYERS+1] = 0.0;
float g_fLastPickup[MAXPLAYERS+1] = 0.0;
float g_fEscapePlanPostBoost[MAXPLAYERS+1] = 0.0;
// -- infected related
int g_iSpecialInfected[MAXPLAYERS+1] = 0;
int g_iNextSpecialInfected[MAXPLAYERS+1] = 0;
int g_iDamage[MAXPLAYERS+1] = 0;
int g_iKillsThisLife[MAXPLAYERS+1] = 0;
int g_iSuperHealth[MAXPLAYERS+1] = 0;
int g_iSuperHealthSubtract[MAXPLAYERS+1] = 0;
bool g_ShouldBacteriaPlay[MAXPLAYERS+1] = true;
bool g_bReplaceRageWithSpecialInfectedSpawn[MAXPLAYERS+1] = false;
int g_iSmokerBeamHits[MAXPLAYERS+1] = 0;
int g_iSmokerBeamHitVictim[MAXPLAYERS+1] = 0;
int g_iGooMultiplier[MAXPLAYERS+1] = 0;
bool g_bGooified[MAXPLAYERS+1] = false;
bool g_bHitOnce[MAXPLAYERS+1] = false;
bool g_bHopperIsUsingPounce[MAXPLAYERS+1] = false; // is hopper using pounce ability?

//
// Weapon IDs
//
// Scout
// -
// Soldier
#define ZFWEAP_ESCAPEPLAN 775
// Pyro
#define ZFWEAP_POWERJACK 214
// Demoman
#define ZFWEAP_EYELANDER 132
#define ZFWEAP_SKULLCUTTER 172
#define ZFWEAP_PERSIAN 404
#define ZFWEAP_HHHHEADTAKER 266
#define ZFWEAP_GOLFCLUB 482
#define ZFWEAP_FESTIVELANDER 1082
// Heavy
#define ZFWEAP_GRU 239
#define ZFWEAP_WARRIORSSPIRIT 310
#define ZFWEAP_FISTSOFSTEEL 331
#define ZFWEAP_MITTENS 656
#define ZFWEAP_FESTIVEGRU 1084
#define ZFWEAP_BREADBITES 1100
// Medic
#define ZFWEAP_OVERDOSE 412
// Engineer
// -
// Sniper
// -
// Spy
// -

//
// Offsets
//
static int oActiveWeapon;
static int oCloakMeter;
static int oResAmmo[3];
static int oClipAmmo;

//
// Cvar Handles
//
ConVar g_cvarVersion;
ConVar g_cvarForceOn;
ConVar g_cvarRatio;
ConVar g_cvarSwapOnPayload;
ConVar g_cvarSwapOnAttdef;
ConVar g_cvarTankHealth;
ConVar g_cvarTankHealthMin;
ConVar g_cvarTankHealthMax;
ConVar g_cvarTankTime;
ConVar g_cvarTankOnce;
ConVar g_cvarTankMinSpeed;
ConVar g_cvarTankMaxSpeed;
ConVar g_cvarFrenzyChance;
ConVar g_cvarFrenzyMaxRespawns;
ConVar g_cvarFrenzyTankChance;
ConVar g_cvarSpecialBonusHealth;
ConVar g_cvarMutationMinPlayers;
ConVar g_cvarMutationVoteRatio;
ConVar g_cvarMutationForceEnabled;
ConVar g_cvarMaxRareWeapons;
ConVar g_cvarMinSpawnWeapons;
ConVar g_cvarSurvivorHealthSpeedDrain;

//
// Global Timer Handles
//
Handle zf_tMain;
Handle zf_tMainFast;
Handle zf_tMainSlow;
Handle zf_tHoarde;
Handle zf_tDataCollect;

//
// ZF Class Objects
//
TFClassType[] ZF_SURVIVORS = {
	TFClass_Sniper,
	TFClass_Soldier,
	TFClass_DemoMan,
	TFClass_Medic,
	TFClass_Pyro,
	TFClass_Engineer
};
TFClassType[] ZF_ZOMBIES = {
	TFClass_Scout,
	TFClass_Heavy,
	TFClass_Spy
};
static const ZF_VALIDSURVIVOR[10] = {
	0,
	0, // Scout
	1, // Sniper
	1, // Soldier
	1, // Demoman
	1, // Medic
	0, // Heavy
	1, // Pyro
	0, // Spy
	1 // Engineer
};
static const int ZF_VALIDZOMBIE[10]	= {
	0,
	1, // Scout
	0, // Sniper
	0, // Soldier
	0, // Demoman
	0, // Medic
	1, // Heavy
	0, // Pyro
	1, // Spy
	0 // Engineer
};

//
// ZF Team / Round State
//
enum ZFRoundState
{
	RoundInit1,
	RoundInit2,
	RoundGrace,
	RoundActive,
	RoundPost
};
static ZFRoundState zf_roundState = RoundInit1;
int zf_zomTeam = view_as<int>(TFTeam_Blue);
int zf_surTeam = view_as<int>(TFTeam_Red);

//
// Music Types / Variables
//
#define MUSIC_DRUMS             0
#define MUSIC_SLAYER_MILD       1
#define MUSIC_SLAYER            2
#define MUSIC_TRUMPET           3
#define MUSIC_SNARE             4
#define MUSIC_BANJO             5
#define MUSIC_HEART_SLOW        6
#define MUSIC_HEART_MEDIUM      7
#define MUSIC_HEART_FAST        8
#define MUSIC_RABIES            9
#define MUSIC_DEAD              10
#define MUSIC_INCOMING          11
#define MUSIC_PREPARE           12
#define MUSIC_DROWN             13
#define MUSIC_TANK              14
#define MUSIC_LASTSTAND         15
#define MUSIC_NEARDEATH         16
#define MUSIC_NEARDEATH2        17
#define MUSIC_AWARD             18
#define MUSIC_LASTTENSECONDS    19
#define MUSIC_JARATE            20
#define MUSIC_DANGER            21
#define MUSIC_PREPARE_ZOMBIE    22
#define MUSIC_MAX               23
Handle g_hMusicTimer[MAXPLAYERS+1] = INVALID_HANDLE;
char g_strMusicLast[MAXPLAYERS+1][MUSIC_MAX][PLATFORM_MAX_PATH];
bool g_bNoMusicForClient[MAXPLAYERS+1] = false;
int g_iMusicCount[MUSIC_MAX] = 0;
int g_iMusicLevel[MAXPLAYERS+1] = 0;
int g_iMusicRandom[MAXPLAYERS+1][2];
int g_iMusicFull[MAXPLAYERS+1] = 0;

//
// Music States / Moods
//
Handle g_hMusicArray = INVALID_HANDLE;
Handle g_hFastRespawnArray = INVALID_HANDLE;
#define MUSIC_NONE                  0
#define MUSIC_INTENSE               1
#define MUSIC_MILD                  2
#define MUSIC_VERYMILD3             3
#define MUSIC_VERYMILD2             4
#define MUSIC_VERYMILD1             5
#define MUSIC_GOO                   6
#define MUSIC_TANKMOOD              7
#define MUSIC_LASTSTANDMOOD         8
#define MUSIC_PLAYERNEARDEATH       9
#define MUSIC_LASTTENSECONDSMOOD    10
#define MUSIC_JARATED               11

//
// Music Channels
//
#define CHANNEL_MUSIC_NONE      0
#define CHANNEL_MUSIC_DRUMS     350
#define CHANNEL_MUSIC_SLAYER    351
#define CHANNEL_MUSIC_SINGLE    352

//
// Special Infected
//
int g_iSprite = 0; // Smoker beam precache index
#define INFECTED_NONE		0
#define INFECTED_TANK		1 // tank
#define INFECTED_BOOMER		2 // boomer
#define INFECTED_CHARGER	3 // charger
#define INFECTED_KINGPIN	4 // 'screamer'
#define INFECTED_STALKER	5 // 'jockey'
#define INFECTED_HUNTER		6 // hunter
#define INFECTED_SMOKER		7 // smoker
#define INFECTED_MAX		INFECTED_SMOKER
// -- skin related
int iScoutZombieIndex;
int iSoldierZombieIndex;
int iPyroZombieIndex;
int iDemomanZombieIndex;
int iHeavyZombieIndex;
int iMedicZombieIndex;
int iEngineerZombieIndex;
int iSniperZombieIndex;
int iSpyZombieIndex;
#define SKIN_ZOMBIE			5
#define SKIN_ZOMBIE_SPY		SKIN_ZOMBIE + 18

//
// Weapon Pickups
//
#define WEAPON_STATIC			1
#define WEAPON_DEFAULT			2
#define WEAPON_SPAWN			3
#define WEAPON_RARE				4
#define WEAPON_RARE_SPAWN		5
#define WEAPON_STATIC_SPAWN		6
#define WEAPON_DEFAULT_NOPICKUP	7

//
// Object IDs
//
#define OBJECT_ID_DISPENSER		0
#define OBJECT_ID_SENTRY		2

//
// Attributes
//
#define ATTRIB_DRAIN_HEALTH 			855
#define ATTRIB_HEALTH_PENALTY 			125
#define ATTRIB_DMG_BONUS_VS_BUILDINGS 	137
#define ATTRIB_MAXAMMO_INCREASE 		76

//
// Entity Solid States
//
#define SOLID_NONE 		0 // no solid model
#define SOLID_BSP 		1 // a BSP tree
#define SOLID_BBOX 		2 // an AABB
#define SOLID_VPHYSICS 	6 // solid vphysics object, get vcollide from the model and collide with that
//
// Entity Collission Group
//
#define COLLISION_GROUP_DEBRIS 	1 // Collides with nothing but world and static stuff

//
// Map overwrites
//
bool g_bSurvival = false;
bool g_bNoMusic = false;
bool g_bNoDirectorTanks = false;
bool g_bNoDirectorRages = false;

//
// Weekly mutations
//
// TODO
#define MUTATION_ROBINHOOD 		1 // sniper only with huntsman / jarate
#define MUTATION_SPECIALNEEDS 	2 // only spawn special infected
#define MUTATION_BATONPASS 		3 // survivors killed by infected respawn immediatley on the same spot as they died
#define MUTATION_BLEEDOUT 		4 // survivors lose health over time
#define MUTATION_HELL			5 // zombies are always on fire
#define MUTATION_GLASSCANNON	6 // zombies deal a lot more damage, but die very easily
#define MUTATION_ALLSEEINGEYE	7 // all players glow
char g_strMutationTitles[][32] =
{
	"Robin Hood",
	"Special Needs",
	"Baton Pass",
	"Bleedout",
	"They Came From Hell",
	"Glass Cannon",
	"All-Seeing Eyes"
};
char g_strMutationDescriptions[][256] =
{
	"All Survivors become Snipers with Huntsman and Jarate.",
	"All Infected will spawn as Special Infected.",
	"All Survivors killed by Infected immediately become infected instead of dying.",
	"All Survivors will take bleed damage each second and passive health regeneration from Morale is disabled.",
	"All Infected are covered in flames, take less fire damage and ignite Survivors on hit while also gaining increased movement speed.",
	"All Infected deal massive damage but at the same time take massive damage in return.",
	"All Survivors and Infected gain outlines."
};
int g_iScheduledMutation = 0;
bool g_bMutationVote[MAXPLAYERS+1] = false;
bool g_bMutationNextRound = false;
bool g_bMutationActive = false;

//
// Map Triggers
//
#define ENT_ONPICKUP	"FireUser1"
#define ENT_ONKILL		"FireUser2"

//
// Hit Sounds
//
char g_strSoundFleshHit[][128] =
{
	"physics/flesh/flesh_impact_bullet1.wav",
	"physics/flesh/flesh_impact_bullet2.wav",
	"physics/flesh/flesh_impact_bullet3.wav",
	"physics/flesh/flesh_impact_bullet4.wav",
	"physics/flesh/flesh_impact_bullet5.wav"
};
char g_strSoundCritHit[][128] =
{
	"player/crit_received1.wav",
	"player/crit_received2.wav",
	"player/crit_received3.wav"
};
stock void EmitHitSoundToClient(int iClient, bool bCrit = false)
{
	int iRandom = GetRandomInt(0, (bCrit) ? sizeof(g_strSoundCritHit)-1 : sizeof(g_strSoundFleshHit)-1);
	EmitSoundToClient(iClient, (bCrit) ? g_strSoundCritHit[iRandom] : g_strSoundFleshHit[iRandom], _, SNDLEVEL_AIRCRAFT);
}

////////////////////////////////////////////////////////////
//
// Util Init
//
////////////////////////////////////////////////////////////
stock void utilBaseInit()
{
	//
	// Initialize offsets.
	//
	oActiveWeapon = FindSendPropInfo("CTFPlayer", "m_hActiveWeapon");
	oCloakMeter	 = FindSendPropInfo("CTFPlayer", "m_flCloakMeter");
	oResAmmo[0]	 = FindSendPropInfo("CTFPlayer", "m_iAmmo") + 4;
	oResAmmo[1]	 = FindSendPropInfo("CTFPlayer", "m_iAmmo") + 8;
	oResAmmo[2]	 = FindSendPropInfo("CTFPlayer", "m_iAmmo") + 12;
	oClipAmmo = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
}

////////////////////////////////////////////////////////////
//
// Math Utils
//
////////////////////////////////////////////////////////////
stock int max(int a, int b) { return (a > b) ? a : b; }
stock int min(int a, int b) { return (a < b) ? a : b; }
stock float fMax(float a, float b) { return (a > b) ? a : b; }
stock float fMin(float a, float b) { return (a < b) ? a : b; }

////////////////////////////////////////////////////////////
//
// ZF Team Utils
//
////////////////////////////////////////////////////////////
stock int zomTeam()
{ return zf_zomTeam; }
stock int surTeam()
{ return zf_surTeam; }
stock int setZomTeam(int team)
{ zf_zomTeam = team; }
stock int setSurTeam(int team)
{ zf_surTeam = team; }
stock int IsZombie(int client)
{ return (GetClientTeam(client) == zf_zomTeam); }
stock int IsSurvivor(int client)
{ return (GetClientTeam(client) == zf_surTeam); }

////////////////////////////////////////////////////////////
//
// Client Utils
//
////////////////////////////////////////////////////////////
stock int GetConnectingCount()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++) if (IsClientAuthorized(i)) iCount++;
	return iCount;
}
stock int GetPlayerCount()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++) if (IsValidPlayer(i)) iCount++;
	return iCount;
}
stock int GetSurvivorCount()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++) if (IsValidLivingSurvivor(i)) iCount++;
	return iCount;
}
stock int GetZombieCount()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++) if (IsValidZombie(i)) iCount++;
	return iCount;
}

////////////////////////////////////////////////////////////
//
// Client Validity Utils
//
////////////////////////////////////////////////////////////
stock bool IsValidClient(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client); }
stock bool IsValidSurvivor(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsSurvivor(client); }
stock bool IsValidZombie(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsZombie(client); }
stock bool IsValidPlayer(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && (IsZombie(client) || IsSurvivor(client)); }
stock bool IsValidLivingClient(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsPlayerAlive(client); }
stock bool IsValidLivingSurvivor(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsPlayerAlive(client) && IsSurvivor(client); }
stock bool IsValidLivingZombie(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsPlayerAlive(client) && IsZombie(client); }
stock bool IsValidLivingPlayer(int client)
{ return (client > 0) && (client <= MaxClients) && IsClientInGame(client) && IsPlayerAlive(client) && (IsZombie(client) || IsSurvivor(client)); }

////////////////////////////////////////////////////////////
//
// ZF Class Utils
//
////////////////////////////////////////////////////////////
stock bool IsValidZombieClass(TFClassType class)
{ return (ZF_VALIDZOMBIE[class] == 1); }
stock bool IsValidSurvivorClass(TFClassType class)
{ return (ZF_VALIDSURVIVOR[class] == 1); }
stock TFClassType GetRandomZombieClass()
{ return ZF_ZOMBIES[GetRandomInt(0,2)]; }
stock TFClassType GetRandomSurvivorClass()
{ return ZF_SURVIVORS[GetRandomInt(0,5)]; }

stock bool isScout(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Scout); }
stock bool isSoldier(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Soldier); }
stock bool isPyro(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Pyro); }
stock bool isDemoman(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_DemoMan); }
stock bool isHeavy(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Heavy); }
stock bool isMedic(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Medic); }
stock bool isEngineer(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Engineer); }
stock bool isSniper(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Sniper); }
stock bool isSpy(int client)
{ return (TF2_GetPlayerClass(client) == TFClass_Spy); }

////////////////////////////////////////////////////////////
//
// Map Utils
//
////////////////////////////////////////////////////////////
stock bool mapIsZF(bool bIncludeSZF = true)
{
	char mapname[4];
	GetCurrentMap(mapname, sizeof(mapname));
	if (strncmp(mapname, "zf", 2, false) == 0) return true;
	if (strncmp(mapname, "szf", 3, false) == 0 && bIncludeSZF) return true;
	return false;
}

stock bool mapIsSZF()
{
	char mapname[4];
	GetCurrentMap(mapname, sizeof(mapname));
	if (strncmp(mapname, "szf", 3, false) == 0) return true;
	return false;
}

stock bool mapIsPL()
{
	char mapname[4];
	GetCurrentMap(mapname, sizeof(mapname));
	return strncmp(mapname, "pl_", 3, false) == 0;
}

stock bool mapIsCP()
{
	char mapname[4];
	GetCurrentMap(mapname, sizeof(mapname));
	return strncmp(mapname, "cp_", 3, false) == 0;
}

////////////////////////////////////////////////////////////
//
// Round Utils
//
////////////////////////////////////////////////////////////
stock void setRoundState(ZFRoundState _state)
{ zf_roundState = _state; }

stock ZFRoundState roundState()
{ return zf_roundState; }

stock void endRound(int winningTeam)
{
	int index = FindEntityByClassname(-1, "team_control_point_master");
	if(index == -1)
	{
		index = CreateEntityByName("team_control_point_master");
		DispatchSpawn(index);
	}

	if(index == -1)
	{
		LogError("[ZF] Can't create 'team_control_point_master,' can't end round!");
	}
	else
	{
		AcceptEntityInput(index, "Enable");
		SetVariantInt(winningTeam);
		AcceptEntityInput(index, "SetWinner");
	}
}

////////////////////////////////////////////////////////////
//
// Weapon State Utils
//
////////////////////////////////////////////////////////////
stock int activeWeapon(int client)
{ return GetEntDataEnt2(client, oActiveWeapon); }

stock int activeWeaponId(int client)
{
	int weapon = activeWeapon(client);
	return (weapon > MaxClients) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1;
}

stock int slotWeaponId(int client, int slot)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	return (weapon > MaxClients) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1;
}

stock int activeWeaponSlot(int client)
{
	int weapon = activeWeapon(client);
	if (weapon > MaxClients)
	{
		for (int i = 0; i < 5; i++)
		{
			if (GetPlayerWeaponSlot(client, i) == weapon)
			{
				return i;
			}
		}
	}
	return -1;
}

stock bool isEquipped(int client, int weaponId)
{
	for (int i = 0; i < 5; i++)
	{
		if (slotWeaponId(client, i) == weaponId)
		{
			return true;
		}
	}
	return false;
}

stock bool isWielding(int client, int weaponId)
{ return (activeWeaponId(client) == weaponId); }

stock bool isWieldingMelee(int client)
{ return (activeWeaponSlot(client) == 2); }

stock bool isSlotClassname(int iClient, int iSlot, char[] strClassname)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > MaxClients && IsValidEdict(iWeapon))
	{
		char strClassname2[32];
		GetEdictClassname(iWeapon, strClassname2, sizeof(strClassname2));
		if (StrEqual(strClassname, strClassname2, false)) return true;
	}
	return false;
}

////////////////////////////////////////////////////////////
//
// Attribute / Flags Utils (Simple)
//
////////////////////////////////////////////////////////////
stock void addCondKritz(int client, float duration)
{ TF2_AddCondition(client, TFCond_Kritzkrieged, duration); }
stock void remCondKritz(int client)
{ TF2_RemoveCondition(client, TFCond_Kritzkrieged); }

stock bool isSlowed(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Slowed); }
stock bool isKritzed(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged); }
stock bool isBonked(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Bonked); }
stock bool isDazed(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Dazed); }
stock bool isCharging(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Charging); }
stock bool isBeingHealed(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Healing); }
stock bool isCloaked(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Cloaked); }
stock bool isUbered(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_Ubercharged); }
stock bool isOnFire(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_OnFire); }
stock bool isFirstBlood(int client)
{ return TF2_IsPlayerInCondition(client, TFCond_CritOnFirstBlood); }

stock bool isGrounded(int client)
{ return (GetEntityFlags(client) & (FL_ONGROUND | FL_INWATER)) != 0; }
stock bool isCrouching(int client)
{ return (GetEntityFlags(client) & FL_DUCKING) != 0; }


////////////////////////////////////////////////////////////
//
// Speed Utils
//
////////////////////////////////////////////////////////////
stock void setClientSpeed(int client, float speed)
{
	// m_flMaxSpeed appears to be reset/recalculated when:
	// + after switching weapons and before next prethinkpost
	// + (soldier holding equalizer) every 17-19 frames
	SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", speed);
}

stock float clientBaseSpeed(int client)
{
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Soldier: return 240.0;	// Default 240.0
		case TFClass_DemoMan: return 280.0;	// Default 280.0
		case TFClass_Medic: return 300.0; // Default 320.0 <Slowed>
		case TFClass_Pyro: return 240.0; // Default 300.0 <Slowed>
		case TFClass_Engineer: return 300.0; // Default 300.0
		case TFClass_Sniper: return 300.0; // Default 300.0
		case TFClass_Scout: return 330.0; // Default 400.0 <Slowed>
		case TFClass_Spy: return 280.0;	// Default 300.0 <Slowed>
		case TFClass_Heavy: return 230.0; // Default 230.0
	}

	return 0.0;
}

stock float clientBonusSpeed(int client)
{
	float speed = 0.0;

	// Infected Specific Changes
	if (IsValidLivingZombie(client))
	{
		// Infected killed total / last survivor death
		// speed += fMin(20.0, 0.5 * zf_spawnZombiesKilledSpree) + fMin(20.0, 2.0 * zf_hordeBonus[client]);
	
		// Frenzy
		if (g_bZombieRage)
		{
			speed += 10.0;
		}
		
		// On fire
		if (isOnFire(client))
		{
			speed += 10.0;
		}
		
		// From Kingpin, does not affect himself
		if (g_iSpecialInfected[client] != INFECTED_KINGPIN && TF2_IsPlayerInCondition(client, TFCond_TeleportedGlow))
		{
			speed += 10.0;
		}

		// Jarate
		if (TF2_IsPlayerInCondition(client, TFCond_Jarated))
		{
			speed -= 80.0; // jarate'd by sniper
		}
		

		//
		// Normal Infected
		//
		if (g_iSpecialInfected[client] == INFECTED_NONE)
		{
			// Overheal from rage usage 
			if (GetClientHealth(client) > SDK_GetMaxHealth(client))
			{
				speed += 10.0;
			}
		}

		//
		// Tank: movement speed bonus based on damage taken and ignite speed bonus
		//
		if (g_iSpecialInfected[client] == INFECTED_TANK)
		{
			speed += fMax(GetConVarFloat(g_cvarTankMinSpeed), GetConVarFloat(g_cvarTankMaxSpeed) - (g_fDamageTakenLife[client] / 20.0));
		}

		//
		// Charger: force charging speed (since it's a non-demoman)
		//
		if (g_iSpecialInfected[client] == INFECTED_CHARGER && isCharging(client))
		{
			speed = 1200.0; // original charge speed is 1000.0, will this black sorcery work?
		}

		//
		// Screamer: speed nerf
		//
		if (g_iSpecialInfected[client] == INFECTED_KINGPIN)
		{
			speed -= 50.0;
		}

		//
		// Hunter: speed buff
		//
		if (g_iSpecialInfected[client] == INFECTED_HUNTER)
		{
			speed += 40.0;
		}

		//
		// Predator: super speed if cloaked
		//
		if (g_iSpecialInfected[client] == INFECTED_STALKER && TF2_IsPlayerInCondition(client, TFCond_Cloaked))
		{
			speed += 120.0;
		}
	}

	// Survivor Specific Changes
	if (IsValidLivingSurvivor(client))
	{
		// if under 100 health, tick away one speed per hp lost
		if (GetClientHealth(client) < g_cvarSurvivorHealthSpeedDrain.IntValue && !isWielding(client, ZFWEAP_ESCAPEPLAN)) 
		{
			speed -= g_cvarSurvivorHealthSpeedDrain.FloatValue - GetClientHealth(client);
		}

		// force speed, since we overwrite it in here in the first place
		if (isCharging(client))
		{
			speed = 600.0;
		}

		// intended for whip
		if (TF2_IsPlayerInCondition(client, TFCond_SpeedBuffAlly))
		{
			speed += 20.0;
		}

		// if backstabbed
		if (g_bBackstabbed[client])
		{
			speed -= 60.0;
		}
	}

	// Class Specific Changes
	switch (TF2_GetPlayerClass(client))
	{
		//
		// Handle scout bonuses
		// + Affected by Crit-a-Cola
		//
		case TFClass_Scout:
		{
			if (TF2_IsPlayerInCondition(client, TFCond_CritCola))
			{
				speed += 20.0;
			}
		}

		//
		// Handle soldier bonuses
		// + Wielding Equalizer
		//
		case TFClass_Soldier:
		{
			if (isWielding(client, ZFWEAP_ESCAPEPLAN))
			{
				// soldier base: 240
				// scout base: 330

				// increase speed over time
				g_fEscapePlanPostBoost[client] += 0.1;
				speed += fMin(g_fEscapePlanPostBoost[client], 15.0);

				// apply speed
				int curH = GetClientHealth(client);
				if (curH > 160) speed += 0.0;
				else if (curH > 120) speed += 15.0;
				else if (curH > 80) speed += 30.0;
				else if (curH > 40) speed += 60.0;
				else if (curH > 0) speed += 90.0;
				// if(curH > 120) speed += 24.0;
				// if(curH > 80) speed += 48.0;
				// if(curH > 40) speed += 96.0;
				// if(curH > 0) speed += 144.0;
			}
			else
			{
				// decrease the boost variable, takes no resources, god bless sourcemod
				g_fEscapePlanPostBoost[client] = fMax(g_fEscapePlanPostBoost[client] - 1.0, 0.0);
			}
		}

		//
		// Handle pyro bonuses
		// + Wielding Powerjack
		//
		case TFClass_Pyro:
		{
			if (isWielding(client, ZFWEAP_POWERJACK))
			{
				speed += 36.0;
			}
		}

		//
		// Handle demoman bonuses
		// + Headcount from all swords but Skullcutter and Persuader
		// + Wielding Skullcutter
		//
		case TFClass_DemoMan:
		{
			if (isSlotClassname(client, 2, "tf_weapon_sword")
				&& !isEquipped(client, ZFWEAP_SKULLCUTTER)
				&& !isEquipped(client, ZFWEAP_PERSIAN))
			{
				int heads = GetEntProp(client, Prop_Send, "m_iDecapitations");
				speed += min(heads, 4) * 10.0;
			}

			else if (isEquipped(client, ZFWEAP_SKULLCUTTER))
			{
				speed -= 42.0;
			}
		}

		//
		// Handle medic bonuses
		// + Wielding the Overdose
		//
		case TFClass_Medic:
		{
			// Overdose
			if (isWielding(client, ZFWEAP_OVERDOSE))
			{
				int iMedigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
				if (iMedigun > MaxClients && IsValidEdict(iMedigun))
				{
					speed += GetEntPropFloat(iMedigun, Prop_Send, "m_flChargeLevel") * 36;
				}
			}
		}

		//
		// Handle heavy bonuses
		// + Wielding GRU
		// + Affected by Steak or similar
		//
		case TFClass_Heavy:
		{
			if (isWielding(client, ZFWEAP_GRU) || isWielding(client, ZFWEAP_FESTIVEGRU) || isWielding(client, ZFWEAP_BREADBITES))
			{
				speed += 70.0;
			}

			else if (isEquipped(client, ZFWEAP_WARRIORSSPIRIT) || isEquipped(client, ZFWEAP_MITTENS))
			{
				speed -= 20.0;
			}
			else if (isEquipped(client, ZFWEAP_FISTSOFSTEEL))
			{
				speed -= 10.0;
			}

			if (TF2_IsPlayerInCondition(client, TFCond_CritCola))
			{
				//return 40.0;
				speed += 20.0;
			}
		}
	}

	return speed;
	// return 0.0;
}

////////////////////////////////////////////////////////////
//
// Entity Name Utils
//
////////////////////////////////////////////////////////////
stock bool entClassnameContains(int ent, const char[] strRefClassname)
{
	if(IsValidEdict(ent) && IsValidEntity(ent))
	{
		char strName[32];
		GetEdictClassname(ent, strName, sizeof(strName));
		return (StrContains(strName, strRefClassname, false) != -1);
	}
	return false;
}

////////////////////////////////////////////////////////////
//
// Glow Utils
//
////////////////////////////////////////////////////////////
stock void setGlow(int client, bool glowEnabled)
{
	SetEntProp(client, Prop_Send, "m_bGlowEnabled", (glowEnabled ? 1 : 0));
}

////////////////////////////////////////////////////////////
//
// Sentry Utils
//
////////////////////////////////////////////////////////////
stock bool entIsSentry(int ent)
{ return entClassnameContains(ent, "obj_sentrygun"); }

////////////////////////////////////////////////////////////
//
// Cloak Utils
// + Range 0.0 to 100.0
//
////////////////////////////////////////////////////////////
stock float getCloak(int client)
{
	if (isSpy(client))
	{
		return GetEntDataFloat(client, oCloakMeter);
	}
	return 0.0;
}

stock void setCloak(int client, float cloakPct)
{
	if (isSpy(client))
	{
		SetEntDataFloat(client, oCloakMeter, cloakPct, true);
	}
}

////////////////////////////////////////////////////////////
//
// Uber Utils
// + Range 0.0 to 1.0
//
////////////////////////////////////////////////////////////
stock void addUber(int client, float uberPct)
{
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon > MaxClients && isMedic(client))
	{
		float curPct = GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel");
		SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", fMin((curPct + uberPct), 1.0));
	}
}

stock void subUber(int client, float uberPct)
{
	int weapon = GetPlayerWeaponSlot(client, 1);
	if(weapon > MaxClients && isMedic(client))
	{
		float curPct = GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel");
		SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", fMax((curPct - uberPct), 0.0));
	}
}

////////////////////////////////////////////////////////////
//
// Metal Add/Sub Utils
//
////////////////////////////////////////////////////////////
stock void addMetalPct(int client, float metalPct, float metalLimitPct = 1.0)
{
	if(isEngineer(client))
	{
		int curMetal = getMetal(client);
		int maxMetal = 200;
		int metal = RoundToCeil(maxMetal * metalPct);
		setMetal(client, min((curMetal + metal), RoundToCeil(maxMetal * metalLimitPct)));
	}
}

stock void subMetalPct(int client, float metalPct)
{
	if(isEngineer(client))
	{
		int curMetal = getMetal(client);
		int maxMetal = 200;
		int metal = RoundToCeil(maxMetal * metalPct);
		subMetal(client, max((curMetal - metal), 0));
	}
}

stock void addMetal(int client, int metal)
{
	if(isEngineer(client))
	{
		int curMetal = getMetal(client);
		setMetal(client, min((curMetal + metal), 200));
	}
}

stock void subMetal(int client, int metal)
{
	if(isEngineer(client))
	{
		int curMetal = getMetal(client);
		setMetal(client, max((curMetal - metal), 0));
	}
}

////////////////////////////////////////////////////////////
//
// Metal Get/Set Utils
//
////////////////////////////////////////////////////////////
stock int getMetal(int client)
{ return GetEntData(client, oResAmmo[2]); }

stock void setMetal(int client, int metal)
{ SetEntData(client, oResAmmo[2], min(metal, 255), true); }

////////////////////////////////////////////////////////////
//
// Ammo Add/Sub Utils
//
////////////////////////////////////////////////////////////

//
// Clip Ammo Utils
//
stock int getClipAmmo(int client, int slot)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	return (weapon > MaxClients) ? GetEntData(weapon, oClipAmmo) : 0;
}

stock void setClipAmmo(int client, int slot, int ammo)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if (weapon > MaxClients) SetEntData(weapon, oClipAmmo, min(ammo, 255), true);
}

stock void addClipAmmo(int client, int slot, int ammo)
{
	int curAmmo = getClipAmmo(client, slot);
	int newAmmo = curAmmo + ammo;
	setClipAmmo(client, slot, newAmmo);
}

stock void subClipAmmo(int client, int slot, int ammo)
{
	int curAmmo = getClipAmmo(client, slot);
	setClipAmmo(client, slot, max((curAmmo - ammo), 0));
}

//
// Reserve Ammo Utils
//
stock int getResAmmo(int iClient, int slot)
{
	return GetEntData(iClient, oResAmmo[slot]);
}

stock void setResAmmo(int iClient, int slot, int ammo)
{
	SetEntData(iClient, oResAmmo[slot], min(ammo, 255), true);
}

stock void addResAmmo(int client, int slot, int ammo)
{
	int curAmmo = getResAmmo(client, slot);
	int newAmmo = curAmmo + ammo;
	setResAmmo(client, slot, newAmmo);
}

stock void subResAmmo(int client, int slot, int ammo)
{
	int curAmmo = getResAmmo(client, slot);
	setResAmmo(client, slot, max((curAmmo - ammo), 0));
}

////////////////////////////////////////////////////////////
//
// Spawn Utils
//
////////////////////////////////////////////////////////////
stock void SpawnClient(int client, int nextClientTeam)
{
	// 1. Prevent players from spawning if they're on an invalid team.
	//		Prevent players from spawning as an invalid class.
	if (IsClientInGame(client) && (IsSurvivor(client) || IsZombie(client)))
	{
		TFClassType nextClientClass = TF2_GetPlayerClass(client);
		if (nextClientTeam == zomTeam() && !IsValidZombieClass(nextClientClass))
		{
			nextClientClass = GetRandomZombieClass();
		}
		if (nextClientTeam == surTeam() && (!IsValidSurvivorClass(nextClientClass) || (IsMutationActive(MUTATION_ROBINHOOD) && nextClientClass != TFClass_Sniper)) )
		{
			// robin hood, only snipers
			if (IsMutationActive(MUTATION_ROBINHOOD))
			{
				nextClientClass = TFClass_Sniper;
			}
			else
			{
				nextClientClass = GetRandomSurvivorClass();
			}
		}

		// Use of m_lifeState here prevents:
		// 1. "[Player] Suicided" messages.
		// 2. Adding a death to player stats.
		TF2_RemoveAllWeapons(client);
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		TF2_SetPlayerClass(client, nextClientClass, false, true);
		ChangeClientTeam(client, nextClientTeam);
		SetEntProp(client, Prop_Send, "m_lifeState", 0);
		TF2_RespawnPlayer(client);
	}
}

stock void setTeamRespawnTime(int team, float time)
{
	int index = FindEntityByClassname(-1, "tf_gamerules");
	if(index != -1)
	{
		SetVariantFloat(time/2.0);
		if(team == view_as<int>(TFTeam_Blue))
			AcceptEntityInput(index, "SetBlueTeamRespawnWaveTime", -1, -1, 0);
		if(team == view_as<int>(TFTeam_Red))
			AcceptEntityInput(index, "SetRedTeamRespawnWaveTime", -1, -1, 0);
	}
}

////////////////////////////////////////////////////////////
//
// Damage Utils
//
////////////////////////////////////////////////////////////
stock void DealDamage(int iVictim, int iDamage, int iAttacker = 0, int iDmgType = DMG_GENERIC, char[] strWeapon = "")
{
	if (!IsValidClient(iAttacker)) iAttacker = 0;
	if (IsValidClient(iVictim) && iDamage > 0)
	{
		char strDamage[16];
		IntToString(iDamage, strDamage, 16);
		char strDamageType[32];
		IntToString(iDmgType, strDamageType, 32);
		int iHurt = CreateEntityByName("point_hurt");
		if (iHurt > 0 && IsValidEdict(iHurt))
		{
			DispatchKeyValue(iVictim, "targetname", "infectious_hurtme");
			DispatchKeyValue(iHurt, "DamageTarget", "infectious_hurtme");
			DispatchKeyValue(iHurt, "Damage", strDamage);
			DispatchKeyValue(iHurt, "DamageType", strDamageType);
			if (!StrEqual(strWeapon, "")) DispatchKeyValue(iHurt, "classname", strWeapon);
			DispatchSpawn(iHurt);
			AcceptEntityInput(iHurt, "Hurt", iAttacker);
			DispatchKeyValue(iHurt, "classname", "point_hurt");
			DispatchKeyValue(iVictim, "targetname", "infectious_donthurtme");
			RemoveEdict(iHurt);
		}
	}
}

////////////////////////////////////////////////////////////
//
// Vector Utils
//
////////////////////////////////////////////////////////////
stock int GetClosestEnemy(int iClient, float flMaxDistance)
{
	if (!IsValidClient(iClient)) return 0;

	float flPosClient[3];
	float flPosTarget[3];
	float flDistance;
	GetClientEyePosition(iClient, flPosClient);
	// zombies target survivors, else target zombie team
	int iTargetTeam = (IsZombie(iClient)) ? surTeam() : zomTeam();

	for (int i = 1; i <= MaxClients; i++)
	{
		// get infected if iClient is survivor, get survivor if iClient is infected
		if (IsValidClient(i) && GetClientTeam(i) == iTargetTeam)
		{
			GetClientEyePosition(i, flPosTarget);
			flDistance = GetVectorDistance(flPosTarget, flPosClient);
			if (flDistance <= flMaxDistance)
			{
				return i;
			}
		}
	}

	return 0;
}

////////////////////////////////////////////////////////////
//
// Sound Utils
//
////////////////////////////////////////////////////////////

// Arrays containing voice files for each class
// Soldier
//
char g_strCarryVO_Soldier[][PLATFORM_MAX_PATH] =
{
    "vo/soldier_autocappedcontrolpoint01.mp3"
	,"vo/soldier_positivevocalization01.mp3"
	,"vo/soldier_positivevocalization02.mp3"
    ,"vo/soldier_positivevocalization03.mp3"
	,"vo/soldier_PickAxeTaunt01.mp3"
    ,"vo/soldier_PickAxeTaunt02.mp3"
    ,"vo/soldier_PickAxeTaunt03.mp3"
    ,"vo/soldier_PickAxeTaunt04.mp3"
    ,"vo/soldier_PickAxeTaunt05.mp3"
    ,"vo/soldier_laughevil01.mp3"
    ,"vo/soldier_laughevil03.mp3"
    ,"vo/soldier_go01.mp3"
    ,"vo/soldier_go02.mp3"
    ,"vo/soldier_battlecry02.mp3"
    ,"vo/soldier_battlecry06.mp3"
};

char g_strWeaponVO_Soldier[][PLATFORM_MAX_PATH] =
{
    "vo/soldier_mvm_loot_common01.mp3"
	,"vo/soldier_mvm_loot_common02.mp3"
	,"vo/soldier_mvm_loot_common03.mp3"
	,"vo/soldier_mvm_loot_rare01.mp3"
	,"vo/soldier_mvm_loot_rare02.mp3"
    ,"vo/soldier_mvm_loot_rare03.mp3"
    ,"vo/soldier_mvm_loot_rare04.mp3"
};

char g_strTankATK_Soldier[][PLATFORM_MAX_PATH] =
{
    "vo/soldier_mvm_tank_shooting01.mp3"
    ,"vo/soldier_mvm_tank_shooting02.mp3"
};

//
// Pyro
//
char g_strCarryVO_Pyro[][PLATFORM_MAX_PATH] =
{
    "vo/pyro_autocappedcontrolpoint01.mp3"
	,"vo/pyro_autocappedintelligence01.mp3"
	,"vo/pyro_go01.mp3"
    ,"vo/pyro_goodjob01.mp3"
    ,"vo/pyro_laughevil02.mp3"
    ,"vo/pyro_laughevil03.mp3"
    ,"vo/pyro_moveup01.mp3"
};

char g_strWeaponVO_Pyro[][PLATFORM_MAX_PATH] =
{
    "vo/pyro_battlecry01.mp3"
    ,"vo/pyro_battlecry02.mp3"
	,"vo/pyro_positivevocalization01.mp3"
};

//
// Demoman
//
char g_strCarryVO_DemoMan[][PLATFORM_MAX_PATH] =
{
    "vo/demoman_go01.mp3"
	,"vo/demoman_go02.mp3"
	,"vo/demoman_go03.mp3"
	,"vo/demoman_helpmecapture02.mp3"
    ,"vo/demoman_helpmecapture03.mp3"
    ,"vo/demoman_laughevil01.mp3"
    ,"vo/demoman_laughevil03.mp3"
    ,"vo/demoman_laughevil05.mp3"
    ,"vo/demoman_laughshort02.mp3"
    ,"vo/demoman_laughshort04.mp3"
    ,"vo/demoman_laughshort06.mp3"
    ,"vo/demoman_gibberish02.mp3"
	,"vo/demoman_gibberish08.mp3"
    ,"vo/demoman_gibberish13.mp3"
};

char g_strWeaponVO_DemoMan[][PLATFORM_MAX_PATH] =
{
    "vo/demoman_mvm_loot_common01.mp3"
    ,"vo/demoman_mvm_loot_common02.mp3"
    ,"vo/demoman_mvm_loot_common03.mp3"
    ,"vo/demoman_mvm_loot_common04.mp3"
    ,"vo/demoman_mvm_loot_godlike01.mp3"
    ,"vo/demoman_mvm_loot_rare01.mp3"
    ,"vo/demoman_mvm_loot_rare02.mp3"
};

//
// Engineer
//
char g_strCarryVO_Engineer[][PLATFORM_MAX_PATH] =
{
    "vo/engineer_autocappedcontrolpoint01.mp3"
	,"vo/engineer_autocappedcontrolpoint02.mp3"
    ,"vo/engineer_autocappedintelligence01.mp3"
    ,"vo/engineer_autocappedintelligence02.mp3"
    ,"vo/engineer_autocappedintelligence03.mp3"
    ,"vo/engineer_cheers04.mp3"
    ,"vo/engineer_laughevil01.mp3"
    ,"vo/engineer_laughevil04.mp3"
    ,"vo/engineer_laughevil06.mp3"
};

char g_strWeaponVO_Engineer[][PLATFORM_MAX_PATH] =
{
    "vo/engineer_mvm_loot_common01.mp3"
    ,"vo/engineer_mvm_loot_common02.mp3"
    ,"vo/engineer_mvm_loot_godlike01.mp3"
    ,"vo/engineer_mvm_loot_godlike02.mp3"
    ,"vo/engineer_mvm_loot_godlike03.mp3"
    ,"vo/engineer_mvm_loot_rare01.mp3"
    ,"vo/engineer_mvm_loot_rare02.mp3"
    ,"vo/engineer_mvm_loot_rare03.mp3"
    ,"vo/engineer_mvm_loot_rare04.mp3"
};

char g_strTankATK_Engineer[][PLATFORM_MAX_PATH] =
{
    "vo/engineer_mvm_tank_shooting01.mp3"
    ,"vo/engineer_meleedare01.mp3"
};

//
// Medic
//
char g_strCarryVO_Medic[][PLATFORM_MAX_PATH] =
{
    "vo/medic_go01.mp3"
    ,"vo/medic_go05.mp3"
    ,"vo/medic_goodjob02.mp3"
    ,"vo/medic_laughevil01.mp3"
    ,"vo/medic_laughevil03.mp3"
    ,"vo/medic_positivevocalization03.mp3"
    ,"vo/medic_specialcompleted04.mp3"
    ,"vo/medic_specialcompleted07.mp3"
    ,"vo/medic_yes03.mp3"
};

char g_strWeaponVO_Medic[][PLATFORM_MAX_PATH] =
{
    "vo/medic_mvm_loot_common01.mp3"
    ,"vo/medic_mvm_loot_common02.mp3"
    ,"vo/medic_mvm_loot_common03.mp3"
    ,"vo/medic_mvm_loot_rare02.mp3"
    ,"vo/medic_mvm_loot_godlike01.mp3"
    ,"vo/medic_mvm_loot_godlike02.mp3"
    ,"vo/medic_mvm_loot_godlike03.mp3"
    ,"vo/medic_specialcompleted02.mp3"
    ,"vo/medic_specialcompleted03.mp3"
};

char g_strTankATK_Medic[][PLATFORM_MAX_PATH] =
{
    "vo/medic_mvm_tank_shooting01.mp3"
    ,"vo/medic_mvm_tank_shooting02.mp3"
};

//
// Sniper
//
char g_strCarryVO_Sniper[][PLATFORM_MAX_PATH] =
{
    "vo/sniper_autocappedcontrolpoint01.mp3"
    ,"vo/sniper_autocappedcontrolpoint02.mp3"
    ,"vo/sniper_autocappedcontrolpoint03.mp3"
    ,"vo/sniper_autocappedintelligence01.mp3"
    ,"vo/sniper_autocappedintelligence02.mp3"
    ,"vo/sniper_autocappedintelligence04.mp3"
    ,"vo/sniper_autocappedintelligence05.mp3"
    ,"vo/sniper_award01.mp3"
    ,"vo/sniper_award06.mp3"
    ,"vo/sniper_award07.mp3"
    ,"vo/sniper_award08.mp3"
    ,"vo/sniper_award11.mp3"
    ,"vo/sniper_award12.mp3"
    ,"vo/sniper_award13.mp3"
    ,"vo/sniper_battlecry02.mp3"
    ,"vo/sniper_go03.mp3"
    ,"vo/sniper_helpmecapture01.mp3"
    ,"vo/sniper_laughevil01.mp3"
    ,"vo/sniper_laughevil02.mp3"
    ,"vo/sniper_moveup01.mp3"
    ,"vo/sniper_specialweapon02.mp3"
    ,"vo/sniper_specialweapon05.mp3"
    ,"vo/sniper_specialweapon07.mp3"
    ,"vo/sniper_specialweapon09.mp3"
};

char g_strWeaponVO_Sniper[][PLATFORM_MAX_PATH] =
{
    "vo/sniper_specialweapon01.mp3"
    ,"vo/sniper_specialweapon02.mp3"
    ,"vo/sniper_specialweapon03.mp3"
    ,"vo/sniper_specialweapon04.mp3"
    ,"vo/sniper_specialweapon05.mp3"
    ,"vo/sniper_specialweapon06.mp3"
    ,"vo/sniper_specialweapon07.mp3"
    ,"vo/sniper_specialweapon08.mp3"
    ,"vo/sniper_specialweapon09.mp3"
};

//
// Infected
//
char g_strZombieVO[][PLATFORM_MAX_PATH] =
{
    "been_shot_12"
    ,"been_shot_13"
    ,"been_shot_14"
    ,"been_shot_18"
    ,"been_shot_19"
    ,"been_shot_20"
    ,"been_shot_21"
    ,"been_shot_22"
    ,"been_shot_24"
    ,"charger_charge_01"
    ,"charger_charge_02"
    ,"charger_pain_01"
    ,"charger_pain_02"
    ,"charger_pain_03"
    ,"charger_spotprey_01"
    ,"charger_spotprey_02"
    ,"charger_spotprey_03"
    ,"death_22"
    ,"death_23"
    ,"death_24"
    ,"death_25"
    ,"death_26"
    ,"death_27"
    ,"death_28"
    ,"death_29"
    ,"hunter_attackmix_01"
    ,"hunter_attackmix_02"
    ,"hunter_attackmix_03"
    ,"hunter_pain_12"
    ,"hunter_pain_13"
    ,"hunter_pain_14"
    ,"hunter_stalk_04"
    ,"hunter_stalk_05"
    ,"hunter_stalk_06"
    ,"idle_breath_01"
    ,"idle_breath_02"
    ,"idle_breath_03"
    ,"idle_breath_04"
    ,"male_boomer_disruptvomit_05"
    ,"male_boomer_disruptvomit_06"
    ,"male_boomer_disruptvomit_07"
    ,"male_boomer_lurk_02"
    ,"male_boomer_lurk_03"
    ,"male_boomer_lurk_04"
    ,"male_boomer_pain_1"
    ,"male_boomer_pain_2"
    ,"male_boomer_pain_3"
    ,"mumbling01"
    ,"mumbling02"
    ,"mumbling03"
    ,"mumbling04"
    ,"mumbling05"
    ,"mumbling06"
    ,"mumbling07"
    ,"mumbling08"
    ,"rage_at_victim21"
    ,"rage_at_victim22"
    ,"rage_at_victim25"
    ,"rage_at_victim26"
    ,"shoved_1"
    ,"shoved_2"
    ,"shoved_3"
    ,"shoved_4"
    ,"smoker_lurk_11"
    ,"smoker_lurk_12"
    ,"smoker_lurk_13"
    ,"smoker_pain_02"
    ,"smoker_pain_03"
    ,"smoker_pain_04"
    ,"tank_attack_01"
    ,"tank_attack_02"
    ,"tank_attack_03"
    ,"tank_attack_04"
    ,"tank_death_01"
    ,"tank_death_02"
    ,"tank_death_03"
    ,"tank_death_04"
    ,"tank_fire_02"
    ,"tank_fire_03"
    ,"tank_fire_04"
    ,"tank_fire_05"
    ,"tank_pain_01"
    ,"tank_pain_02"
    ,"tank_pain_03"
    ,"tank_pain_04"
    ,"tank_voice_01"
    ,"tank_voice_02"
    ,"tank_voice_03"
    ,"tank_voice_04"
};

//
// Functions
//
void VocalsPrecache()
{
    int i;

    for (i = 0; i < sizeof(g_strCarryVO_Soldier); i++) PrecacheSound(g_strCarryVO_Soldier[i]);
    for (i = 0; i < sizeof(g_strWeaponVO_Soldier); i++) PrecacheSound(g_strWeaponVO_Soldier[i]);
    for (i = 0; i < sizeof(g_strTankATK_Soldier); i++) PrecacheSound(g_strTankATK_Soldier[i]);

    for (i = 0; i < sizeof(g_strCarryVO_Pyro); i++) PrecacheSound(g_strCarryVO_Pyro[i]);
    for (i = 0; i < sizeof(g_strWeaponVO_Pyro); i++) PrecacheSound(g_strWeaponVO_Pyro[i]);

    for (i = 0; i < sizeof(g_strCarryVO_DemoMan); i++) PrecacheSound(g_strCarryVO_DemoMan[i]);
    for (i = 0; i < sizeof(g_strWeaponVO_DemoMan); i++) PrecacheSound(g_strWeaponVO_DemoMan[i]);

    for (i = 0; i < sizeof(g_strCarryVO_Engineer); i++) PrecacheSound(g_strCarryVO_Engineer[i]);
    for (i = 0; i < sizeof(g_strWeaponVO_Engineer); i++) PrecacheSound(g_strWeaponVO_Engineer[i]);
    for (i = 0; i < sizeof(g_strTankATK_Engineer); i++) PrecacheSound(g_strTankATK_Engineer[i]);

    for (i = 0; i < sizeof(g_strCarryVO_Medic); i++) PrecacheSound(g_strCarryVO_Medic[i]);
    for (i = 0; i < sizeof(g_strWeaponVO_Medic); i++) PrecacheSound(g_strWeaponVO_Medic[i]);
    for (i = 0; i < sizeof(g_strTankATK_Medic); i++) PrecacheSound(g_strTankATK_Medic[i]);

    for (i = 0; i < sizeof(g_strCarryVO_Sniper); i++) PrecacheSound(g_strCarryVO_Sniper[i]);
    for (i = 0; i < sizeof(g_strWeaponVO_Sniper); i++) PrecacheSound(g_strWeaponVO_Sniper[i]);

    for (i = 0; i < sizeof(g_strZombieVO); i++)
    {
        char strPath[80];
        Format(strPath, sizeof(strPath), "left4fortress/zombie_vo/%s.mp3", g_strZombieVO[i]);
        PrecacheSound(strPath, true);
        Format(strPath, sizeof(strPath), "sound/%s", strPath);
        AddFileToDownloadsTable(strPath);
    }
}

stock void SZF_EmitZombieVoiceToAll(char[] strName, iClient, int iNumber)
{
	char strPath[PLATFORM_MAX_PATH];
	Format(strPath, sizeof(strPath), "left4fortress/zombie_vo/%s_%s%d.mp3", strName, (iNumber <= 9) ? "0" : "", iNumber);
	EmitSoundToAll(strPath, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
}

stock void SZF_EmitNearDeathToAll(iClient)
{
	char strPath[PLATFORM_MAX_PATH];
	int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_NEARDEATH2]-1);
	MusicGetPath(MUSIC_NEARDEATH2, iRandom, strPath, sizeof(strPath));
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && ShouldHearEventSounds(i) && i != iClient)
		{
			EmitSoundToClient(i, strPath, iClient, SNDLEVEL_AIRCRAFT);
		}
	}
}

////////////////////////////////////////////////////////////
//
// Weapon Pickup Utils
//
////////////////////////////////////////////////////////////

// Arrays containing weapon model paths
// Spawn Weapons
//
char g_strSpawnModels[][256] =
{
	// MULTI-CLASS
	"models/weapons/c_models/c_shotgun/c_shotgun.mdl",
	"models/weapons/c_models/c_reserve_shooter/c_reserve_shooter.mdl",

	// SOLDIER
	"models/weapons/c_models/c_bugle/c_bugle.mdl",
	"models/weapons/c_models/c_battalion_bugle/c_battalion_bugle.mdl",

	// PYRO
	"models/weapons/c_models/c_drg_manmelter/c_drg_manmelter.mdl",
	"models/weapons/c_models/c_flaregun_pyro/c_flaregun_pyro.mdl",
	"models/weapons/c_models/c_detonator/c_detonator.mdl",

	// DEMOMAN
	"models/weapons/c_models/c_targe/c_targe.mdl",

	// MEDIC
	"models/weapons/c_models/c_syringegun/c_syringegun.mdl",
	"models/weapons/c_models/c_proto_syringegun/c_proto_syringegun.mdl",

	// SNIPER
	"models/weapons/c_models/c_smg/c_smg.mdl",
	"models/weapons/c_models/urinejar.mdl",
	"models/weapons/w_models/w_sniperrifle.mdl",
	"models/weapons/c_models/c_bow/c_bow.mdl",
	"models/weapons/c_models/c_pro_rifle/c_pro_rifle.mdl",

	// ENGINEER
	"models/weapons/c_models/c_pistol/c_pistol.mdl",
	"models/weapons/c_models/c_wrangler.mdl",
	"models/weapons/c_models/c_tele_shotgun/c_tele_shotgun.mdl"
};

//
// Rare Weapons
//
char g_strRareModels[][256] =
{
	// SOLDIER
	"models/weapons/c_models/c_directhit/c_directhit.mdl",
	"models/weapons/c_models/c_liberty_launcher/c_liberty_launcher.mdl",
	"models/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl",
	"models/weapons/c_models/c_dumpster_device/c_dumpster_device.mdl",
	"models/weapons/c_models/c_rocketlauncher/c_rocketlauncher.mdl",
	"models/workshop/weapons/c_models/c_atom_launcher/c_atom_launcher.mdl",
	"models/workshop/weapons/c_models/c_blackbox/c_blackbox.mdl",

	// PYRO
	"models/weapons/c_models/c_flamethrower/c_flamethrower.mdl",
	"models/weapons/c_models/c_degreaser/c_degreaser.mdl",
	"models/weapons/c_models/c_flamethrower/c_backburner.mdl",
	"models/weapons/c_models/c_rainblower/c_rainblower.mdl",
	"models/weapons/c_models/c_flameball/c_flameball.mdl",

	// DEMOMAN
	"models/weapons/c_models/c_stickybomb_launcher/c_stickybomb_launcher.mdl",
	"models/weapons/c_models/c_scottish_resistance/c_scottish_resistance.mdl",
	"models/workshop/weapons/c_models/c_kingmaker_sticky/c_kingmaker_sticky.mdl",
	"models/weapons/c_models/c_demo_cannon/c_demo_cannon.mdl",
	"models/workshop/weapons/c_models/c_quadball/c_quadball.mdl",
	// "models/weapons/c_models/c_persian_shield/c_persian_shield.mdl",
	// "models/workshop/weapons/c_models/c_wheel_shield/c_wheel_shield.mdl",

	// MEDIC
	"models/weapons/c_models/c_crusaders_crossbow/c_crusaders_crossbow.mdl",
	"models/weapons/c_models/c_medigun/c_medigun.mdl",
	"models/weapons/c_models/c_medigun_defense/c_medigun_defense.mdl",
	"models/weapons/c_models/c_proto_medigun/c_proto_medigun.mdl",
	"models/weapons/c_models/c_leechgun/c_leechgun.mdl",

	// ENGINEER
	"models/weapons/c_models/c_frontierjustice/c_frontierjustice.mdl",
	"models/weapons/c_models/c_dex_shotgun/c_dex_shotgun.mdl",

	// SNIPER
	"models/weapons/c_models/c_dex_sniperrifle/c_dex_sniperrifle.mdl",
	"models/weapons/c_models/c_tfc_sniperrifle/c_tfc_sniperrifle.mdl",
	"models/weapons/c_models/c_dartgun.mdl"
};

//
// 'Normal' Weapons
//
char g_strWeaponModels[][256] =
{
	// MULTI-CLASS
	"models/workshop/weapons/c_models/c_trenchgun/c_trenchgun.mdl",
	"models/weapons/c_models/c_shotgun/c_shotgun.mdl",
	"models/weapons/c_models/c_reserve_shooter/c_reserve_shooter.mdl",

	// SOLDIER
	"models/weapons/c_models/c_bugle/c_bugle.mdl",
	"models/weapons/c_models/c_battalion_bugle/c_battalion_bugle.mdl",
	"models/weapons/c_models/c_drg_righteousbison/c_drg_righteousbison.mdl",
	"models/weapons/c_models/c_shogun_warhorn/c_shogun_warhorn.mdl",

	// PYRO
	"models/weapons/c_models/c_scorch_shot/c_scorch_shot.mdl",
	"models/weapons/c_models/c_drg_manmelter/c_drg_manmelter.mdl",
	"models/weapons/c_models/c_flaregun_pyro/c_flaregun_pyro.mdl",
	"models/weapons/c_models/c_detonator/c_detonator.mdl",

	// DEMOMAN
	"models/weapons/c_models/c_grenadelauncher/c_grenadelauncher.mdl",
	"models/weapons/c_models/c_lochnload/c_lochnload.mdl",

	// MEDIC
	"models/weapons/c_models/c_syringegun/c_syringegun.mdl",
	"models/weapons/c_models/c_proto_syringegun/c_proto_syringegun.mdl",

	// SNIPER
	"models/weapons/c_models/c_smg/c_smg.mdl",
	"models/weapons/c_models/urinejar.mdl",
	"models/weapons/c_models/c_pro_smg/c_pro_smg.mdl",
	"models/weapons/w_models/w_sniperrifle.mdl",
	"models/weapons/c_models/c_pro_rifle/c_pro_rifle.mdl",
	"models/weapons/c_models/c_bazaar_sniper/c_bazaar_sniper.mdl",

	// ENGINEER
	"models/weapons/c_models/c_pistol/c_pistol.mdl",
	"models/weapons/c_models/c_wrangler.mdl",
	"models/weapons/c_models/c_drg_pomson/c_drg_pomson.mdl",
	"models/weapons/c_models/c_tele_shotgun/c_tele_shotgun.mdl"
};

//
// 'Pick-up' Models
//
char g_strPickupModels[][256] =
{
	// AMMO
	"models/items/ammopack_large.mdl",
	"models/items/medkit_large.mdl",
	// "models/weapons/c_models/c_energy_drink/c_energy_drink.mdl", // skin 0-2
};

//
// Rare Weapons by ID
//
int g_intRareWeapon[] =
{
	18,
	127,
	414,
	730,
	441,
	1104,
	21,
	40,
	215,
	741,
	996,
	130,
	20,
	1150,
	406,
	1099,
	527,
	141,
	29,
	411,
	998,
	305,
	36,
	230,
	402,
	526,
	1098
};

//
// Functions
//
bool StrContainsWeapon(char[] strModel, char[] strName)
{
	char strC[32];
	char strW[32];
	Format(strC, sizeof(strC), "/w_%s.mdl", strName);
	Format(strW, sizeof(strW), "/c_%s.mdl", strName);
	return (StrContains(strModel, strC) != -1 || StrContains(strModel, strW) != -1);
}

int GetWeaponType(int iEntity)
{
	char strName[255];
	GetEntPropString(iEntity, Prop_Data, "m_iName", strName, sizeof(strName));

	// strcontains versus strequals on 2048 entities obviously shows strcontains as the winner
	if (StrContains(strName, "szf_weapon_spawn", false) == 0) return WEAPON_SPAWN; // spawn: dont expire on pickup
	else if (StrContains(strName, "szf_weapon_rare_spawn", false) == 0) return WEAPON_RARE_SPAWN; // guaranteed rare and non-expiring
	else if (StrContains(strName, "szf_weapon_rare", false) == 0) return WEAPON_RARE; // guaranteed rare
	else if (StrContains(strName, "szf_weapon_static_spawn", false) == 0) return WEAPON_STATIC_SPAWN; // static: don't change model and non-expiring
	else if (StrContains(strName, "szf_weapon_static", false) == 0) return WEAPON_STATIC; // static: don't change model
	else if (StrContains(strName, "szf_weapon_nopickup", false) == 0) return WEAPON_DEFAULT_NOPICKUP; // no pickup: this weapon can never become a pickup
	else if (StrContains(strName, "szf_weapon", false) != -1) return WEAPON_DEFAULT; // normal

	return 0;
}

bool IsWeaponTypeSpawn(int iEntity)
{ return (GetWeaponType(iEntity) == WEAPON_SPAWN || GetWeaponType(iEntity) == WEAPON_RARE_SPAWN || GetWeaponType(iEntity) == WEAPON_STATIC_SPAWN); }

bool IsWeaponTypeRare(int iEntity)
{ return (GetWeaponType(iEntity) == WEAPON_RARE || GetWeaponType(iEntity) == WEAPON_RARE_SPAWN); }

stock void MakeWeaponPickup(int iEntity)
{
	// reset angle
	float flAngles[3];
	flAngles[0] = 0.0;
	flAngles[1] = 0.0;
	flAngles[2] = 0.0;

	// set model
	SetEntityModel(iEntity, g_strPickupModels[GetRandomInt(0, sizeof(g_strPickupModels)-1)]);
	TeleportEntity(iEntity, NULL_VECTOR, flAngles, NULL_VECTOR);

	// set color
	SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iEntity, 150, 255, 150, 255);
}

////////////////////////////////////////////////////////////
//
// Tutorial Module / Help Utils
//
////////////////////////////////////////////////////////////

void RegisterTutorialCookies()
{
	cookieFirstTimeZombie = RegClientCookie("szf_tutorial_zombie", "Store tutorial state(s).", CookieAccess_Protected);
	cookieFirstTimeSurvivor = RegClientCookie("szf_tutorial_survivor", "Store tutorial state(s).", CookieAccess_Protected);
	cookieFirstTimeVersusTank = RegClientCookie("szf_tutorial_survivor_vs_tank", "Store tutorial state(s).", CookieAccess_Protected);
}

float PrepareTutorialMessage(float flDelay, int iClient, char[] strMessage, float flDuration = 6.0)
{
	DataPack hPack = new DataPack();
	CreateDataTimer(flDelay, DisplayTutorialMessage, hPack);
	hPack.WriteCell(iClient);
	hPack.WriteFloat(flDuration);
	hPack.WriteString(strMessage);
	return flDelay + flDuration;
}

public Action DisplayTutorialMessage(Handle hTimer, DataPack iData)
{
	char strDisplay[255];
	ResetPack(iData);

	int iClient = ReadPackCell(iData);
	float flDuration = ReadPackFloat(iData);
	ReadPackString(iData, strDisplay, sizeof(strDisplay));

	if (!IsValidClient(iClient)) return;

	SetHudTextParams(-1.0, 0.4, flDuration, 50, 255, 50, 128);
	ShowHudText(iClient, -1, strDisplay);
}

stock void ShowGameText(const char[] strText, char[] strIcon = "ico_build")
{
	int iEntity = CreateEntityByName("game_text_tf");
	DispatchKeyValue(iEntity, "message", strText);
	DispatchKeyValue(iEntity, "display_to_team", "0");
	// for icons, go to https://github.com/SteamDatabase/GameTracking-TF2/blob/master/tf/tf2_misc_dir/scripts/mod_textures.txt -sasch
	DispatchKeyValue(iEntity, "icon", "ico_build");
	DispatchKeyValue(iEntity, "targetname", "game_text1");
	DispatchKeyValue(iEntity, "background", "2");
	DispatchSpawn(iEntity);
	AcceptEntityInput(iEntity, "Display", iEntity, iEntity);
	CreateTimer(10.0, KillGameText, iEntity);
}

stock void InitiateSurvivorTutorial(int iClient)
{
	// first time spawning as a survivor
	if (GetCookie(iClient, cookieFirstTimeSurvivor) == 1) return;

	float flDelay = 1.0;
	flDelay = PrepareTutorialMessage(flDelay, iClient, "Welcome to Super Zombie Fortress!");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "You are currently playing as a Survivor.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "You may have noticed you do not have any weapons.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "You can pick up weapons by calling for medic or attacking it.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "As a Survivor, your goal is to complete the map objective.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "There are (Special) Infected, watch out for those!");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "You can check out more information by typing '/szf' into the chat.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "Enjoy the round and good luck out there!");

	SetCookie(iClient, 1, cookieFirstTimeSurvivor);
}

stock void InitiateZombieTutorial(int iClient)
{
	// first time spawning as an infected
	if (GetCookie(iClient, cookieFirstTimeZombie) == 1) return;
	
	float flDelay = 1.0;
	flDelay = PrepareTutorialMessage(flDelay, iClient, "Welcome to Super Zombie Fortress!");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "You are currently playing as an Infected.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "As an Infected, your goal is to kill the Survivors.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "To help you accomplish that, Special Infected are available for you based on time and conditions.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "In addition, a tank may be spawned later in the round.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "You can check out more information by typing '/szf' into the chat.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "Enjoy the round and get them!");

	SetCookie(iClient, 1, cookieFirstTimeZombie);
}

stock void InitiateTankTutorial(int iClient)
{
	// first time encountering a tank
	if (GetCookie(iClient, cookieFirstTimeVersusTank) == 1) return;

	float flDelay = 1.0;
	flDelay = PrepareTutorialMessage(flDelay, iClient, "Do not let the Tank get close to you, his attacks are lethal.");
	flDelay = PrepareTutorialMessage(flDelay, iClient, "Shoot the tank to slow it down and minimize damage done to the Survivor team.");

	SetCookie(iClient, 1, cookieFirstTimeVersusTank);
}

////////////////////////////////////////////////////////////
//
// Morale Utils
//
////////////////////////////////////////////////////////////

stock int AddMorale(int iClient, int iAmount)
{
	if (IsValidClient(iClient))
	{
		g_iSurvivorMorale[iClient] = min(100, g_iSurvivorMorale[iClient] + iAmount);
		return g_iSurvivorMorale[iClient];
	}
	return 0;
}
stock void AddMoraleAll(int iAmount)
{ for (int i = 1; i <= MaxClients; i++) AddMorale(i, iAmount); }

stock int SubtractMorale(int iClient, int iAmount)
{
	if (IsValidClient(iClient))
	{
		g_iSurvivorMorale[iClient] = max(0, g_iSurvivorMorale[iClient] - iAmount);
		return g_iSurvivorMorale[iClient];
	}
	return 0;
}

stock void SubtractMoraleAll(int iAmount)
{ for (int i = 1; i <= MaxClients; i++) SubtractMorale(i, iAmount); }

stock int SetMorale(int iClient, int iAmount)
{
	if (IsValidClient(iClient))
	{
		g_iSurvivorMorale[iClient] = iAmount;
		return g_iSurvivorMorale[iClient];
	}
	return 0;
}

stock void SetMoraleAll(int iAmount)
{ for (int i = 1; i <= MaxClients; i++) SetMorale(i, iAmount); }

stock int GetMorale(int iClient)
{ return (IsValidClient(iClient)) ? g_iSurvivorMorale[iClient] : 0; }

////////////////////////////////////////////////////////////
//
// Mutation Utils
//
////////////////////////////////////////////////////////////

stock void ResetMutationVotes()
{ for (int i = 1; i <= MaxClients; i++) g_bMutationVote[i] = false; }

stock int GetMutationVotes()
{ 
	int iReturn = 0;
	for (int i = 1; i <= MaxClients; i++) if (g_bMutationVote[i]) iReturn++;
	return iReturn;
}

stock int GetMutationVotesNeeded()
{ return RoundToCeil(GetConnectingCount() * GetConVarFloat(g_cvarMutationVoteRatio)); }

stock int GetActiveMutation()
{
	// save time if we already know it beforehand
	if (g_iScheduledMutation > 0) return g_iScheduledMutation;

	// get 1-7
	char strTimeDay[4];
	FormatTime(strTimeDay, sizeof(strTimeDay), "%w", GetTime());
	int iMutation = StringToInt(strTimeDay)+1;
	g_iScheduledMutation = iMutation;
	return g_iScheduledMutation;
}

bool IsMutationActive(int iMutation)
{ return (g_bMutationActive && GetActiveMutation() == iMutation && GetConVarBool(g_cvarMutationForceEnabled)); }

////////////////////////////////////////////////////////////
//
// Time Utils
//
////////////////////////////////////////////////////////////

stock int GetSecondsLeft()
{
	//Get round time that the round started with
	int ent = FindEntityByClassname(MaxClients+1, "team_round_timer");

	if (!IsValidEntity(ent))
	{
		return -1;
	}

	float RoundStartLength = GetEntPropFloat(ent, Prop_Send, "m_flTimeRemaining");
	int iRoundStartLength = RoundToZero(RoundStartLength);
	int TimeBuffer = iRoundStartLength + g_AdditionalTime;

	if (g_StartTime <= 0) return TimeBuffer;

	int SecElapsed = GetTime() - g_StartTime;

	int iTimeLeft = TimeBuffer-SecElapsed;
	if (iTimeLeft < 0) iTimeLeft = 0;
	if (iTimeLeft > TimeBuffer) iTimeLeft = TimeBuffer;

	return iTimeLeft;
}

stock float GetTimePercentage()
{
	//Alright bitch, play tiemz ovar
	if (g_StartTime <= 0) return 0.0;
	int SecElapsed = GetTime() - g_StartTime;
	//CPrintToChatAll("%i Seconds have elapsed since the round started", SecElapsed)

	//Get round time that the round started with
	int ent = FindEntityByClassname(MaxClients+1, "team_round_timer");
	if (ent == -1) return 0.0;

	float RoundStartLength = GetEntPropFloat(ent, Prop_Send, "m_flTimeRemaining");
	//CPrintToChatAll("Float:RoundStartLength == %f", RoundStartLength)
	int iRoundStartLength = RoundToZero(RoundStartLength);

	//g_AdditionalTime = time added this round
	//CPrintToChatAll("TimeAdded This Round: %i", g_AdditionalTime)

	int TimeBuffer = iRoundStartLength + g_AdditionalTime;
	//new TimeLeft = TimeBuffer - SecElapsed;

	float TimePercentage = float(SecElapsed) / float(TimeBuffer);
	//CPrintToChatAll("TimeLeft Sec: %i", TimeLeft)

	if (TimePercentage < 0.0) TimePercentage = 0.0;
	if (TimePercentage > 1.0) TimePercentage = 1.0;

	return TimePercentage;
}

/******************************************************************************************************/

stock void CloseHandle_2(Handle hndl)
{ if (hndl != null) delete hndl; }

stock void ResizePlayer(int iClient, float flSize = 1.0)
{
	float m_vecMin[3] = { -24.5, -24.5, 0.0 }, m_vecMax[3] = { 24.5,  24.5, 83.0 };

	// box scale 
	ScaleVector(m_vecMin, flSize);
	ScaleVector(m_vecMax, flSize);
	SetEntPropVector(iClient, Prop_Send, "m_vecSpecifiedSurroundingMins", m_vecMin);
	SetEntPropVector(iClient, Prop_Send, "m_vecSpecifiedSurroundingMaxs", m_vecMax);

	// model scale and step size
	SetEntPropFloat(iClient, Prop_Send, "m_flModelScale", flSize);
	SetEntPropFloat(iClient, Prop_Send, "m_flStepSize", 18.0 * flSize);

	g_flSetSize[iClient] = flSize;
}

stock void PrecacheBonus(char[] strPath)
{
	char strPath2[256];
	Format(strPath2, sizeof(strPath2), "materials/left4fortress/%s.vmt", strPath);
	AddFileToDownloadsTable(strPath2);
	PrecacheGeneric(strPath2, true);
	Format(strPath2, sizeof(strPath2), "materials/left4fortress/%s.vtf", strPath);
	AddFileToDownloadsTable(strPath2);
	PrecacheGeneric(strPath2, true);
}

stock bool ShowBonus(int iClient, char[] strMessage, float flDelay = 1.0, float flDuration = 5.0)
{
	if (!IsValidClient(iClient)) return false; // timer not sent

	DataPack hPack = new DataPack();
	CreateDataTimer(flDelay, ShowBonusTimer, hPack);
	hPack.WriteCell(iClient);
	hPack.WriteString(strMessage);
	hPack.WriteFloat(flDuration);
	return true; // timer sent
}

public Action ShowBonusTimer(Handle hTimer, DataPack iData)
{
	ResetPack(iData);
	int iClient = ReadPackCell(iData);
	if (!IsValidClient(iClient)) return;

	// do sound
	char strSound[256];
	int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_AWARD]-1);
	MusicGetPath(MUSIC_AWARD, iRandom, strSound, sizeof(strSound));
	EmitSoundToClient(iClient, strSound);

	// generate overlay path
	char strOverlay[64];
	ReadPackString(iData, strOverlay, sizeof(strOverlay));
	Format(strOverlay, sizeof(strOverlay), "left4fortress/%s", strOverlay);
	// get duration
	float flDuration = ReadPackFloat(iData);

	// show overlay
	ScreenOverlay(flDuration, strOverlay, iClient);
}

stock void ScreenOverlay(float flDuration = 6.0, char[] strOverlay, int iClient)
{
	if (!IsValidClient(iClient)) return;

	char strPath[256];
	Format(strPath, sizeof(strPath), "r_screenoverlay\"%s\"", strOverlay);
	ClientCommand(iClient, strPath);
	CreateTimer(flDuration, ResetOverlay, iClient);
}

public Action ResetOverlay(Handle hTimer, int iClient)
{
	if (!IsValidClient(iClient)) return;
	ClientCommand(iClient, "r_screenoverlay\"\"");
}

stock void AddModelToDownload(char[] strModel)
{
	char strPath[256];
	char ModelExtensions[][] = {
		".mdl",
		".dx80.vtx",
		".dx90.vtx",
		".sw.vtx",
		".vvd",
		".phy"
	};

	for (int iExt = 0; iExt < sizeof(ModelExtensions); iExt++)
	{
		Format(strPath, sizeof(strPath), "models/%s%s", strModel, ModelExtensions[iExt]);
		AddFileToDownloadsTable(strPath);
	}
}

stock int FindEntityByTargetname(const char[] targetname, const char[] classname)
{
	char namebuf[32];
	int index = -1;
	namebuf[0] = '\0';

	while(strcmp(namebuf, targetname) != 0
		&& (index = FindEntityByClassname(index, classname)) != -1)
		GetEntPropString(index, Prop_Data, "m_iName", namebuf, sizeof(namebuf));

	return(index);
}

stock void Shake(int iClient, float flAmplitude, float flDuration)
{
	BfWrite hShake = view_as<BfWrite>(StartMessageOne("Shake", iClient));
	hShake.WriteByte(0); // 0x0000 = start shake
	hShake.WriteFloat(flAmplitude);
	hShake.WriteFloat(1.0);
	hShake.WriteFloat(flDuration);
	EndMessage();
}

stock void SpawnPickup(int iClient, const char[] strClassname)
{
	float PlayerPosition[3];
	GetClientAbsOrigin(iClient, PlayerPosition);
	PlayerPosition[2] += 16.0;
	int iEntity = CreateEntityByName(strClassname);
	DispatchKeyValue(iEntity, "OnPlayerTouch", "!self,Kill,,0,-1");
	if (DispatchSpawn(iEntity))
	{
		SetEntProp(iEntity, Prop_Send, "m_iTeamNum", 0, 4);
		TeleportEntity(iEntity, PlayerPosition, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(0.15, TimerKillEntity, iEntity);
	}
}

public Action TimerKillEntity(Handle hTimer, int iEntity)
{
	if (IsValidEntity(iEntity))
	{
		AcceptEntityInput(iEntity, "Kill");
	}
}


public Action TimerStopTickle(Handle hTimer, int iClient)
{
	if (!IsValidLivingPlayer(iClient)) return;
	// aka "remove any taunt but conviniently utilize it for holiday punch"
	// if (!GetEntProp(iClient, Prop_Send, "m_bIsReadyToHighFive") && !IsValidEntity(GetEntPropEnt(iClient, Prop_Send, "m_hHighFivePartner"))) TF2_RemoveCondition(iClient, TFCond_Taunting);
	TF2_RemoveCondition(iClient, TFCond_Taunting);
	g_bBackstabbed[iClient] = false;
}

stock void ShowAnnotationOnObject(int iIndex, const char[] strText, int iTeam = 0, float flDuration = 5.0, float flDistance = 1280.0)
{
	Handle hEvent = CreateEvent("show_annotation");
	if (hEvent == INVALID_HANDLE) return;
	SetEventInt(hEvent, "follow_entindex", iIndex);
	SetEventInt(hEvent, "visibilityBitfield", ShouldShowAnnotation(iIndex, iTeam, flDistance));
	SetEventFloat(hEvent, "lifetime", flDuration);
	SetEventString(hEvent, "text", strText);
	SetEventString(hEvent, "play_sound", "ui/item_paint_can_pickup.wav");
	FireEvent(hEvent);
}

stock int ShouldShowAnnotation(int iIndex, int iTeam, float flDistance)
{
	int bits;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i)) continue;
		if (iIndex == i) continue; // dont target self
		if (iTeam > 0 && GetClientTeam(i) != iTeam) continue; // if filtering by team
		if (IsValidPlayer(i) && IsWithinRange(iIndex, i, flDistance)) // valid player & within range
		{
			bits |= (1 << i);
		}
	}
	return bits;
}

stock bool IsWithinRange(int iIndex, int iViewer, float flDistance)
{
	float indexpos[3];
	float viewerpos[3];

	GetClientAbsOrigin(iViewer, viewerpos);
	if (IsValidPlayer(iIndex)) {
		// if it's a client, get client abs
		GetClientAbsOrigin(iIndex, indexpos);
	} else {
		// else, get entity vec position
		GetEntPropVector(iIndex, Prop_Send, "m_vecOrigin", indexpos);
	}

	return (GetVectorDistance(indexpos, viewerpos) <= flDistance);
}  

// because it saves a lot of lines.
stock void SZF_GetClientName(int iClient, char[] str, int iSize)
{
	if (!IsValidClient(iClient)) return;
	char strPlayerName[80];
	GetClientName(iClient, strPlayerName, sizeof(strPlayerName));
	strcopy(str, iSize, strPlayerName);
}

stock void SZF_CPrintToChatAll(int iClient, char[] strText, bool bTeam = false, const char[] param1="", const char[] param2="", const char[] param3="", const char[] param4="")
{
	if (bTeam && !IsValidClient(iClient)) return;

	char strPlayerName[80], strMessage[255];
	if (0 < iClient <= MaxClients)
	{
		SZF_GetClientName(iClient, strPlayerName, sizeof(strPlayerName));
		if (bTeam)
			Format(strMessage, sizeof(strMessage), "\x01(TEAM) %s\x01 : %s", strPlayerName, strText);
		else
			Format(strMessage, sizeof(strMessage), "\x01%s\x01 : %s", strPlayerName, strText);
	}
	
	ReplaceString(strMessage, sizeof(strMessage), "{param1}", "%s1");
	ReplaceString(strMessage, sizeof(strMessage), "{param2}", "%s2");
	ReplaceString(strMessage, sizeof(strMessage), "{param3}", "%s3");
	ReplaceString(strMessage, sizeof(strMessage), "{param4}", "%s4");
	CReplaceColorCodes(strMessage, iClient, _, sizeof(strMessage));
	
	int players[MAXPLAYERS+1], playersNum;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || (bTeam &&  GetClientTeam(i) != GetClientTeam(iClient))) continue;
		players[playersNum++] = i;
	}
	UTIL_SayText2(players, playersNum, iClient, true, strMessage, param1, param2, param3, param4);
}

void SetNextAttack(int iClient, float flDuration = 0.0, bool bMeleeOnly = true)
{
	if (!IsValidClient(iClient)) return;

	int iWeapon;
	float flNextAttack = flDuration;

	// primary, secondary and melee
	for (int i = 0; i <= 2; i++)
	{
		if (bMeleeOnly && i < 2) continue;
		iWeapon = GetPlayerWeaponSlot(iClient, i);

		if (iWeapon > MaxClients && IsValidEntity(iWeapon))
		{
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", flNextAttack);
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", flNextAttack);
		}
	}
}

// love you ben
stock bool TF2_WeaponFindAttribute(int iWeapon, int iAttrib, float &flVal)
{
	Address addAttrib = TF2Attrib_GetByDefIndex(iWeapon, iAttrib);
	if (addAttrib == Address_Null)
	{
		int iItemDefIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		int iAttributes[16];
		float flAttribValues[16];
		
		int iMaxAttrib = TF2Attrib_GetStaticAttribs(iItemDefIndex, iAttributes, flAttribValues);
		for (int i = 0; i < iMaxAttrib; i++)
		{
			if (iAttributes[i] == iAttrib)
			{
				flVal = flAttribValues[i];
				return true;
			}
		}
		return false;
	}
	flVal = TF2Attrib_GetValue(addAttrib);
	return true;
}

////////////////////////////////////////////////////////////
//
// Infected Utils
//
////////////////////////////////////////////////////////////

int SetRageCooldown(int iClient, int iValue)
{
	if (!IsValidZombie(iClient)) return 0;
	zf_rageTimer[iClient] = (iValue == 0) ? iValue : iValue+1;
	return zf_rageTimer[iClient];
}

int AddRageCooldown(int iClient, int iValue)
{
	if (!IsValidZombie(iClient)) return 0;
	zf_rageTimer[iClient] += iValue;
	return zf_rageTimer[iClient];
}

int GetRageCooldown(int iClient)
{ return (IsValidZombie(iClient)) ? zf_rageTimer[iClient] : -1; }

void DoGenericRage(int iClient)
{
	int curH = GetClientHealth(iClient);
	SetEntityHealth(iClient, RoundToCeil(curH * 1.5));

	// hear me roar
	ClientCommand(iClient, "voicemenu 2 1");

	float fClientPos[3];
	GetClientEyePosition(iClient, fClientPos);
	fClientPos[2] -= 60.0; // the particle goes "down", so essentially we make the particle a bit up of the player so it goes down as an effect

	ShowParticle("spell_cast_wheel_blue", 4.0, fClientPos);
	PrintHintText(iClient, "Rage Activated!");
}

void DoBoomerExplosion(int iClient, float flRadius)
{
	float flClientPos[3];
	float flSurvivorPos[3];
	GetClientEyePosition(iClient, flClientPos);

	ShowParticle("asplode_hoodoo_debris", 6.0, flClientPos);
	ShowParticle("asplode_hoodoo_dust", 6.0, flClientPos);

	// count survivors hit
	int survivorsHit = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			GetClientEyePosition(i, flSurvivorPos);
			float fDistance = GetVectorDistance(flClientPos, flSurvivorPos);
			Shake(i, fMax(50.0 - (fDistance * 0.05), 5.0), 3.0);
			if (fDistance <= flRadius)
			{
				TF2_AddCondition(i, TFCond_Jarated, 12.0 - (fDistance * 0.01));
				survivorsHit++;
			}
		}
	}

	// play DARF BARF sound              wtf bro???? -disp
	SZF_EmitZombieVoiceToAll("male_boomer_disruptvomit", iClient, GetRandomInt(5, 7));
	// TODO: add explosive sound

	// if alive, force explode
	if (IsPlayerAlive(iClient)) FakeClientCommand(iClient, "explode");
}

void DoKingpinRage(int iClient, float flRadius)
{
	float flPosScreamer[3]; // fun fact: this is based on l4d's scrapped "screamer" special infected, which "buffed" zombies with its presence
	float flPosZombie[3];
	float flDistance;
	GetClientEyePosition(iClient, flPosScreamer);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsZombie(i))
		{
			GetClientEyePosition(i, flPosZombie);
			flDistance = GetVectorDistance(flPosScreamer, flPosZombie);
			if (flDistance <= flRadius)
			{
				TF2_AddCondition(i, TFCond_DefenseBuffed, 7.0 - flDistance / 120.0);
				Shake(i, 3.0, 3.0);
			}
		}
	}
}

void DoHunterJump(int iClient)
{
	char strPath[64];
	Format(strPath, sizeof(strPath), "ambient/halloween/male_scream_%i.wav", GetRandomInt(18, 19));
	EmitSoundToAll(strPath, iClient, SNDLEVEL_AIRCRAFT);

	//g_bHopperIsUsingPounce[iClient] = true;
	CreateTimer(0.3, SetHunterJump, iClient);

	float flVelocity[3];
	float flEyeAngles[3];

	GetClientEyeAngles(iClient, flEyeAngles);

	flVelocity[0] = Cosine(DegToRad(flEyeAngles[0])) * Cosine(DegToRad(flEyeAngles[1])) * 960;
	flVelocity[1] = Cosine(DegToRad(flEyeAngles[0])) * Sine(DegToRad(flEyeAngles[1])) * 960;
	flVelocity[2] = 480.0;

	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, flVelocity);
	SetEntProp(iClient, Prop_Send, "m_iAirDash", 5);
}

void DoSmokerBeam(int iClient)
{
	float vOrigin[3], vAngles[3], vEndOrigin[3], vHitPos[3];
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);

	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_ALL, RayType_Infinite, TraceDontHitEntity, iClient);
	TR_GetEndPosition(vEndOrigin, hTrace);

	// draw beam
	TE_SetupBeamPoints(vOrigin, vEndOrigin, g_iSprite, 0, 0, 0, 0.08, 5.0, 5.0, 10, 0.0, { 255, 255, 255, 255 }, 0);
	TE_SendToAll();

	int iHit = TR_GetEntityIndex(hTrace);

	if (TR_DidHit(hTrace) && IsValidClient(iHit) && IsValidLivingSurvivor(iHit) && GetVectorDistance(vOrigin, vEndOrigin) <= 2500.0)
	{
		// calculate pull velocity towards Smoker
		if (!g_bBackstabbed[iClient])
		{
			float vVelocity[3];
			GetClientAbsOrigin(iHit, vHitPos);
			MakeVectorFromPoints(vOrigin, vHitPos, vVelocity);
			NormalizeVector(vVelocity, vVelocity);
			ScaleVector(vVelocity, fMin(-450.0 + GetClientHealth(iHit), -10.0) );
			TeleportEntity(iHit, NULL_VECTOR, NULL_VECTOR, vVelocity);
		}

		// if target changed, change stored target AND reset beam hit count
		if (g_iSmokerBeamHitVictim[iClient] != iHit)
		{
			g_iSmokerBeamHitVictim[iClient] = iHit;
			g_iSmokerBeamHits[iClient] = 0;
		}

		// increase count and if it reaches a threshold, apply damage
		g_iSmokerBeamHits[iClient]++;
		if (g_iSmokerBeamHits[iClient] == 5)
		{
			DealDamage(iHit, 2, iClient); // do damage
			g_iSmokerBeamHits[iClient] = 0;
		}

		Shake(iHit, 4.0, 0.2); // shake effect
	}

	delete hTrace;
}

stock int FindChargerTarge(int iClient)
{
	int edict = MaxClients+1;
	while((edict = FindEntityByClassname2(edict, "tf_wearable_demoshield")) != -1)
	{
		int idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
		if (idx == 406 && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == iClient && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
		{
			return edict;
		}
	}
	return -1;
}

public Action SetHunterJump(Handle timer, any iClient)
{
	if (IsValidLivingZombie(iClient))
	{
		g_bHopperIsUsingPounce[iClient] = true;
	}

	return Plugin_Continue;
}

stock int GetReplaceRageWithSpecialInfectedSpawnCount()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidZombie(i) && g_bReplaceRageWithSpecialInfectedSpawn[i])
		{
			iCount++;
		}
	}
	return iCount;
}

stock void UTIL_SayText2(int[] players, int playersNum, int iEntity, bool bChat, const char[] msg_name, const char[] param1="", const char[] param2="", const char[] param3="", const char[] param4="")
{
	BfWrite message = UserMessageToBfWrite(StartMessage("SayText2", players, playersNum, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS)); 
	
	message.WriteByte(iEntity);
	message.WriteByte(true);

	message.WriteString(msg_name); 
	
	message.WriteString(param1); 
	
	message.WriteString(param2); 
	
	message.WriteString(param3);

	message.WriteString(param4);
	
	EndMessage();
}


// Filthy functions from a very old era
// Reimplemented from assumptions of their actions
static int GetCookie(int iClient, Handle hCookie)
{
	// uint32 has a max value of 4294967295 therefore numbers cannot be longer than 10 digits
	char sCookie[10];
	GetClientCookie(iClient, hCookie, sCookie, sizeof(sCookie));
	return StringToInt(sCookie);
}

static void SetCookie(int iClient, int iAmount, Handle hCookie)
{
	// uint32 has a max value of 4294967295 therefore numbers cannot be longer than 10 digits
	char sCookie[10];
	IntToString(iAmount, sCookie, sizeof(sCookie));
	SetClientCookie(iClient, hCookie, sCookie);
}
