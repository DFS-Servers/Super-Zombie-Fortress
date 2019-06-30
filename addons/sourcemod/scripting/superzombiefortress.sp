#pragma semicolon 1

// Includes
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <clientprefs>
// 3rd party includes
#include <morecolors>
#include <tf2attributes>
#include <tf_econ_data>
#include <tf2items>
#include <szf_util_base>
#include <szf_util_panels>
// enforce new decls
#pragma newdecls required

// plugin Information
public Plugin myinfo =
{
	name = "Super Zombie Fortress",
	author = "sasch, Benoist3012 (contributions), MekuCube (original)",
	description = "Originally based off MekuCube's 1.05",
	version = PLUGIN_VERSION,
	url = "https://github.com/ramunecarbonated"
}

////////////////////////////////////////////////////////////
//
// Sourcemod Callbacks
//
////////////////////////////////////////////////////////////
public void OnPluginStart()
{
	// Add server tag.
	AddServerTag("zf");
	AddServerTag("szf");

	// Initialize global state
	g_bSurvival = false;
	g_bNoMusic = false;
	g_bNoDirectorTanks = false;
	g_bNoDirectorRages = false;
	zf_bEnabled = false;
	zf_bNewRound = true;
	zf_lastSurvivor = false;
	setRoundState(RoundInit1);

	// Initialize timer handles
	zf_tMain = INVALID_HANDLE;
	zf_tMainSlow = INVALID_HANDLE;
	zf_tMainFast = INVALID_HANDLE;
	zf_tHoarde = INVALID_HANDLE;

	// Initialize other packages
	utilBaseInit();

	// Register cvars
	g_cvarVersion = CreateConVar("sm_zf_version", PLUGIN_VERSION, "Current Zombie Fortress Version. DO NOT TOUCH!", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	SetConVarString(g_cvarVersion, PLUGIN_VERSION);
	g_cvarForceOn = CreateConVar("sm_zf_force_on", "1", "<0/1> Activate ZF for non-ZF maps", _, true, 0.0, true, 1.0);
	g_cvarRatio = CreateConVar("sm_zf_ratio", "0.7", "<0.01-1.00> Percentage of players that start as survivors", _, true, 0.01, true, 1.0);
	g_cvarSwapOnPayload = CreateConVar("sm_zf_swaponpayload", "1", "<0/1> Swap teams on non-ZF payload maps", _, true, 0.0, true, 1.0);
	g_cvarSwapOnAttdef = CreateConVar("sm_zf_swaponattdef", "1", "<0/1> Swap teams on non-ZF attack/defend maps", _, true, 0.0, true, 1.0);
	g_cvarTankHealth = CreateConVar("sm_zf_tank_health", "400", "Amount of health the Tank gets per alive survivor", _, true, 10.0);
	g_cvarTankHealthMin = CreateConVar("sm_zf_tank_health_min", "1000", "Minimum amount of health the Tank can spawn with", _, true, 0.0);
	g_cvarTankHealthMax = CreateConVar("sm_zf_tank_health_max", "8000", "Maximum amount of health the Tank can spawn with", _, true, 0.0);
	g_cvarTankTime = CreateConVar("sm_zf_tank_time", "60.0", "Adjusts the damage the Tank takes per second. If the value is 70.0, the Tank will take damage that will make him die (if unhurt by survivors) after 70 seconds. 0 to disable", _, true, 0.0);
	g_cvarTankOnce = CreateConVar("sm_zf_tank_once", "60.0", "Every round there is at least one Tank. If no Tank has appeared, a Tank will be manually created when there is sm_zf_tank_once time left. Ie. if the value is 60, the Tank will be spawned when there's 60% of the time left", _, true, 0.0);
	g_cvarTankMinSpeed = CreateConVar("sm_zf_tank_min_speed", "70.0", "Define the minimum movement speed increment the Tank gains", _, true, 0.0);
	g_cvarTankMaxSpeed = CreateConVar("sm_zf_tank_max_speed", "120.0", "Define the minimum movement speed increment the Tank gains", _, true, 0.0);
	g_cvarFrenzyChance = CreateConVar("sm_zf_frenzy_chance", "3.0", "% Chance of a random frenzy", _, true, 0.0);
	g_cvarFrenzyMaxRespawns = CreateConVar("sm_zf_frenzy_max_respawns", "30", "Maximum amount of Infected which can instantly respawn during a frenzy upon dieing", _, true, 1.0);
	g_cvarFrenzyTankChance = CreateConVar("sm_zf_frenzy_tank", "20.0", "% Chance of a Tank appearing instead of a frenzy", _, true, 0.0);
	g_cvarSpecialBonusHealth = CreateConVar("sm_zf_special_health_bonus", "100.0", "How much bonus health should Special Infected receive", _, true, 10.0);
	g_cvarMutationMinPlayers = CreateConVar("sm_zf_mutation_minvotes", "6", "Minimal amount of players required to vote for mutation mode", _, true, 1.0, true, 32.0);
	g_cvarMutationVoteRatio = CreateConVar("sm_zf_mutation_vote_ratio", "0.6", "<0.01-1.00> Percentage of players required to active mutation mode", _, true, 0.01, true, 1.0);
	g_cvarMutationForceEnabled = CreateConVar("sm_zf_mutation_force_enabled", "0", "Force enable mutation", _, true, 0.0, true, 1.0);
	g_cvarMaxRareWeapons = CreateConVar("sm_zf_weapons_max_rare", "15", "Maximum amount of pickup weapons from the 'rare' roster", _, true, 0.0);
	g_cvarMinSpawnWeapons = CreateConVar("sm_zf_weapons_min_spawn", "4", "Minimum amount of pickup weapons from the 'spawn' roster", _, true, 0.0);
	g_cvarSurvivorHealthSpeedDrain = CreateConVar("sm_zf_survivor_hp_speed_drain", "50", "Below this amount of health, speed should be drained from the Survivor", _, true, 0.0);
	AutoExecConfig(true);

	// Hook events
	HookEvent("teamplay_round_start", event_RoundStart);
	HookEvent("teamplay_setup_finished", event_SetupEnd);
	HookEvent("teamplay_round_win", event_RoundEnd);
	HookEvent("teamplay_timer_time_added", EventTimeAdded);
	HookEvent("player_spawn", event_PlayerSpawn);
	HookEvent("player_death", event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_builtobject", event_PlayerBuiltObject);
	HookEvent("teamplay_point_captured", event_CPCapture);
	HookEvent("teamplay_point_startcapture", event_CPCaptureStart);
	HookEvent("teamplay_broadcast_audio", event_OnBroadCast, EventHookMode_Pre);
	HookEvent("controlpoint_starttouch", event_OnPlayerInsideCapture);
	HookEvent("controlpoint_endtouch", event_OnPlayerOutsideCapture);
	HookEvent("deploy_buff_banner", event_BuffBannerDeployed);
	HookEvent("player_chargedeployed", event_UberDeployed);

	// Hook Client Commands
	AddCommandListener(hook_JoinTeam, "jointeam");
	AddCommandListener(hook_JoinClass, "joinclass");
	AddCommandListener(hook_VoiceMenu, "voicemenu");

	RegServerCmd("szf_panic_event", Server_ZombieRage);
	RegServerCmd("szf_zombierage", Server_ZombieRage);

	RegServerCmd("szf_zombietank", Server_Tank);
	RegServerCmd("szf_tank", Server_Tank);

	// Hook Client Chat / Console Commands
	RegConsoleCmd("sm_zf", cmd_zfMenu);
	RegConsoleCmd("sm_szf", cmd_zfMenu);
	RegConsoleCmd("sm_music", cmd_zfMusicToggle);
	RegConsoleCmd("sm_votemutation", cmd_zfVoteMutation);
	RegConsoleCmd("sm_votem", cmd_zfVoteMutation);
	// RegConsoleCmd("sm_teampreference", cmd_zfTeamPreference);

	RegAdminCmd("sm_tank", Admin_ZombieTank, ADMFLAG_CHANGEMAP, "(Try to) call a tank.");
	RegAdminCmd("sm_boomer", Admin_ForceBoomer, ADMFLAG_CHANGEMAP, "Become a boomer on next respawn.");
	RegAdminCmd("sm_charger", Admin_ForceCharger, ADMFLAG_CHANGEMAP, "Become a charger on next respawn.");
	RegAdminCmd("sm_kingpin", Admin_ForceScreamer, ADMFLAG_CHANGEMAP, "Become a screamer on next respawn.");
	RegAdminCmd("sm_stalker", Admin_ForcePredator, ADMFLAG_CHANGEMAP, "Become a predator on next respawn.");
	RegAdminCmd("sm_hunter", Admin_ForceHopper, ADMFLAG_CHANGEMAP, "Become a hunter on next respawn.");
	RegAdminCmd("sm_smoker", Admin_ForceSmoker, ADMFLAG_CHANGEMAP, "Become a smoker on next respawn.");

	CreateTimer(10.0, SpookySound, 0, TIMER_REPEAT);
	AddNormalSoundHook(SoundHook);

	RegisterTutorialCookies();
	cookieNoMusicForPlayer = RegClientCookie("szf_musicpreference", "Does the player want to hear the gamemode's music?", CookieAccess_Protected);
	cookiePreferredTeam = RegClientCookie("szf_teampreference", "What team does the player prefer?", CookieAccess_Protected);

	AddCommandListener(CommandListener_Build, "build");
	SDK_Init();

	g_bFirstRound = true;
	
}

public Action OnRelayTrigger(const char[] output, int caller, int activator, float delay)
{
	char strRelay[255];
	GetEntPropString(caller, Prop_Data, "m_iName", strRelay, sizeof(strRelay));

	if (StrEqual("szf_panic_event", strRelay) || StrEqual("szf_zombierage", strRelay)) ZombieRage();
	else if (StrEqual("szf_zombietank", strRelay) || StrEqual("szf_tank", strRelay)) ZombieTank();
}

// Benoist3012 is the man :heart:
public int TF2Items_OnGiveNamedItem_Post(int iClient, char[] classname, int itemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex)
{
	if (IsZombie(iClient))
	{
		if (strcmp(classname, "tf_weapon_fists") == 0 || strcmp(classname, "tf_weapon_knife") == 0 || strcmp(classname, "tf_weapon_bat") == 0)
		{
			TF2Attrib_SetByDefIndex(entityIndex, ATTRIB_DRAIN_HEALTH, 0.0);
			TF2Attrib_SetByDefIndex(entityIndex, ATTRIB_HEALTH_PENALTY, 0.0);
			TF2Attrib_RemoveByDefIndex(entityIndex, ATTRIB_DRAIN_HEALTH);
			TF2Attrib_RemoveByDefIndex(entityIndex, ATTRIB_HEALTH_PENALTY);
			TF2Attrib_ClearCache(entityIndex); // This will refresh health max calculation

			// Don't use that code for survivor though, you may end up regenerating them mid game..
			int iMaxHealth = SDK_GetMaxHealth(iClient);
			SetEntProp(iClient, Prop_Send, "m_iHealth", iMaxHealth);
		}
	}

	if (IsSurvivor(iClient))
	{
		// no double ammo when equipping a "jump training" weapon
		if (strcmp(classname, "tf_weapon_rocketlauncher") == 0 || strcmp(classname, "tf_weapon_pipebomblauncher") == 0)
		{
			TF2Attrib_SetByDefIndex(entityIndex, ATTRIB_MAXAMMO_INCREASE, 1.0);
			TF2Attrib_ClearCache(entityIndex);
		}
	}
}

public Action CommandListener_Build(int iClient, const char[] command, int argc)
{
	if (!iClient) return Plugin_Continue;

	// Get arguments
	char sObjectMode[32];
	GetCmdArg(1, sObjectMode, sizeof(sObjectMode));

	int iObjectType = StringToInt(sObjectMode);

	// if not sentry or dispenser, then block building
	if (iObjectType != OBJECT_ID_DISPENSER && iObjectType != OBJECT_ID_SENTRY) return Plugin_Handled;

	return Plugin_Continue;
}

public Action Server_ZombieRage(int iArgs)
{
	char duration[256];

	GetCmdArgString(duration, sizeof(duration));
	float flDuration = StringToFloat(duration);

	ZombieRage(flDuration);

	return Plugin_Handled;
}

public Action Server_Tank(int iArgs)
{
	ZombieTank();
	return Plugin_Handled;
}

public Action Admin_ForceBoomer(int iClient, int iArgs)
{
	if (IsZombie(iClient)) g_iNextSpecialInfected[iClient] = INFECTED_BOOMER;
	return Plugin_Handled;
}

public Action Admin_ForceCharger(int iClient, int iArgs)
{
	if (IsZombie(iClient)) g_iNextSpecialInfected[iClient] = INFECTED_CHARGER;
	return Plugin_Handled;
}

public Action Admin_ForceScreamer(int iClient, int iArgs)
{
	if (IsZombie(iClient)) g_iNextSpecialInfected[iClient] = INFECTED_KINGPIN;
	return Plugin_Handled;
}

public Action Admin_ForcePredator(int iClient, int iArgs)
{
	if (IsZombie(iClient)) g_iNextSpecialInfected[iClient] = INFECTED_STALKER;
	return Plugin_Handled;
}

public Action Admin_ForceHopper(int iClient, int iArgs)
{
	if (IsZombie(iClient)) g_iNextSpecialInfected[iClient] = INFECTED_HUNTER;
	return Plugin_Handled;
}

public Action Admin_ForceSmoker(int iClient, int iArgs)
{
	if (IsZombie(iClient)) g_iNextSpecialInfected[iClient] = INFECTED_SMOKER;
	return Plugin_Handled;
}

public Action Admin_ZombieTank(int iClient, int iArgs)
{
	ZombieTank(iClient); // try to call one
	return Plugin_Handled;
}

//
// Cookies
//
public void OnClientCookiesCached(int iClient)
{
	// to keep in mind: null = 0
	char cValue[8];
	
	GetClientCookie(iClient, cookieNoMusicForPlayer, cValue, sizeof(cValue));
	g_bNoMusicForClient[iClient] = view_as<bool>(StringToInt(cValue));

	GetClientCookie(iClient, cookiePreferredTeam, cValue, sizeof(cValue));
	g_iPreferredTeam[iClient] = StringToInt(cValue); 

	// TODO: add team preference cookie, if that gets approved
}

public void OnConfigsExecuted()
{
	if (mapIsZF())
	{
		zfEnable();
	}
	else
	{
		GetConVarBool(g_cvarForceOn) ? zfEnable() : zfDisable();
	}

	setRoundState(RoundInit1);
}

public void OnMapEnd()
{
	// Close timer handles
	if (zf_tMain != INVALID_HANDLE)
	{
		CloseHandle_2(zf_tMain);
		zf_tMain = INVALID_HANDLE;
	}
	if (zf_tMainSlow != INVALID_HANDLE)
	{
		CloseHandle_2(zf_tMainSlow);
		zf_tMainSlow = INVALID_HANDLE;
	}

	if (zf_tMainFast != INVALID_HANDLE)
	{
		CloseHandle_2(zf_tMainFast);
		zf_tMainFast = INVALID_HANDLE;
	}
	if (zf_tHoarde != INVALID_HANDLE)
	{
		CloseHandle_2(zf_tHoarde);
		zf_tHoarde = INVALID_HANDLE;
	}
	setRoundState(RoundPost);
	g_bRoundActive = false;
	zfDisable();

	UnhookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger);
}

void GetMapSettingsByInfoTarget()
{
	int i = -1;
	char name[64];
	while ((i = FindEntityByClassname2(i, "info_target")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
		if (strcmp(name, "szf_survivalmode", false) == 0) g_bSurvival = true;
		if (strcmp(name, "szf_nomusic", false) == 0) g_bNoMusic = true;
		if (strcmp(name, "szf_director_notank", false) == 0) g_bNoDirectorTanks = true;
		if (strcmp(name, "szf_director_norage", false) == 0) g_bNoDirectorRages = true;
	}
}

public void OnClientPostAdminCheck(int iClient)
{
	if (!zf_bEnabled) return;

	CreateTimer(10.0, timer_initialHelp, iClient, TIMER_FLAG_NO_MAPCHANGE);

	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);

	g_iDamage[iClient] = GetAverageDamage();
}

public void OnClientDisconnect(int iClient)
{
	if (!zf_bEnabled) return;
	StopSoundSystem(iClient);
	DropCarryingItem(iClient);
	g_fLastPickup[iClient] = 0.0;
	g_fLastCallout[iClient] = 0.0;
	g_bMutationVote[iClient] = false;
	if (iClient == g_iZombieTank) g_iZombieTank = 0;
}

public void OnGameFrame()
{
	if (!zf_bEnabled) return;
	handle_gameFrameLogic();
}

////////////////////////////////////////////////////////////
//
// SDKHooks Callbacks
//
////////////////////////////////////////////////////////////

public void OnPreThinkPost(int iClient)
{
	if (!zf_bEnabled) return;

	if (IsValidLivingClient(iClient))
	{
		// handle speed bonus, if not slowed&dazed or in 'backstabbed' state
		if ( (!isSlowed(iClient) && !isDazed(iClient)) || g_bBackstabbed[iClient] )
		{
			float speed = clientBaseSpeed(iClient) + clientBonusSpeed(iClient);
			setClientSpeed(iClient, speed);
		}

		// handle hunter-specific logic.
		if (IsZombie(iClient) && g_iSpecialInfected[iClient] == INFECTED_HUNTER && g_bHopperIsUsingPounce[iClient])
		{
			if (GetEntityFlags(iClient) & FL_ONGROUND == FL_ONGROUND)
			{
				g_bHopperIsUsingPounce[iClient] = false;
			}
		}
	}

	UpdateClientCarrying(iClient);
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflicter, float &fDamage, int &iDamagetype, int &iWeapon, float fForce[3], float fForcePos[3], int iDamageCustom)
{
	if (!zf_bEnabled) return Plugin_Continue;
	if (!CanRecieveDamage(iVictim)) return Plugin_Continue;

	bool bChanged = false;
	if (IsValidClient(iVictim) && IsValidClient(iAttacker))
	{
		g_bHitOnce[iVictim] = true;
		g_bHitOnce[iAttacker] = true;
		if (GetClientTeam(iVictim) != GetClientTeam(iAttacker))
		{
			EndGracePeriod();
		}
	}

	if (IsValidClient(iVictim) && g_iSuperHealth[iVictim] > 0)
	{
		g_iSuperHealth[iVictim] -= RoundFloat(fDamage);
		if (g_iSuperHealth[iVictim] < 0) g_iSuperHealth[iVictim] = 0;
		bChanged = true;

		int iMaxHealth = RoundFloat(float(SDK_GetMaxHealth(iVictim)) * 1.5);
		SetEntityHealth(iVictim, iMaxHealth);
	}

	if (iVictim != iAttacker)
	{
		// any player attacker under 300 damage
		if (IsValidLivingClient(iAttacker) && fDamage < 300.0)
		{
			// Damage scaling Zombies
			if (IsValidZombie(iAttacker))
			{
				fDamage = fDamage * g_fZombieDamageScale * 0.7; // default: 0.7

				// Scouts get additional damage reduction
				if (isScout(iAttacker)) fDamage *= 0.825;
			}

			// Damage scaling Survivors
			if (IsValidSurvivor(iAttacker) && !entIsSentry(iInflicter))
			{
				float flMoraleBonus = fMax(GetMorale(iAttacker) * 0.002, 0.2); // 0.2% for each morale point, 100 morale equals 20% damage bonus
				fDamage = fDamage / g_fZombieDamageScale * (1.1 + flMoraleBonus); // default: 1.1
			}

			bChanged = true;
		}

		// any survivor victim, any infected attacker
		if (IsValidSurvivor(iVictim) && IsValidZombie(iAttacker))
		{
			// Has the "stunned" state
			if (g_bBackstabbed[iVictim])
			{
				fDamage = fMin(fDamage * 0.6, 15.0);
				// make backstabs normal
				iDamagetype &= ~DMG_CRIT;
				iDamageCustom = 0;
				bChanged = true;
			}

			// Survivor using Pain Train
			if (isEquipped(iVictim, 333)) 
			{
				fDamage *= 1.1;
				bChanged = true;
			}

			// track damage dealt as tank
			if (g_iZombieTank > 0 && g_iZombieTank == iAttacker)
			{
				g_fTankDamageDealt += fDamage;
			}

			// reduce damage from crit amplifying items when active
			if (TF2_IsPlayerInCondition(iAttacker, TFCond_CritCola) || TF2_IsPlayerInCondition(iAttacker, TFCond_Buffed) || TF2_IsPlayerInCondition(iAttacker, TFCond_CritHype))
			{
				fDamage *= 0.66;
				bChanged = true;
			}

			// Get iWeapon's item index
			int iWeaponIndex = (IsValidEdict(iWeapon) && iWeapon > MaxClients ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
			// Weapons with a specific use case / modification go here
			switch (iWeaponIndex)
			{
				case ZFWEAP_MITTENS: // Mittens, this is a weaker backstab.
				{
					if (iDamagetype & DMG_CRIT)
					{
						if (!g_bBackstabbed[iVictim])
						{
							SetNextAttack(iAttacker, GetGameTime() + 1.25);
							SetBackstabState(iVictim, 1.0, 1.0);
							CreateTimer(1.0, TimerStopTickle, iVictim, TIMER_FLAG_NO_MAPCHANGE);
						}
						
						// change damage to prevent taunt-kill
						fDamage = 10.0;
						bChanged = true;
					}
				}
			}

			// if not in a stunned state - taunts, backstabs and very high critical damage
			if (fDamage >= SDK_GetMaxHealth(iVictim) - 20 || iDamageCustom == TF_CUSTOM_TAUNT_HIGH_NOON || iDamageCustom == TF_CUSTOM_TAUNT_GRAND_SLAM || iDamageCustom == TF_CUSTOM_BACKSTAB)
			{
				if (!g_bBackstabbed[iVictim])
				{
					bool bShow = true; // show annotation?
					SetBackstabState(iVictim, BACKSTABDURATION_FULL, 0.25);
					SetNextAttack(iAttacker, GetGameTime() + 1.25);

					fDamage = 15.0;
					if (g_iSpecialInfected[iAttacker] == INFECTED_STALKER) fDamage *= 1.5;
					bChanged = true;

					// basically, on kill becomes on hit
					switch (iWeaponIndex)
					{
						case 225, 574: // YER, Wanga Prick
						{
							bShow = false; // no indicator / silent
						}

						case 356: // Conniver's Kunai 
						{
							SetEntityHealth(iAttacker, 200);
						}

						case 461: // Big Earner
						{
							if (getCloak(iAttacker) < 66.0) setCloak(iAttacker, 66.0);
							TF2_AddCondition(iAttacker, TFCond_SpeedBuffAlly, 3.0);
						}
					}

					// show annotation and play sound
					if (bShow)
					{
						// show annotation
						ShowAnnotationOnObject(iVictim, "Stunned", surTeam());
						// play sound around the victim
						int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_NEARDEATH2]-1);
						char strPath[PLATFORM_MAX_PATH];
						MusicGetPath(MUSIC_NEARDEATH2, iRandom, strPath, sizeof(strPath));
						EmitSoundToAll(strPath, iVictim);
					}
				}
				else
				{
					fDamage = fMin(fDamage * 0.6, 15.0);
					// make backstabs normal
					iDamagetype &= ~DMG_CRIT;
					iDamageCustom = 0;
				}
			}
			

			// tank, play voice file on every succesful hit against survivor
			if (g_iSpecialInfected[iAttacker] == INFECTED_TANK)
			{
				SZF_EmitZombieVoiceToAll("tank_attack", iAttacker, GetRandomInt(1, 4));
			}

			// damage tracking and final limiting
			if (fDamage > 0.0)
			{
				int iDamage = RoundFloat(fDamage);
				if (iDamage > 300) iDamage = 300;
				g_iDamage[iAttacker] += iDamage;
			}

			// increase damage survivors take from zombies when glass cannon mutation is on
			if (IsMutationActive(MUTATION_GLASSCANNON))
			{
				fDamage *= 3.0;
				bChanged = true;
			}

			// hell zombies make survivors burn, duh
			if (IsMutationActive(MUTATION_HELL) && !TF2_IsPlayerInCondition(iVictim, TFCond_OnFire))
			{
				TF2_IgnitePlayer(iVictim, iAttacker);
			}
		}

		// any infected victim
		if (IsValidZombie(iVictim))
		{
			// for heavy, cap damage to 150, zero down physics force, disable physics force
			if (isHeavy(iVictim))
			{
				if (fDamage > 200.0 && fDamage <= 500.0) fDamage = 200.0;
				ScaleVector(fForce, 0.0);
				iDamagetype |= DMG_PREVENT_PHYSICS_FORCE;
				bChanged = true;
			}

			// disable physics force from sentry
			if (entIsSentry(iInflicter))
			{
				iDamagetype |= DMG_PREVENT_PHYSICS_FORCE;
			}

			// any survivor attacker
			if (IsValidSurvivor(iAttacker))
			{
				// tank victim
				if (g_iSpecialInfected[iVictim] == INFECTED_TANK)
				{
					// "SHOOT THAT TANK" voice call
					if (g_fDamageDealtAgainstTank[iAttacker] == 0)
					{
						if (isSoldier(iAttacker))
						{
							int iRandom = GetRandomInt(0, sizeof(g_strTankATK_Soldier)-1);
							EmitSoundToAll(g_strTankATK_Soldier[iRandom], iAttacker, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
						}

						if (isEngineer(iAttacker))
						{
							int iRandom = GetRandomInt(0, sizeof(g_strTankATK_Engineer)-1);
							EmitSoundToAll(g_strTankATK_Engineer[iRandom], iAttacker, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
						}

						if (isMedic(iAttacker))
						{
							int iRandom = GetRandomInt(0, sizeof(g_strTankATK_Medic)-1);
							EmitSoundToAll(g_strTankATK_Medic[iRandom], iAttacker, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
						}
					}

					g_fDamageDealtAgainstTank[iAttacker] += fDamage;
					// already applied before in the isHeavy line
					// ScaleVector(fForce, 0.0);
					// iDamagetype |= DMG_PREVENT_PHYSICS_FORCE;
				}

				// increase damage taken from crit amplifying items when active
				if (TF2_IsPlayerInCondition(iVictim, TFCond_CritCola) || TF2_IsPlayerInCondition(iVictim, TFCond_Buffed) || TF2_IsPlayerInCondition(iVictim, TFCond_CritHype))
				{
					fDamage *= 1.5;
					bChanged = true;
				}

				// melee hits also damage players around the zombie
				if (IsValidEdict(iWeapon) && GetPlayerWeaponSlot(iAttacker, TFWeaponSlot_Melee) == iWeapon)
				{
					// get survivor position
					float flPosZombie[3];
					float flPosZombieSplash[3];
					GetClientEyePosition(iVictim, flPosZombie);
					
					// get weapon classname
					char strClassname[64];
					GetEdictClassname(iWeapon, strClassname, sizeof(strClassname));
					
					// go through each client
					for (int i = 1; i <= MaxClients; i++)
					{
						// not the initial victim and a zombie
						if (i == iVictim) continue;
						if (!IsValidLivingZombie(i)) continue;

						GetClientEyePosition(i, flPosZombieSplash);
						if (GetVectorDistance(flPosZombie, flPosZombieSplash) <= 30.0)
						{
							// this is it
							DealDamage(i, RoundToFloor(fDamage * 0.6), iAttacker, iDamagetype, strClassname);

							// bleed
							float flBleedDuration = 0.0;
							if (TF2_WeaponFindAttribute(iWeapon, 149, flBleedDuration) && flBleedDuration > 0.0)
							{
								TF2_MakeBleed(iVictim, iAttacker, flBleedDuration);
							}

							// ignite
							float flIgnite = 0.0;
							if (TF2_WeaponFindAttribute(iWeapon, 208, flIgnite) && flIgnite != 0.0)
							{
								TF2_IgnitePlayer(iVictim, iAttacker);
							}
						}
					}
				}

				// increase damage zombies take when glass cannon mutation is on
				if (IsMutationActive(MUTATION_GLASSCANNON))
				{
					fDamage *= 3.0;
					bChanged = true;
				}
			}
		}

		// any player attacker, any player victim
		if (IsValidClient(iVictim) && IsValidClient(iAttacker) && iAttacker != iVictim)
		{
			// track these stats
			g_fDamageTakenLife[iVictim] += fDamage;
			g_fDamageDealtLife[iAttacker] += fDamage;
		}
	}

	if (bChanged) return Plugin_Changed;
	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Client Console / Chat Command Handlers
//
////////////////////////////////////////////////////////////
public Action hook_JoinTeam(int iClient, const char[] command, int argc)
{
	char cmd1[32];
	char sSurTeam[16];
	char sZomTeam[16];
	char sZomVgui[16];

	if (!zf_bEnabled) return Plugin_Continue;
	if (argc < 1) return Plugin_Handled;

	GetCmdArg(1, cmd1, sizeof(cmd1));

	if (roundState() >= RoundGrace)
	{
		// Assign team-specific strings
		if (zomTeam() == view_as<int>(TFTeam_Blue))
		{
			sSurTeam = "red";
			sZomTeam = "blue";
			sZomVgui = "class_blue";
		}
		else
		{
			sSurTeam = "blue";
			sZomTeam = "red";
			sZomVgui = "class_red";
		}

		// If iClient tries to join the survivor team or a random team
		// during grace period or active round, place them on the zombie
		// team and present them with the zombie class select screen.
		if (StrEqual(cmd1, sSurTeam, false) || StrEqual(cmd1, "auto", false))
		{
			ChangeClientTeam(iClient, zomTeam());
			ShowVGUIPanel(iClient, sZomVgui);
			return Plugin_Handled;
		}
		// If iClient tries to join the zombie team or spectator
		// during grace period or active round, let them do so.
		else if (StrEqual(cmd1, sZomTeam, false) || StrEqual(cmd1, "spectate", false))
		{
			return Plugin_Continue;
		}
		// Prevent joining any other team.
		else
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action hook_JoinClass(int iClient, const char[] command, int argc)
{
	char cmd1[32];

	if (!zf_bEnabled) return Plugin_Continue;
	if (argc < 1) return Plugin_Handled;

	GetCmdArg(1, cmd1, sizeof(cmd1));

	if (IsZombie(iClient))
	{
		// If an invalid zombie class is selected, print a message and
		// accept joinclass command. ZF spawn logic will correct this
		// issue when the player spawns.
		if (!(StrEqual(cmd1, "scout", false) || StrEqual(cmd1, "spy", false) ||  StrEqual(cmd1, "heavyweapons", false)))
		{
			CPrintToChat(iClient, "{greenyellow}[SZF] {red}Valid zombies: Scout, Heavy and Spy");
		}
	}

	else if (IsSurvivor(iClient))
	{
		// Prevent survivors from switching classes during the round.
		if (roundState() == RoundActive)
		{
			CPrintToChat(iClient, "{greenyellow}[SZF] {red}Survivors can't change classes during a round.");
			return Plugin_Handled;
		}
		// If an invalid survivor class is selected, print a message
		// and accept the joincalss command. ZF spawn logic will
		// correct this issue when the player spawns.
		else if (!(StrEqual(cmd1, "soldier", false) ||
			StrEqual(cmd1, "pyro", false) ||
			StrEqual(cmd1, "demoman", false) ||
			StrEqual(cmd1, "engineer", false) ||
			StrEqual(cmd1, "medic", false) ||
			StrEqual(cmd1, "sniper", false)))
		{
			CPrintToChat(iClient, "{greenyellow}[SZF] {red}Valid survivors: Soldier, Pyro, Demo, Engineer, Medic and Sniper.");
		}
	}

	return Plugin_Continue;
}

public Action hook_VoiceMenu(int iClient, const char[] command, int argc)
{
	char cmd1[32];
	char cmd2[32];

	if (!zf_bEnabled) return Plugin_Continue;
	if (argc < 2) return Plugin_Handled;

	GetCmdArg(1, cmd1, sizeof(cmd1));
	GetCmdArg(2, cmd2, sizeof(cmd2));

	// Capture call for medic commands (represented by "voicemenu 0 0").
	// Activate zombie Rage ability (150% health), if possible. Rage
	// can't be activated below full health or if it's already active.
	// Rage recharges after 30 seconds.
	if (StrEqual(cmd1, "0") && StrEqual(cmd2, "0") && IsPlayerAlive(iClient))
	{
		if (IsSurvivor(iClient))
		{
			// recently did a succesful pickup, prevent voicemenu spam
			if (g_fLastPickup[iClient] + PICKUP_COOLDOWN > GetGameTime()) return Plugin_Continue;

			// succesful weapon grab, block it
			if (AttemptCarryItem(iClient) || AttemptGrabItem(iClient)) return Plugin_Handled;

			// has more or equal to maximum health, block it
			// int curH = GetClientHealth(iClient);
			// int maxH = SDK_GetMaxHealth(iClient);
			// if (curH >= maxH) return Plugin_Handled;

			return Plugin_Continue;
		}

		// no need to else if since above will end the code execution if carry is succesful
		if (IsZombie(iClient))
		{
			if (g_bRoundActive && g_iNextSpecialInfected[iClient] != INFECTED_NONE && g_bReplaceRageWithSpecialInfectedSpawn[iClient])
			{
				if (iClient != g_iZombieTank) g_iSpecialInfected[iClient] = g_iNextSpecialInfected[iClient];
				g_iNextSpecialInfected[iClient] = INFECTED_NONE;
				g_bReplaceRageWithSpecialInfectedSpawn[iClient] = false;

				TF2_RespawnPlayer(iClient);
				// CreateTimer(0.1, timer_postSpawn, iClient, TIMER_FLAG_NO_MAPCHANGE);

				// broadcast to team
				char strName[80];
				SZF_GetClientName(iClient, strName, sizeof(strName));

				// format final message string
				char strMessage[255];
				Format(strMessage, sizeof(strMessage), "(TEAM) %s\x01 : I have used my {green}quick respawn into special infected\x01!", strName);
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i) && GetClientTeam(i) == GetClientTeam(iClient))
					{
						CPrintToChat(i, strMessage);
					}
				}
			}
			else if (GetRageCooldown(iClient) == 0)
			{
				if (g_iSpecialInfected[iClient] == INFECTED_NONE)
				{
					SetRageCooldown(iClient, 30);
					DoGenericRage(iClient);
				}

				if (g_iSpecialInfected[iClient] == INFECTED_BOOMER && g_bRoundActive)
				{
					// sound is inside doboomerexplosion
					DoBoomerExplosion(iClient, 600.0);
				}

				if (g_iSpecialInfected[iClient] == INFECTED_CHARGER && isGrounded(iClient))
				{
					SetRageCooldown(iClient, 20);
					TF2_AddCondition(iClient, TFCond_Charging, 1.55);
					SZF_EmitZombieVoiceToAll("charger_charge", iClient, GetRandomInt(1, 2));
				}

				if (g_iSpecialInfected[iClient] == INFECTED_KINGPIN)
				{
					SetRageCooldown(iClient, 20);
					DoKingpinRage(iClient, 600.0);

					char strPath[64];
					Format(strPath, sizeof(strPath), "ambient/halloween/male_scream_%i.wav", GetRandomInt(15, 16));
					EmitSoundToAll(strPath, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}

				if (g_iSpecialInfected[iClient] == INFECTED_HUNTER)
				{
					SetRageCooldown(iClient, 3);
					DoHunterJump(iClient);
					SZF_EmitZombieVoiceToAll("hunter_attackmix", iClient, GetRandomInt(1, 3));
				}
			}

			else
			{
				ClientCommand(iClient, "voicemenu 2 5");
				PrintHintText(iClient, "Can't Activate Rage!");
			}

			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action cmd_zfMenu(int iClient, int iArgs)
{
	if (!zf_bEnabled) return Plugin_Continue;
	panel_PrintMain(iClient);

	return Plugin_Handled;
}

public Action cmd_zfMusicToggle(int iClient, int iArgs)
{
	if (IsValidClient(iClient))
	{
		char cPreference[32];

		if (g_bNoMusicForClient[iClient])
		{
			g_bNoMusicForClient[iClient] = false;
			CPrintToChat(iClient, "{greenyellow}[SZF] {green}Music has been enabled.");
		}
		else if (!g_bNoMusicForClient[iClient])
		{
			g_bNoMusicForClient[iClient] = true;
			CPrintToChat(iClient, "{greenyellow}[SZF] {red}Music has been disabled.");
		}

		Format(cPreference, sizeof(cPreference), "%i", g_bNoMusicForClient[iClient]);
		SetClientCookie(iClient, cookieNoMusicForPlayer, cPreference);
	}

	return Plugin_Handled;
}

public Action cmd_zfVoteMutation(int iClient, int iArgs)
{
	// minimum player count
	if (GetConnectingCount() < GetConVarInt(g_cvarMutationMinPlayers))
	{
		CPrintToChatAll("{greenyellow}[SZF] {red}A minimum of 6 players is required to be able to vote for mutation.");
		return Plugin_Handled;
	}

	// mutation already planned or active
	if (g_bMutationNextRound || g_bMutationActive)
	{
		CPrintToChatAll("{greenyellow}[SZF] {red}Mutation mode is already active or will be active on the next round.");
		return Plugin_Handled;
	}

	// already voted
	if (g_bMutationVote[iClient]) return Plugin_Handled;

	// valid client check
	if (IsValidClient(iClient))
	{
		char strPlayerName[64];
		char strMessage[255];

		g_bMutationVote[iClient] = true;

		int iVotes = GetMutationVotes();

		// get name and format message
		SZF_GetClientName(iClient, strPlayerName, sizeof(strPlayerName));
		Format(strMessage, sizeof(strMessage), "{greenyellow}[SZF] %s\x01 has voted to enable the {yellow}'%s'\x01-mutation. (%d/%d votes, {greenyellow}/votem\x01)", strPlayerName, g_strMutationTitles[GetActiveMutation()-1], iVotes, GetMutationVotesNeeded());

		// print it
		CPrintToChatAll(strMessage);
		EmitSoundToAll("left4fortress/ui/beep_synthtone01.mp3");

		// if this vote made it reach the threshold, print another message and do stuff
		if (iVotes >= GetMutationVotesNeeded())
		{
			// reset votes
			ResetMutationVotes();

			// set for next round
			g_bMutationNextRound = true;

			// get name and format message
			Format(strMessage, sizeof(strMessage), "{greenyellow}[SZF] {green}Enough votes reached, the {yellow}'%s'\x01-mutation will be enabled in the next round.", g_strMutationTitles[GetActiveMutation()-1]);

			// print message
			CPrintToChatAll(strMessage);
			EmitSoundToAll("left4fortress/ui/menu_enter05.mp3");
		}
	}

	return Plugin_Handled;
}



//
// Round Start Event
//
public Action event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;

	DetermineControlPoints();
	SetPickupWeapons();

	zf_lastSurvivor = false;

	int players[MAXPLAYERS+1] = 0;
	int playerCount;
	int surCount;

	g_StartTime = GetTime();
	g_AdditionalTime = 0;

	int i;
	for (i = 1; i <= MaxClients; i++)
	{
		g_iDamage[i] = 0;
		g_iKillsThisLife[i] = 0;
		g_iSpecialInfected[i] = INFECTED_NONE;
		g_iNextSpecialInfected[i] = INFECTED_NONE;
		g_bReplaceRageWithSpecialInfectedSpawn[i] = false;
		g_iSuperHealth[i] = 0;
		g_iSuperHealthSubtract[i] = 0;
	}

	g_iZombieTank = 0;
	g_bTankOnce = false;
	RemoveAllGoo();

	//
	// Handle round state.
	// + "teamplay_round_start" event is fired twice on new map loads.
	//
	if (roundState() == RoundInit1)
	{
		setRoundState(RoundInit2);
		return Plugin_Continue;
	}
	else
	{
		setRoundState(RoundGrace);
		CPrintToChatAll("{greenyellow}[SZF] {green}Grace period begun. Survivors can change classes.");
	}

	//
	// Assign players to zombie and survivor teams.
	//
	if (zf_bNewRound)
	{
		// Find all active players.
		playerCount = 0;
		for(i = 1; i <= MaxClients; i++)
		{
			zf_spawnZombiesKilledSurvivor[i] = 0;

			if (IsValidPlayer(i))
			{
				players[playerCount] = i;
				playerCount++;
			}
		}

		// Randomize, sort players
		SortIntegers(players, playerCount, Sort_Random);
		// NOTE: As of SM 1.3.1, SortIntegers w/ Sort_Random doesn't
		//             sort the first element of the array. Temp fix below.
		int idx = GetRandomInt(0,playerCount-1);
		int temp = players[idx];
		players[idx] = players[0];
		players[0] = temp;

		// Calculate team counts. At least one survivor must exist.
		surCount = RoundToFloor(playerCount*GetConVarFloat(g_cvarRatio));
		int zomCount = 0;
		// if the calculation above returns 0 for survivor count, force it to 1 if there is any player on
		if (surCount == 0 && playerCount > 0) surCount = 1;

		// Assign active players to survivor and zombie teams.
		g_iStartSurvivors = 0;
		bool bSurvivors[MAXPLAYERS+1] = false;

		// find players who have started last round as a zombie and _try_ to make them not a zombie again
		for (i = 0; i <= playerCount; i++)
		{
			// players who have:
			// - started as infected in the previous round get in as survivor
			// - set their preference for survivor team have a 33% to be seeded
			if ( IsValidClient(players[i]) &&
				(g_bStartedAsZombie[players[i]] || (g_iPreferredTeam[players[i]] > 1 && g_iPreferredTeam[players[i]] == surTeam() && !GetRandomInt(0, 2) ) ) ) 
			{
				SpawnClient(players[i], surTeam());
				bSurvivors[players[i]] = true;
				g_iStartSurvivors++;
				surCount--;
			}

			// recount this boolean later in the code
			g_bStartedAsZombie[players[i]] = false;
		}

		i = 1;
		while (surCount > 0 && i <= playerCount)
		{
			int iClient = players[i];
			if (IsValidClient(iClient) && !bSurvivors[players[i]])
			{
				bool bGood = true;
				// ur a good boy, a survivor!
				if (bGood)
				{
					SpawnClient(iClient, surTeam());
					bSurvivors[iClient] = true;
					g_iStartSurvivors++;
					surCount--;
				}
			}
			i++;
		}

		// get all players again, focus on people are not on a zombie team yet or if we need to still have an actual zombie
		for (i = 0; i <= playerCount; i++)
		{
			if (IsValidPlayer(players[i]) && (zomCount < 1 || !bSurvivors[players[i]]))
			{
				// spawn as zombie
				SpawnClient(players[i], zomTeam());
				zomCount++;
				// no zombie next round :-)
				g_bStartedAsZombie[players[i]] = true;
			}
		}
	}

	// Reset counters
	zf_spawnSurvivorsKilledCounter = 0;
	zf_spawnZombiesKilledCounter = 0;
	zf_spawnZombiesKilledSpree = 0;
	zf_pointsCaptured = 0;
	if (g_bMutationNextRound) g_bMutationActive = true; // set mutation to active

	// Handle grace period timers.
	CreateTimer(0.5, timer_graceStartPost, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(45.0, timer_graceEnd, TIMER_FLAG_NO_MAPCHANGE);

	SetGlow();
	UpdateZombieDamageScale();

	return Plugin_Continue;
}

//
// Setup End Event
//
public Action event_SetupEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;

	EndGracePeriod();

	g_StartTime = GetTime();
	g_AdditionalTime = 0;
	g_bRoundActive = true;

	return Plugin_Continue;
}

void EndGracePeriod()
{
	if (!zf_bEnabled) return;

	if (roundState() == RoundActive) return;
	if (roundState() == RoundPost) return;

	setRoundState(RoundActive);
	CPrintToChatAll("{greenyellow}[SZF] {orange}Grace period complete. Survivors can no longer change classes.");

	int iSurvivors = GetSurvivorCount();
	int iZombies = GetZombieCount();
	int iConnecting = GetConnectingCount();

	// buff survivors if these conditions are met:
	// first round
	// 16 or more people are still connecting
	// 4 survivors or less are in the team
	if (g_bFirstRound && iConnecting >= 16 && iSurvivors <= 4)
	{
		// for loop
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				if (IsSurvivor(i) && IsPlayerAlive(i))
				{
					SetEntityHealth(i, 300);
				}

				CPrintToChat(i, "{greenyellow}[SZF] %sSurvivors have received extra health due to being in a heavy disadvantage in the first round.", (IsZombie(i)) ? "{red}" : "{green}");
			}
		}
	}

	else if (iZombies <= 6 && iSurvivors >= 18)
	{
		// for loop
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				if (IsZombie(i))
				{
					if (IsPlayerAlive(i))
					{
						SetEntityHealth(i, 300);
						TF2_AddCondition(i, TFCond_DefenseBuffed, -1.0);
					}

					g_iNextSpecialInfected[i] = GetRandomInt(INFECTED_BOOMER, INFECTED_MAX);
				}

				CPrintToChat(i, "{greenyellow}[SZF] %sInfected have received extra health and other benefits to ensure game balance at the start of the round.", (IsZombie(i)) ? "{green}" : "{red}");
			}
		}
	}

	g_bFirstRound = false;
	g_flTankCooldown = GetGameTime() + 90.0 - fMax(0.0, (iSurvivors-12) * 3.0); // 2 min cooldown before tank spawns will be considered
	g_flSelectSpecialCooldown = GetGameTime() + 90.0 - fMax(0.0, (iSurvivors-12) * 3.0); // 2 min cooldown before mid-spawn special selection will be considered
	g_flRageCooldown = GetGameTime() + 45.0 - fMax(0.0, (iSurvivors-12) * 1.5); // 1 min cooldown before frenzy will be considered
}

//
// Round End Event
//
public Action event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;

	//
	// Prepare for a completely new round, if
	// + Round was a full round (full_round flag is set), OR
	// + Zombies are the winning team.
	//
	zf_bNewRound = GetEventBool(event, "full_round") || (event.GetInt("team") == zomTeam());
	setRoundState(RoundPost);

	if (event.GetInt("team") == zomTeam())
	{
		EmitSoundToAll("left4fortress/death.mp3");
	}

        if (event.GetInt("team") == surTeam())
	{
		/* TODO:
		** if (GetEventBool(event, "full_round")) [play 'final' we_survived]
		** else [play 'mid-round' we_survived]
		*/
		EmitSoundToAll("left4fortress/we_survived.mp3");
	}

	SetGlow();
	UpdateZombieDamageScale();
	g_bRoundActive = false;
	g_bTankRefreshed = false;
	if (g_bMutationActive) g_bMutationActive = false; // reset mutation

	return Plugin_Continue;
}

//
// Player Spawn Event
//
public Action event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;

	int iClient = GetClientOfUserId(event.GetInt("userid"));
	//StartSoundSystem(iClient, MUSIC_NONE);

	// reset overlay
	ClientCommand(iClient, "r_screenoverlay\"\"");

	g_iSuperHealth[iClient] = 0;
	g_iSuperHealthSubtract[iClient] = 0;
	g_bHitOnce[iClient] = false;
	g_bHopperIsUsingPounce[iClient] = false;
	g_iHitBonusCombo[iClient] = 0;
	g_bBackstabbed[iClient] = false;
	g_iKillsThisLife[iClient] = 0;
	g_fDamageTakenLife[iClient] = 0.0;
	g_fDamageDealtLife[iClient] = 0.0;
	g_fLastPickup[iClient] = 0.0;
	g_fLastCallout[iClient] = 0.0;
	g_fLastRarePickup[iClient] = 0.0;
	g_iMoraleSkipTicks[iClient] = 3;

	DropCarryingItem(iClient, false);

	SetEntityRenderColor(iClient, 255, 255, 255, 255);
	SetEntityRenderMode(iClient, RENDER_NORMAL);

	if (roundState() == RoundActive)
	{
		if (g_iZombieTank > 0 && g_iZombieTank == iClient)
		{
			g_iSpecialInfected[iClient] = INFECTED_NONE;

			if (!isHeavy(iClient))
			{
				TF2_SetPlayerClass(iClient, TFClass_Heavy, true, true);
				TF2_RespawnPlayer(iClient);
				CreateTimer(0.1, timer_postSpawn, iClient, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Stop;
			}
			else
			{
				g_iZombieTank = 0;
				g_iSpecialInfected[iClient] = INFECTED_TANK;

				// Health (subtraction)
				int iSurvivors = GetSurvivorCount();
				int intHealth = GetConVarInt(g_cvarTankHealth) * iSurvivors;
				if (intHealth < GetConVarInt(g_cvarTankHealthMin)) intHealth = GetConVarInt(g_cvarTankHealthMin);
				if (intHealth > GetConVarInt(g_cvarTankHealthMax)) intHealth = GetConVarInt(g_cvarTankHealthMax);
				g_iSuperHealth[iClient] = intHealth;

				int iSubtract = 0;
				if (GetConVarFloat(g_cvarTankTime) > 0.0)
				{
					iSubtract = RoundFloat(float(intHealth) / GetConVarFloat(g_cvarTankTime));
					if (iSubtract < 3) iSubtract = 3;
				}
				g_iSuperHealthSubtract[iClient] = iSubtract;

				// Set some client stuff
				TF2_AddCondition(iClient, TFCond_Kritzkrieged, 999.0);
				SetEntityHealth(iClient, 450);

				// Green model color
				SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
				SetEntityRenderColor(iClient, 0, 255, 0, 255);
				PerformFastRespawn2(iClient);

				// Resize player
				ResizePlayer(iClient, 1.2);

				// Music!
				MusicHandleAll();

				// Broadcast message and set final variables
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i) && IsValidSurvivor(i))
					{
						InitiateTankTutorial(i);
						CPrintToChat(i, "{greenyellow}[SZF] {red}Incoming TAAAAANK!");
					}

					g_fDamageDealtAgainstTank[i] = 0.0;
				}

				g_fTankDamageDealt = 0.0;
			}
		}

		else
		{
			// if special needs mutation is active and no special infected state set, force it
			if (IsMutationActive(MUTATION_SPECIALNEEDS) && g_iSpecialInfected[iClient] == INFECTED_NONE)
			{
				g_iSpecialInfected[iClient] = GetRandomInt(INFECTED_BOOMER, INFECTED_MAX);
			}
			
			char strSpecialName[16];

			// heavy special infected
			if (g_iSpecialInfected[iClient] == INFECTED_BOOMER
				|| g_iSpecialInfected[iClient] == INFECTED_CHARGER)
			{
				if (!isHeavy(iClient))
				{
					TF2_SetPlayerClass(iClient, TFClass_Heavy, true, true);
					TF2_RespawnPlayer(iClient);
					CreateTimer(0.1, timer_postSpawn, iClient, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Stop;
				}

				SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
				// boomer
				if (g_iSpecialInfected[iClient] == INFECTED_BOOMER)
				{
					strSpecialName = "boomer";
					SetEntityRenderColor(iClient, 255, 255, 0, 255);
					
					//CPrintToChat(iClient, "{greenyellow}[SZF] {green}YOU ARE A BOOMER:\n{orange}- Call 'MEDIC!' to EXPLODE and JARATE nearby enemies!\n- You also explode upon dying, coating the killer and assister in JARATE.");
					//PrintCenterText(iClient, "YOU ARE A BOOMER!\nRead the chat for more information.");
					//strBacteriaFilePath = "left4fortress/boomerbacterias.mp3";
				}
				// charger
				if (g_iSpecialInfected[iClient] == INFECTED_CHARGER)
				{
					strSpecialName = "charger";
					SetEntityRenderColor(iClient, 255, 0, 0, 255);
					
					//CPrintToChat(iClient, "{greenyellow}[SZF] {green}YOU ARE A CHARGER:\n{orange}- Call 'MEDIC!' to CHARGE! {yellow}(16 second cooldown)");
					//PrintCenterText(iClient, "YOU ARE A CHARGER!\nRead the chat for more information.");
					//strBacteriaFilePath = "left4fortress/chargerbacterias.mp3";
				}
			}

			// scout special infected
			if (g_iSpecialInfected[iClient] == INFECTED_KINGPIN
				|| g_iSpecialInfected[iClient] == INFECTED_HUNTER)
			{
				if (!isScout(iClient))
				{
					TF2_SetPlayerClass(iClient, TFClass_Scout, true, true);
					TF2_RespawnPlayer(iClient);
					CreateTimer(0.1, timer_postSpawn, iClient, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Stop;
				}

				SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
				// hunter
				if (g_iSpecialInfected[iClient] == INFECTED_HUNTER)
				{
					strSpecialName = "hunter";
					SetEntityRenderColor(iClient, 255, 0, 0, 255);
					
					//CPrintToChat(iClient, "{greenyellow}[SZF] {green}YOU ARE A HUNTER:\n{orange}- Call 'MEDIC!' to LEAP and POUNCE ENEMY SURVIVORS! {yellow}(3 on miss & 21 on hit second cooldown)");
					//PrintCenterText(iClient, "YOU ARE A HUNTER!\nRead the chat for more information.");
				}
				// kingpin
				if (g_iSpecialInfected[iClient] == INFECTED_KINGPIN)
				{
					strSpecialName = "kingpin";
					SetEntityRenderColor(iClient, 150, 0, 255, 255);
					
					//CPrintToChat(iClient, "{greenyellow}[SZF] {green}YOU ARE A KINGPIN:\n{orange}- Call 'MEDIC!' to RALLY ALLIED ZOMBIES! {yellow}(21 second cooldown){orange}\n- Zombies standing near you are more powerful.");
					//PrintCenterText(iClient, "YOU ARE A KINGPIN!\nRead the chat for more information.");
				}
			}

			// spy special infected
			if (g_iSpecialInfected[iClient] == INFECTED_STALKER
				|| g_iSpecialInfected[iClient] == INFECTED_SMOKER)
			{
				if (!isSpy(iClient))
				{
					TF2_SetPlayerClass(iClient, TFClass_Spy, true, true);
					TF2_RespawnPlayer(iClient);
					CreateTimer(0.1, timer_postSpawn, iClient, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Stop;
				}

				SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
				// stalker
				if (g_iSpecialInfected[iClient] == INFECTED_STALKER)
				{
					strSpecialName = "stalker";
					SetEntityRenderColor(iClient, 50, 50, 50, 155);
					//CPrintToChat(iClient, "{greenyellow}[SZF] {green}YOU ARE A STALKER:\n{orange}- If not close to any survivors, you will be cloaked and gain super speed!\n- Your backstabs do more damage.");
					//PrintCenterText(iClient, "YOU ARE A STALKER!\nRead the chat for more information.");
				}
				// smoker
				if (g_iSpecialInfected[iClient] == INFECTED_SMOKER)
				{
					strSpecialName = "smoker";
					SetEntityRenderColor(iClient, 255, 0, 0, 255);
					//CPrintToChat(iClient, "{greenyellow}[SZF] {green}YOU ARE A SMOKER:\n{orange}- Right click to fire a beam to enemy players and pull them towards you! {yellow}(no cooldown)");
					//PrintCenterText(iClient, "YOU ARE A SMOKER!\nRead the chat for more information.");
				}
				// witch
				/*
				if (g_iSpecialInfected[iClient] == INFECTED_WITCH)
				{
					strSpecialName = "witch";
					SetEntityRenderColor(iClient, 255, 0, 0, 255);
					//CPrintToChat(iClient, "{greenyellow}[SZF] {green}YOU ARE A SMOKER:\n{orange}- Right click to fire a beam to enemy players and pull them towards you! {yellow}(no cooldown)");
					//PrintCenterText(iClient, "YOU ARE A SMOKER!\nRead the chat for more information.");
				}
				*/
			}

			// player is indeed special infected
			if (strlen(strSpecialName) > 0)
			{
				char strSurvivorAlertSound[PLATFORM_MAX_PATH];
				char strCenterText[PLATFORM_MAX_PATH];

				// play spawn sound to player
				EmitSoundToClient(iClient, "left4fortress/ui/pickup_scifi37.mp3");

				// increase size of players a tiny wee bit
				ResizePlayer(iClient, 1.05);

				// play special sound to survivors
				Format(strSurvivorAlertSound, sizeof(strSurvivorAlertSound), "left4fortress/bacteria/%sbacteria.mp3", strSpecialName);
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsValidLivingSurvivor(i)) continue;
					EmitSoundToClient(i, strSurvivorAlertSound);
				}

				// display message to player
				strSpecialName[0] = CharToLower(strSpecialName[0]);
				Format(strCenterText, sizeof(strCenterText), "You are a %s!\nRead the Panel for more information.", strSpecialName);
				PrintCenterText(iClient, strCenterText);

				// draw panel
				panel_PrintSpecial(iClient, g_iSpecialInfected[iClient]);

			}
		}
	}

	TFClassType clientClass = TF2_GetPlayerClass(iClient);

	resetClientState(iClient);
	// 1. Prevent players spawning on survivors if round has started.
	//        Prevent players spawning on survivors as an invalid class.
	//        Prevent players spawning on zombies as an invalid class.
	if (IsSurvivor(iClient))
	{
		if (roundState() == RoundActive)
		{
			SpawnClient(iClient, zomTeam());
			return Plugin_Continue;
		}

		if (!IsValidSurvivorClass(clientClass))
		{
			// this will call the last valid survivor class the client had, will work when going from zombie to survivor and when just selecting a non-valid survivor class
			if (IsValidSurvivorClass(g_tfClassLastSurvivorClass[iClient]))
			{
				SetEntProp(iClient, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(g_tfClassLastSurvivorClass[iClient]));
			}
			SpawnClient(iClient, surTeam());
			return Plugin_Continue;
		}

		// everything here below runs when player passed all checks
		g_tfClassLastSurvivorClass[iClient] = clientClass;
	}

	else if (IsZombie(iClient))
	{
		if (!IsValidZombieClass(clientClass))
		{
			SpawnClient(iClient, zomTeam());
			return Plugin_Continue;
		}

		if (roundState() == RoundActive)
		{
			if (g_iSpecialInfected[iClient] != INFECTED_TANK && !PerformFastRespawn(iClient))
			{
				TF2_AddCondition(iClient, TFCond_Ubercharged, 2.0);
			}
		}
	}

	// 2. Handle valid, post spawn logic
	CreateTimer(0.1, timer_postSpawn, iClient, TIMER_FLAG_NO_MAPCHANGE);

	SetGlow();
	UpdateZombieDamageScale();
	TankCanReplace(iClient);
	//HandleClientInventory(iClient);

	return Plugin_Continue;
}

//
// Player Death Event
//
public Action event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;

	int killers[2];
	int victim = GetClientOfUserId(event.GetInt("userid"));
	killers[0] = GetClientOfUserId(event.GetInt("attacker"));
	killers[1] = GetClientOfUserId(event.GetInt("assister"));

	ClientCommand(victim, "r_screenoverlay\"\"");

	DropCarryingItem(victim);

	// handle bonuses
	if (IsValidZombie(killers[0]) && killers[0] != victim)
	{
		g_iKillsThisLife[killers[0]]++;

		if (g_iKillsThisLife[killers[0]] <= 1) ShowBonus(killers[0], "zombie_kill"); // 1 kill
		if (g_iKillsThisLife[killers[0]] == 2) ShowBonus(killers[0], "zombie_kill_2"); // 2 kills
		if (g_iKillsThisLife[killers[0]] > 2) ShowBonus(killers[0], "zombie_kill_lot"); // >2 kills
		if (g_bBackstabbed[victim]) ShowBonus(killers[0], "zombie_stab_death"); // survivor died during backstab
		if (g_iKillsThisLife[killers[0]] == 3) TF2_AddCondition(killers[0], TFCond_DefenseBuffed, TFCondDuration_Infinite); // 3 kills, give buff

		// 50%
		if (g_iNextSpecialInfected[killers[0]] == INFECTED_NONE && !GetRandomInt(0, 1) && g_bRoundActive == true)
		{
			g_iNextSpecialInfected[killers[0]] = GetRandomInt(INFECTED_BOOMER, INFECTED_MAX);

			if (g_iSpecialInfected[killers[0]] == INFECTED_NONE)
			{
				g_bReplaceRageWithSpecialInfectedSpawn[killers[0]] = true;
			}
		}

	}

	if (IsValidZombie(killers[1]) && killers[1] != victim)
	{
		ShowBonus(killers[1], "zombie_assist"); // you did an assist, good job!
		// 33%
		if (g_iNextSpecialInfected[victim] == INFECTED_NONE && !GetRandomInt(0, 2) && g_bRoundActive == true)
		{
			g_iNextSpecialInfected[killers[1]] = GetRandomInt(INFECTED_BOOMER, INFECTED_MAX);
		}
	}

	// the tank's dead
	if (g_iSpecialInfected[victim] == INFECTED_TANK)
	{
		g_iDamage[victim] = GetAverageDamage();

		int iWinner = 0;
		float fHighest = 0.0;

		SZF_EmitZombieVoiceToAll("tank_death", victim, GetRandomInt(1, 4));

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidLivingSurvivor(i))
			{
				// if (g_fDamageDealtAgainstTank[i] > 0.0)
				// {
				// }

				// calculate highest damage done
				if (fHighest < g_fDamageDealtAgainstTank[i])
				{
					fHighest = g_fDamageDealtAgainstTank[i];
					iWinner = i;
				}

				// add morale
				AddMorale(i, 35);
			}
		}

		if (fHighest > 0.0)
		{
			SetHudTextParams(-1.0, 0.3, 8.0, 200, 255, 200, 128, 1);

			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i))
				{
					ShowHudText(i, -1, "The Tank '%N' has died\nMost damage: %N (%d)", victim, iWinner, RoundFloat(fHighest));

				}
			}
		}

		if (g_fTankDamageDealt <= 50.0 && !g_bTankRefreshed)
		{
			g_bTankRefreshed = true;
			ZombieTank();
		}
	}

	g_ShouldBacteriaPlay[victim] = true;
	g_bReplaceRageWithSpecialInfectedSpawn[victim] = false;
	int g_iSpecialInfectedIndex = g_iSpecialInfected[victim];
	g_iSpecialInfected[victim] = INFECTED_NONE;

	// Handle zombie death logic, all round states.
	if (IsValidZombie(victim))
	{
		// 10%
		if (IsValidSurvivor(killers[0]) && !GetRandomInt(0, 9) && g_bRoundActive == true)
		{
			g_iNextSpecialInfected[victim] = GetRandomInt(INFECTED_BOOMER, INFECTED_MAX);
		}

		// force removal of cloak condition, seems to be causing the arm bug (?)
		if (TF2_IsPlayerInCondition(victim, TFCond_Cloaked))
		{
			TF2_RemoveCondition(victim, TFCond_Cloaked);
		}

		// boomer explodes on death, albeit for smaller radius
		if (g_iSpecialInfectedIndex == INFECTED_BOOMER)
		{
			DoBoomerExplosion(victim, 400.0);
		}

		// set special infected state
		if (g_iNextSpecialInfected[victim] != INFECTED_NONE)
		{
			// if not tank, we carry over the desired special infected to be his actual state
			if (victim != g_iZombieTank) g_iSpecialInfected[victim] = g_iNextSpecialInfected[victim];
			g_iNextSpecialInfected[victim] = INFECTED_NONE;
		}

		// Remove dropped ammopacks from zombies.
		int index = -1;
		while ((index = FindEntityByClassname(index, "tf_ammo_pack")) != -1)
		{
			if (GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity") == victim)
			{
				AcceptEntityInput(index, "Kill");
			}
		}

		// zombie rage: instant respawn
		if (g_bZombieRage && roundState() == RoundActive)
		{
			g_iZombiesRespawnedSinceFrenzy++;
			int iMaxRespawns = g_cvarFrenzyMaxRespawns.IntValue;

			// initiate instant respawn
			if (g_iZombiesRespawnedSinceFrenzy <= iMaxRespawns)
			{
				CreateTimer(0.1, RespawnPlayer, victim);
			}
			
			// display message indicating that we no longer will instantly respawn infected
			if (g_iZombiesRespawnedSinceFrenzy == iMaxRespawns)
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i))
					{
						CPrintToChat(i, "{greenyellow}[SZF] %sInfected no longer instantly respawn during this frenzy...", (IsZombie(i)) ? "{red}" : "{green}");
					}
				}
			}
		}
	}

	// Instant respawn outside of the actual gameplay
	if (roundState() != RoundActive && roundState() != RoundPost)
	{
		CreateTimer(0.1, RespawnPlayer, victim);
		return Plugin_Continue;
	}

	// Handle survivor death logic, active round only.
	if (IsValidSurvivor(victim))
	{
		// black and white effect for death
		ClientCommand(victim, "r_screenoverlay\"debug/yuv\"");

		if (IsValidZombie(killers[0]))
		{
			zf_spawnZombiesKilledSpree = 0;
			zf_spawnSurvivorsKilledCounter++;

			// with less than 14 survivors dead and every time 3 survivors die, have a chance to start a zombie rage
			if (zf_spawnSurvivorsKilledCounter <= 14 && zf_spawnSurvivorsKilledCounter % 3 == 0 && !GetRandomInt(0, 40 - GetSurvivorCount()))
			{
				ZombieRage();
			}

			// baton pass means they instantly respawn and go to the killer's spot
			if (IsMutationActive(MUTATION_BATONPASS))
			{
				CreateTimer(0.1, timer_zombify, victim, TIMER_FLAG_NO_MAPCHANGE);
				CPrintToChat(victim, "{greenyellow}[SZF] {red}You have perished and turned into a zombie...");
				SpawnClient(victim, zomTeam());

				// teleport to killer
				float flPosClient[3];
				GetClientAbsOrigin(killers[0], flPosClient);
				TeleportEntity(victim, flPosClient, NULL_VECTOR, NULL_VECTOR);
			}
		}

		// reset backstab state
		g_bBackstabbed[victim] = false;

		// Transfer player to zombie team.
		CreateTimer(6.0, timer_zombify, victim, TIMER_FLAG_NO_MAPCHANGE);
		// check if he's the last
		CreateTimer(0.1, CheckLastPlayer);

		int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_DEAD]-1);
		char strPath[PLATFORM_MAX_PATH];
		MusicGetPath(MUSIC_DEAD, iRandom, strPath, sizeof(strPath));
		EmitSoundToClient(victim, strPath, _, SNDLEVEL_AIRCRAFT);
		EmitSoundToClient(victim, strPath, _, SNDLEVEL_AIRCRAFT);
		StartSoundSystem(victim, MUSIC_NONE);
	}

	// Handle zombie death logic, active round only.
	else if (IsValidZombie(victim))
	{
		if (IsValidSurvivor(killers[0]))
		{
			zf_spawnZombiesKilledSpree++;
			zf_spawnZombiesKilledCounter++;
			zf_spawnZombiesKilledSurvivor[killers[0]]++;

			// if (zf_spawnZombiesKilledSurvivor[killers[0]] == 50 && !zf_lastSurvivor)
			// {
			// }

			// every time 50 zombies are killed, 10% chance to start a zombie rage, does not trigger on last survivor
			if (zf_spawnZombiesKilledCounter % 50 == 0 && !GetRandomInt(0, 9) && !zf_lastSurvivor)
			{
				ZombieRage();
			}
		}

		for (int i = 0; i < 2; i++)
		{
			if (IsValidLivingClient(killers[i]))
			{
				// Handle ammo kill bonuses.
				// + Soldiers receive 2 rockets per kill.
				// + Demomen receive 1 pipe per kill.
				// + Snipers receive 2 ammo per kill.
				TFClassType killerClass = TF2_GetPlayerClass(killers[i]);
				switch (killerClass)
				{
					case TFClass_Soldier: addResAmmo(killers[i], 0, 2);
					case TFClass_DemoMan: addResAmmo(killers[i], 0, 1);
					case TFClass_Sniper:  addResAmmo(killers[i], 0, 2);
				}

				// Handle morale bonuses.
				// + Each kill adds morale.
				int iMorale = GetMorale(killers[i]);
				int iBase = (g_iSpecialInfectedIndex == INFECTED_NONE) ? 18 : 33; // is it a normal or special infected?
				iMorale = AddMorale(killers[i], max(RoundToFloor(iBase / ((iBase+iMorale) / 15.0)), 3) );

				// + Each kill grants small health restoration.
				int curH = GetClientHealth(killers[i]);
				int maxH = SDK_GetMaxHealth(killers[i]);
				if (curH < maxH)
				{
					curH += 5 + min(RoundToFloor(iMorale / 10.0), 10); // minimum of 5, max of 15 with 100 morale
					curH = min(curH, maxH);
					SetEntityHealth(killers[i], curH);
				}

			} // if
		} // for
	} // if

	SetGlow();
	UpdateZombieDamageScale();

	return Plugin_Continue;
}

//
// Object Built Event
//
public Action event_PlayerBuiltObject(Event event, const char[] name, bool dontBroadcast)
{
    if (!zf_bEnabled) return Plugin_Continue;

    int iIndex = GetEventInt(event, "index");
    int iObject = GetEventInt(event, "object");

    // 1. Handle dispenser rules.
    //        Disable dispensers when they begin construction.
    //        Increase max health to 300 (default level 1 is 150).
    if (iObject == OBJECT_ID_DISPENSER)
    {
			SetEntProp(iIndex, Prop_Send, "m_bDisabled", 1);
			SetEntProp(iIndex, Prop_Send, "m_bCarried", 1);
			SetEntProp(iIndex, Prop_Send, "m_iMaxHealth", 300);
			AcceptEntityInput(iIndex, "Disable");
    }

    return Plugin_Continue;
}

public Action event_CPCapture(Handle hEvent, const char[] strName, bool bHide)
{
	if (g_iControlPoints <= 0) return;

	//LogMessage("Captured CP");

	int iCaptureIndex = GetEventInt(hEvent, "cp");
	if (iCaptureIndex < 0) return;
	if (iCaptureIndex >= g_iControlPoints) return;

	for (int i = 0; i < g_iControlPoints; i++)
	{
		if (g_iControlPointsInfo[i][0] == iCaptureIndex)
		{
			g_iControlPointsInfo[i][1] = 2;
		}
	}

	// control point capture: increase morale for people in capture
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i) && g_bInControlPoint[i])
		{
			// add morale
			AddMorale(i, 25);
		}
	}
	zf_pointsCaptured++;

	CheckRemainingCP();
}

public Action event_CPCaptureStart(Handle hEvent, const char[] strName, bool bHide)
{
	if (g_iControlPoints <= 0) return;

	int iCaptureIndex = GetEventInt(hEvent, "cp");
	//LogMessage("Began capturing CP #%d / (total %d)", iCaptureIndex, g_iControlPoints);
	if (iCaptureIndex < 0) return;
	if (iCaptureIndex >= g_iControlPoints) return;

	for (int i = 0; i < g_iControlPoints; i++)
	{
		if (g_iControlPointsInfo[i][0] == iCaptureIndex)
		{
			g_iControlPointsInfo[i][1] = 1;
			//LogMessage("Set capture status on %d to 1", i);
		}
	}

	//LogMessage("Done with capturing CP event");

	CheckRemainingCP();
}

public Action event_OnBroadCast(Handle event, const char[] name, bool dontBroadcast)
{
	char sound[20];
	GetEventString(event, "sound", sound, sizeof(sound));

	if (!strcmp(sound, "Game.YourTeamWon", false))
	{
		//EmitSoundToAll("left4fortress/we_survived.mp3");
		return Plugin_Handled;
	}

	else if (!strcmp(sound, "Game.YourTeamLost", false))
	{
		//EmitSoundToAll("left4fortress/death.mp3");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

//
// Player Touches Capture Point
//
public Action event_OnPlayerInsideCapture(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;
	int iClient = GetClientOfUserId(GetEventInt(event, "player"));

	g_bInControlPoint[iClient] = true;
	return Plugin_Continue;
}

//
// Player Untouches Capture Point
//
public Action event_OnPlayerOutsideCapture(Event event, const char[] name, bool dontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;
	int iClient = GetClientOfUserId(GetEventInt(event, "player"));
	if (!IsValidLivingPlayer(iClient)) return Plugin_Continue;

	g_bInControlPoint[iClient] = false;
	return Plugin_Continue;
}

//
// Banner is deployed by a Soldier
//
public Action event_BuffBannerDeployed(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;
	int iClient = GetClientOfUserId(GetEventInt(event, "buff_owner"));
	if (!IsValidLivingPlayer(iClient)) return Plugin_Continue;

	// playing banner adds 30 morale
	AddMorale(iClient, 30);

	// for people in it's range, it adds 20 morale
	float flPosAlly[3];
	float flPosSoldier[3];
	float flDistance;
	GetClientEyePosition(iClient, flPosSoldier);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			GetClientEyePosition(i, flPosAlly);
			flDistance = GetVectorDistance(flPosSoldier, flPosAlly);
			if (flDistance <= 450.0)
			{
				AddMorale(iClient, 20);
			}
		}
	}

	return Plugin_Continue;
}

public Action event_UberDeployed(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!zf_bEnabled) return Plugin_Continue;
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidLivingPlayer(iClient)) return Plugin_Continue;
	
	// using uber adds 50 morale
	AddMorale(iClient, 50);
	return Plugin_Continue;
}


////////////////////////////////////////////////////////////
//
// Periodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action timer_main(Handle timer) // 1Hz
{
	if (!zf_bEnabled) return Plugin_Continue;

	handle_survivorAbilities();
	handle_zombieAbilities();
	setTeamRespawnTime(zomTeam(), (g_bZombieRage) ? 3.0 : fMax(6.0, 12.0 / fMax(0.8, g_fZombieDamageScale)) );
	MusicHandleAll();

	if (roundState() == RoundActive)
	{
		handle_winCondition();

		for (int i = 1; i <= MaxClients; i++)
		{
			// alive infected
			if (IsValidLivingZombie(i))
			{
				// tank
				if (g_iSpecialInfected[i] == INFECTED_TANK)
				{
					// tank super health handler
					if (g_iSuperHealth[i] > 0)
					{
						g_iSuperHealth[i] -= g_iSuperHealthSubtract[i];
					}

					else
					{
						int intHealth = GetClientHealth(i);
						if (intHealth > 1)
						{
							intHealth -= g_iSuperHealthSubtract[i];
							if (intHealth < 1) intHealth = 1;
							SetEntityHealth(i, intHealth);
						}

						else
						{
							ForcePlayerSuicide(i);
						}
					}

					// screen shake if tank is close by
					float flPosClient[3];
					float flPosTank[3];
					float flDistance;
					GetClientEyePosition(i, flPosTank);

					for (int z = 1; z <= MaxClients; z++)
					{
						if (IsClientInGame(z) && IsPlayerAlive(z) && IsSurvivor(z))
						{
							GetClientEyePosition(z, flPosClient);
							flDistance = GetVectorDistance(flPosTank, flPosClient);
							flDistance /= 20.0;
							if (flDistance <= 50.0)
							{
								Shake(z, fMin(50.0 - flDistance, 5.0), 1.2);
							}
						}
					}
				}

				// kingpin
				if (g_iSpecialInfected[i] == INFECTED_KINGPIN)
				{
					TF2_AddCondition(i, TFCond_TeleportedGlow, 1.5);

					float flPosClient[3];
					float flPosScreamer[3];
					float flDistance;
					GetClientEyePosition(i, flPosScreamer);

					for (int z = 1; z <= MaxClients; z++)
					{
						if (IsValidLivingZombie(z))
						{
							GetClientEyePosition(z, flPosClient);
							flDistance = GetVectorDistance(flPosScreamer, flPosClient);
							if (flDistance <= 600.0)
							{
								TF2_AddCondition(z, TFCond_TeleportedGlow, 1.5);
								zf_screamerNearby[z] = true;
							}

							else
							{
								zf_screamerNearby[z] = false;
							}
						}
					}
				}

				
				// hell fire mutation
				if (IsMutationActive(MUTATION_HELL))
				{
					// give fire condition and fire resistance attribute
					if (!TF2_IsPlayerInCondition(i, TFCond_OnFire))
					{
						TF2_AddCondition(i, TFCond_OnFire, -1.0);
						int iEntity = GetPlayerWeaponSlot(i, TFWeaponSlot_Melee);
						if (iEntity > 0 && IsValidEdict(iEntity)) TF2Attrib_SetByName(iEntity, "dmg taken from fire reduced", 0.1);
					}
				}

				// if no special select cooldown is active and less than 2 people have been selected for the respawn into special infected
				// AND
				// damage scale is 80% and a dice roll is hit OR the damage scale is 160%
				if ( g_bRoundActive && g_flSelectSpecialCooldown <= GetGameTime() && GetReplaceRageWithSpecialInfectedSpawnCount() <= 2 && g_iSpecialInfected[i] == INFECTED_NONE && g_iNextSpecialInfected[i] == INFECTED_NONE
					&& ( (g_fZombieDamageScale >= 0.8 && !GetRandomInt(0, RoundToCeil(100 / g_fZombieDamageScale)))
					|| g_fZombieDamageScale >= 1.6 ) )
				{
					g_iNextSpecialInfected[i] = GetRandomInt(INFECTED_BOOMER, INFECTED_MAX);
					g_bReplaceRageWithSpecialInfectedSpawn[i] = true;
					g_flSelectSpecialCooldown = GetGameTime() + 20.0;
					CPrintToChat(i, "{greenyellow}[SZF] {green}You have been selected to become a Special Infected! {orange}Call 'MEDIC!' to respawn as one (or automatically become one on death).");
					PrintCenterText(i, "You have been selected to become a Special Infected!");
					EmitSoundToClient(i, "left4fortress/ui/pickup_secret01.mp3");
				}
			}

			// alive survivor
			if (IsValidLivingSurvivor(i))
			{
				// bleed out mutation
				if (IsMutationActive(MUTATION_BLEEDOUT))
				{
					// give bleed condition ok
					if (!TF2_IsPlayerInCondition(i, TFCond_Bleeding))
					{
						TF2_AddCondition(i, TFCond_Bleeding, -1.0);
					}

					// bleed like applied above does no damage, but we make it do so anyway, one tick a second
					if (TF2_IsPlayerInCondition(i, TFCond_Bleeding))
					{
						DealDamage(i, 1, i);
					}
				}
			}
			
		}
	}

	return Plugin_Continue;
}

public Action timer_mainSlow(Handle timer) // 4 min
{
	if (!zf_bEnabled) return Plugin_Continue;
	help_printZFInfoChat(0);

	return Plugin_Continue;
}

public Action timer_mainFast(Handle timer)
{
	if (!zf_bEnabled) return Plugin_Continue;
	GooDamageCheck();

	return Plugin_Continue;
}

public Action timer_hoarde(Handle timer) // 1/5th Hz
{
	if (!zf_bEnabled) return Plugin_Continue;
	handle_hoardeBonus();

	return Plugin_Continue;
}

public Action timer_datacollect(Handle timer) // 1/5th Hz
{
	if (!zf_bEnabled) return Plugin_Continue;
	FastRespawnDataCollect();

	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Aperiodic Timer Callbacks
//
////////////////////////////////////////////////////////////
public Action timer_graceStartPost(Handle timer)
{
	// Disable all resupply cabinets.
	int index = -1;
	while((index = FindEntityByClassname(index, "func_regenerate")) != -1)
		AcceptEntityInput(index, "Disable");

	// Remove all dropped ammopacks.
	index = -1;
	while ((index = FindEntityByClassname(index, "tf_ammo_pack")) != -1)
			AcceptEntityInput(index, "Kill");

	// Remove all ragdolls.
	index = -1;
	while ((index = FindEntityByClassname(index, "tf_ragdoll")) != -1)
			AcceptEntityInput(index, "Kill");

	// Disable all payload cart dispensers.
	index = -1;
	while((index = FindEntityByClassname(index, "mapobj_cart_dispenser")) != -1)
		SetEntProp(index, Prop_Send, "m_bDisabled", 1);

	// Disable all respawn room visualizers (non-ZF maps only)
	if (!mapIsZF())
	{
		char strParent[255];
		index = -1;
		while((index = FindEntityByClassname(index, "func_respawnroomvisualizer")) != -1)
		{
			GetEntPropString(index, Prop_Data, "respawnroomname", strParent, sizeof(strParent));
			if (!StrEqual(strParent, "ZombieSpawn", false))
			{
				AcceptEntityInput(index, "Disable");
			}
		}
	}

	// survivor prepare music
	char strPath[PLATFORM_MAX_PATH];
	MusicGetPath(MUSIC_PREPARE, GetRandomInt(0, g_iMusicCount[MUSIC_PREPARE]-1), strPath, sizeof(strPath));
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i) && ShouldHearEventSounds(i))
		{
			EmitSoundToClient(i, strPath);
		}
	}

	// infected prepare music
	MusicGetPath(MUSIC_PREPARE_ZOMBIE, GetRandomInt(0, g_iMusicCount[MUSIC_PREPARE_ZOMBIE]-1), strPath, sizeof(strPath));
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidZombie(i) && ShouldHearEventSounds(i))
		{
			EmitSoundToClient(i, strPath);
		}
	}

	return Plugin_Continue;
}

public Action timer_graceEnd(Handle timer)
{
	EndGracePeriod();

	return Plugin_Continue;
}

public Action timer_initialHelp(Handle timer, any iClient)
{
	// Wait until iClient is in game before printing initial help text.
	if (IsClientInGame(iClient))
	{
		help_printZFInfoChat(iClient);
	}
	else
	{
		CreateTimer(10.0, timer_initialHelp, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action timer_postSpawn(Handle timer, int iClient)
{
	if (IsValidLivingPlayer(iClient))
	{
		//HandleClientInventory(iClient);
		if (IsZombie(iClient))
		{
			HandleZombieLoadout(iClient);
			InitiateZombieTutorial(iClient);
		}

		if (IsSurvivor(iClient))
		{
			HandleSurvivorLoadout(iClient);
			InitiateSurvivorTutorial(iClient);
		}
	}

	return Plugin_Continue;
}

public Action timer_zombify(Handle timer, any iClient)
{
	if (roundState() != RoundActive) return Plugin_Continue;

	if (IsValidClient(iClient))
	{
		CPrintToChat(iClient, "{greenyellow}[SZF] {red}You have perished and turned into a zombie...");
		SpawnClient(iClient, zomTeam());
	}

	return Plugin_Continue;
}

////////////////////////////////////////////////////////////
//
// Handling Functionality
//
////////////////////////////////////////////////////////////
void handle_gameFrameLogic()
{
	// round is active
	if (roundState() == RoundActive)
	{
		// initiate vars
		int iSurvivors = GetSurvivorCount();

		// get all clients
		for (int i = 1; i <= MaxClients; i++)
		{
			// living survivor
			if (IsValidLivingSurvivor(i))
			{
				// if last survivor
				if (iSurvivors == 1)
				{
					if (GetActivePlayerCount() >= 6 && !TF2_IsPlayerInCondition(i, TFCond_Buffed)) {
						// give mini-crits
						TF2_AddCondition(i, TFCond_Buffed, -1.0);
					} else if (GetActivePlayerCount() < 6 && TF2_IsPlayerInCondition(i, TFCond_Buffed)) {
						// remove mini-crits
						TF2_RemoveCondition(i, TFCond_Buffed);
					}
				}
			}

			// living infected
			if (IsValidLivingZombie(i))
			{
				// Do not allow disguising, ever
				if (TF2_IsPlayerInCondition(i, TFCond_Disguised))
				{
					TF2_RemoveCondition(i, TFCond_Disguised);
				}

				// Turn "crit on kill" condition acquirement into perma mini-crits
				if (TF2_IsPlayerInCondition(i, TFCond_CritOnKill))
				{
					TF2_AddCondition(i, TFCond_Buffed, -1.0);
					TF2_RemoveCondition(i, TFCond_CritOnKill);
				}

				//
				// Normal Infected
				//
				if (g_iSpecialInfected[i] == INFECTED_NONE)
				{
					if (isSpy(i))
					{
						// limit cloak
						if (getCloak(i) > 66.0)
						{
							setCloak(i, 66.0);
						}
					}
				}

				//
				// Stalker
				//
				if (g_iSpecialInfected[i] == INFECTED_STALKER)
				{
					// is there an enemy within 250 hammer units?
					bool bTooClose = (GetClosestEnemy(i, 250.0) > 0);

					if (!bTooClose && iSurvivors > 0) {
						// give cloak
						if (!TF2_IsPlayerInCondition(i, TFCond_Cloaked)) TF2_AddCondition(i, TFCond_Cloaked, -1.0);
						setCloak(i, 100.0);
					} else if ((bTooClose || iSurvivors <= 0) && TF2_IsPlayerInCondition(i, TFCond_Cloaked)) {
						// remove cloak
						TF2_RemoveCondition(i, TFCond_Cloaked);
						setCloak(i, 1.0);
					}
				}

				//
				// Smoker
				//
				if (g_iSpecialInfected[i] == INFECTED_SMOKER)
				{
					// no cloaking allowed
					if (TF2_IsPlayerInCondition(i, TFCond_Cloaked))
					{
						TF2_RemoveCondition(i, TFCond_Cloaked);
					}

					if (getCloak(i) > 1.0)
					{
						setCloak(i, 1.0);
					}
				}

				//
				// Charger
				//
				if (g_iSpecialInfected[i] == INFECTED_CHARGER)
				{
					// is charging
					if (isCharging(i))
					{
						int iTarget = GetClosestEnemy(i, 112.0);

						if (IsValidLivingSurvivor(iTarget))
						{
							// set backstab state
							if (!g_bBackstabbed[iTarget])
							{
								SetBackstabState(iTarget, BACKSTABDURATION_FULL, 0.8);
								ShowAnnotationOnObject(iTarget, "Stunned by Charger", surTeam());
							}

							// play sound
							EmitSoundToAll("weapons/demo_charge_hit_flesh_range1.wav", i); 

							// deal damage and remove charging condition
							DealDamage(iTarget, 50, i, _, "tf_wearable_demoshield");
							TF2_RemoveCondition(i, TFCond_Charging);
						}
					}
				}

				//
				// Hunter
				//
				if (g_iSpecialInfected[i] == INFECTED_HUNTER)
				{
					// is pouncing
					if (g_bHopperIsUsingPounce[i])
					{
						int iTarget = GetClosestEnemy(i, 112.0);

						if (IsValidLivingSurvivor(iTarget))
						{
							// set backstab state
							if (!g_bBackstabbed[iTarget])
							{
								SetBackstabState(iTarget, BACKSTABDURATION_FULL, 1.0);
								ShowAnnotationOnObject(iTarget, "Stunned by Hunter", surTeam());
							}
							
							// teleport hunter inside the target
							float flPosClient[3];
							GetClientAbsOrigin(iTarget, flPosClient);
							flPosClient[2] += 4.0;
							TeleportEntity(i, flPosClient, NULL_VECTOR, NULL_VECTOR);

							// remove pounce
							g_bHopperIsUsingPounce[i] = false;
						}
					}
				}
			}
			// dead infected
			else if (IsValidPlayer(i) && !IsPlayerAlive(i))
			{
				//
				// force removal of cloak condition, seems to be causing the arm bug (?)
				//
				if (TF2_IsPlayerInCondition(i, TFCond_Cloaked)) {
					// remove cloak
					TF2_RemoveCondition(i, TFCond_Cloaked);
				}
			}
		}
	}
}

void handle_winCondition()
{
	// 1. Check for any survivors that are still alive.
	bool anySurvivorAlive = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i))
		{
			anySurvivorAlive = true;
			break;
		}
	}

	// 2. If no survivors are alive and at least 1 zombie is playing,
	//        end round with zombie win.
	if (!anySurvivorAlive && (GetTeamClientCount(zomTeam()) > 0))
	{
		endRound(zomTeam());
	}
}

void handle_survivorAbilities()
{
	int clipAmmo;
	int resAmmo;
	int ammoAdj;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i))
		{
			// 1. Handle survivor weapon rules.
			//        SMG doesn't have to reload.
			//        Syringe gun / blutsauger don't have to reload.
			//        Flamethrower / backburner ammo limited to 100.
			switch(TF2_GetPlayerClass(i))
			{
				case TFClass_Sniper:
				{
					if (isSlotClassname(i, 1, "tf_weapon_smg"))
					{
						clipAmmo = getClipAmmo(i, 1);
						resAmmo = getResAmmo(i, 1);
						ammoAdj = min((25 - clipAmmo), resAmmo);
						if (ammoAdj > 0)
						{
							setClipAmmo(i, 1, (clipAmmo + ammoAdj));
							setResAmmo(i, 1, (resAmmo - ammoAdj));
						}
					}
				}

				case TFClass_Medic:
				{
					if (isSlotClassname(i, 0, "tf_weapon_syringegun_medic"))
					{
						clipAmmo = getClipAmmo(i, 0);
						resAmmo = getResAmmo(i, 0);
						ammoAdj = min((40 - clipAmmo), resAmmo);
						if (ammoAdj > 0)
						{
							setClipAmmo(i, 0, (clipAmmo + ammoAdj));
							setResAmmo(i, 0, (resAmmo - ammoAdj));
						}
					}
				}

				case TFClass_Pyro:
				{
					resAmmo = getResAmmo(i, 0);
					if (resAmmo > 100)
					{
						ammoAdj = max((resAmmo - 10), 100);
						setResAmmo(i, 0, ammoAdj);
					}
				}

				case TFClass_Engineer:
				{
					if (isSlotClassname(i, 1, "tf_weapon_pistol"))
					{
						resAmmo = getResAmmo(i, 1);
						if (resAmmo > 60)
						{
							ammoAdj = 60;
							setResAmmo(i, 1, ammoAdj);
						}
					}
				}
			} //switch

			// 2. Survivor health regeneration.
			int curH = GetClientHealth(i);
			int maxH = SDK_GetMaxHealth(i);
			
			if (curH < maxH && !IsMutationActive(MUTATION_BLEEDOUT))
			{
				// give additional regen bonus based on morale
				int iMorale = GetMorale(i);
				curH += min(RoundToFloor((iMorale+1) / 25.0), 3) + 1; // max of 3 with 74 morale
				curH = min(curH, maxH);
				SetEntityHealth(i, curH);
			}

			// 3. Handle survivor morale.
			int iMorale = GetMorale(i);

			if (iMorale > 100) iMorale = SetMorale(i, 100); // max cap

			g_iMoraleSkipTicks[i]--; // get rid of one tick every second
			g_iMoraleSkipTicks[i] -= RoundToFloor(zf_spawnSurvivorsKilledCounter / 8.0); // every 8 survivors killed speeds up morale drain
			if (curH < 50) g_iMoraleSkipTicks[i]--; // low health
			if (g_bZombieRage) g_iMoraleSkipTicks[i] -= 100; // zombie rage

			if (g_iMoraleSkipTicks[i] <= 0)
			{
				g_iMoraleSkipTicks[i] = 3;
				iMorale = SubtractMorale(i, 1);
				// decrement morale bonus over time
			}

			// 3.1. Show morale (and weapon stuff) on HUD
			char strHudText[256];
			Format(strHudText, sizeof(strHudText), "Morale: %d/100", iMorale);
			SetHudTextParams(0.25, 0.65, 1.0, 200, 255, 200, 255);

			// 3.3. Award buffs if high morale is detected
			if (iMorale > 50) TF2_AddCondition(i, TFCond_DefenseBuffed, 1.1); // 50: defense buff

			// 4. HUD stuff
			// 4.1. Movement Speed
			float base = clientBaseSpeed(i);
			float current = clientBaseSpeed(i) + clientBonusSpeed(i);
			Format(strHudText, sizeof(strHudText), "%s\nSpeed: %d\%", strHudText, RoundFloat(current / base * 100));

			// 4.2. Primary weapons
			int iPrimary = GetPlayerWeaponSlot(i, TFWeaponSlot_Primary);
			if (iPrimary > MaxClients && IsValidEdict(iPrimary))
			{
				if (GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex") == 752)
				{
					float fFocus = GetEntPropFloat(i, Prop_Send, "m_flRageMeter");
					Format(strHudText, sizeof(strHudText), "%s\nFocus: %d/100", strHudText, RoundToZero(fFocus));
				}

				if (isSlotClassname(i, 0, "tf_weapon_particle_cannon"))
				{
					float fEnergy = GetEntPropFloat(iPrimary, Prop_Send, "m_flEnergy");
					Format(strHudText, sizeof(strHudText), "%s\nMangler: %d\%", strHudText, RoundFloat(fEnergy)*5);
				}

				if (isSlotClassname(i, 0, "tf_weapon_drg_pomson"))
				{
					float fEnergy = GetEntPropFloat(iPrimary, Prop_Send, "m_flEnergy");
					Format(strHudText, sizeof(strHudText), "%s\nPomson: %d\%", strHudText, RoundFloat(fEnergy)*5);
				}

				if (isSlotClassname(i, 0, "tf_weapon_sniperrifle_decap"))
				{
					int iHeads = GetEntProp(i, Prop_Send, "m_iDecapitations");
					Format(strHudText, sizeof(strHudText), "%s\nHeads: %d", strHudText, iHeads);
				}

				if (isSlotClassname(i, 0, "tf_weapon_sentry_revenge"))
				{
					int iCrits = GetEntProp(i, Prop_Send, "m_iRevengeCrits");
					Format(strHudText, sizeof(strHudText), "%s\nCrits: %d", strHudText, iCrits);
				}
			}

			// 4.3. Secondary weapons
			int iSecondary = GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary);
			if (iSecondary > MaxClients && IsValidEdict(iSecondary))
			{
				if (isSlotClassname(i, 1, "tf_weapon_raygun"))
				{
					float fEnergy = GetEntPropFloat(iSecondary, Prop_Send, "m_flEnergy");
					Format(strHudText, sizeof(strHudText), "%s\nBison: %d\%", strHudText, RoundFloat(fEnergy)*5);
				}

				if (isSlotClassname(i, 1, "tf_weapon_buff_item"))
				{
					float fRage = GetEntPropFloat(i, Prop_Send, "m_flRageMeter");

					// if round is active, add rage
					if (roundState() == RoundActive)
					{
						fRage += 1.25; // without doing anything, you can use a buff banner every 80 seconds
						if (fRage > 100.0) fRage = 100.0;
						SetEntPropFloat(i, Prop_Send, "m_flRageMeter", fRage);
					}

					Format(strHudText, sizeof(strHudText), "%s\nRage: %d/100", strHudText, RoundToZero(fRage));
				}

				if (isSlotClassname(i, 1, "tf_weapon_charged_smg"))
				{
					float fRage = GetEntPropFloat(iSecondary, Prop_Send, "m_flMinicritCharge");
					Format(strHudText, sizeof(strHudText), "%s\nCrikey: %d/100", strHudText, RoundToZero(fRage));
				}

				if (isSlotClassname(i, 1, "tf_weapon_jar"))
				{
					float fTime = GetEntPropFloat(iSecondary, Prop_Send, "m_flEffectBarRegenTime");
					if (fTime != 0)
					{
						fTime -= GetGameTime();
						int iTime = RoundToCeil(fTime);
						Format(strHudText, sizeof(strHudText), "%s\nJarate: %ds", strHudText, iTime);
					}
				}
			}

			// 4.4. Output the stored hud text string
			ShowHudText(i, -1, strHudText);

		} //if
	} //for

	// 3. Handle sentry rules.
	//        + Mini and Norm sentry starts with 24 / 30 ammo (16%/20% of default) and decays to 0, then self destructs.
	//        + No sentry can be upgraded.
	int index = -1;
	while ((index = FindEntityByClassname(index, "obj_sentrygun")) != -1)
	{
		int iOwner = GetEntPropEnt(index, Prop_Send, "m_hBuilder");
		bool sentBuilding = GetEntProp(index, Prop_Send, "m_bBuilding") == 1;
		bool sentPlacing = GetEntProp(index, Prop_Send, "m_bPlacing") == 1;
		bool sentCarried = GetEntProp(index, Prop_Send, "m_bCarried") == 1;
		bool sentIsMini = GetEntProp(index, Prop_Send, "m_bMiniBuilding") == 1;

		if (IsValidClient(iOwner) && !sentBuilding && !sentPlacing && !sentCarried)
		{
			int sentAmmo = GetEntProp(index, Prop_Send, "m_iAmmoShells");
			if (sentAmmo > 0)
			{
				sentAmmo = min((sentIsMini) ? 24 : 30, (sentAmmo - 1));
				SetEntProp(index, Prop_Send, "m_iAmmoShells", sentAmmo);
				SetEntProp(index, Prop_Send, "m_iUpgradeMetal", 0);
			}
			else
			{
				SetVariantInt(GetEntProp(index, Prop_Send, "m_iMaxHealth"));
				AcceptEntityInput(index, "RemoveHealth");
			}
		}

		int sentLevel = GetEntProp(index, Prop_Send, "m_iHighestUpgradeLevel");
		if (IsValidClient(iOwner) && sentLevel > 1)
		{
			SetVariantInt(GetEntProp(index, Prop_Send, "m_iMaxHealth"));
			AcceptEntityInput(index, "RemoveHealth");
		}
	}
}

void handle_zombieAbilities()
{
	TFClassType clientClass;
	int curH;
	int maxH;
	int bonus;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingZombie(i) && g_iSpecialInfected[i] != INFECTED_TANK)
		{
			clientClass = TF2_GetPlayerClass(i);
			curH = GetClientHealth(i);
			maxH = SDK_GetMaxHealth(i);

			// 1. Handle zombie regeneration.
			//        Zombies regenerate health based on class and number of nearby
			//        zombies (hoarde bonus). Zombies decay health when overhealed.
			bonus = 0;
			if (curH < maxH)
			{
				switch(clientClass)
				{
					case TFClass_Scout: bonus = 2 + 2 * zf_hordeBonus[i];
					case TFClass_Heavy: bonus = 1 + 1 * zf_hordeBonus[i];
					case TFClass_Spy:   bonus = 2 + 2 * zf_hordeBonus[i];
				}

				// handle additional regeneration
				if (g_bZombieRage) bonus *= 2; // zombie rage gives double regen
				if (zf_screamerNearby[i]) bonus += 2; // kingpin

				curH += bonus;
				curH = min(curH, maxH);
				SetEntityHealth(i, curH);
			}
			else if (curH > maxH)
			{
				switch(clientClass)
				{
					case TFClass_Scout: bonus = -3; 
					case TFClass_Heavy: bonus = -7;
					case TFClass_Spy:   bonus = -3;
				}
				curH += bonus;
				curH = max(curH, maxH);
				SetEntityHealth(i, curH);
			}

			// 2.1. Handle fast respawn into special infected HUD message
			if (g_bRoundActive && g_bReplaceRageWithSpecialInfectedSpawn[i])
			{
				PrintHintText(i, "Call 'MEDIC!' to respawn as a special infected!");
			}
			// 2.2. Handle zombie rage timer
			//        Rage recharges every 20(special)/30(normal) seconds.
			else if (GetRageCooldown(i) > 0)
			{
				int iCooldown = AddRageCooldown(i, -1);
				if (iCooldown == 0) PrintCenterText(i, "Rage is ready! (Call 'MEDIC!' to use)");
				else if (iCooldown % 5 == 0) PrintCenterText(i, "Rage is ready in %d seconds!", iCooldown);
			}
		} //if
	} //for
}

void handle_hoardeBonus()
{
	int playerCount;
	int player[MAXPLAYERS];
	int playerHoardeId[MAXPLAYERS];
	float playerPos[MAXPLAYERS][3];

	int hoardeSize[MAXPLAYERS];

	int curPlayer;
	int curHoarde;
	Handle hStack;

	// 1. Find all active zombie players.
	playerCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && IsZombie(i))
		{
			player[playerCount] = i;
			playerHoardeId[playerCount] = -1;
			GetClientAbsOrigin(i, playerPos[playerCount]);
			playerCount++;
		}
	}

	// 2. Calculate hoarde groups.
	//        A hoarde is defined as a single, contiguous group of valid zombie
	//        players. Distance calculation between zombie players serves as
	//        primary decision criteria.
	curHoarde = 0;
	hStack = CreateStack();
	for (int i = 0; i < playerCount; i++)
	{
		// 2a. Create new hoarde group.
		if (playerHoardeId[i] == -1)
		{
			PushStackCell(hStack, i);
			playerHoardeId[i] = curHoarde;
			hoardeSize[curHoarde] = 1;
		}

		// 2b. Build current hoarde created in step 2a.
		//         Use a depth-first adjacency search.
		while(PopStackCell(hStack, curPlayer))
		{
			for (int j = i+1; j < playerCount; j++)
			{
				if (playerHoardeId[j] == -1)
				{
					if (GetVectorDistance(playerPos[j], playerPos[curPlayer], true) <= 200000)
					{
						PushStackCell(hStack, j);
						playerHoardeId[j] = curHoarde;
						hoardeSize[curHoarde]++;
					}
				}
			}
		}
		curHoarde++;
	}

	// 3. Set hoarde bonuses.
	for (int i = 1; i <= MaxClients; i++)
		zf_hordeBonus[i] = 0;
	for (int i = 0; i < playerCount; i++)
		zf_hordeBonus[player[i]] = hoardeSize[playerHoardeId[i]] - 1;

	CloseHandle_2(hStack);
}

////////////////////////////////////////////////////////////
//
// ZF Logic Functionality
//
////////////////////////////////////////////////////////////
void zfEnable()
{
	zf_bEnabled = true;
	zf_bNewRound = true;
	setRoundState(RoundInit2);

	zfSetTeams();
	GetMapSettingsByInfoTarget(); // get map's individuals settings

	for (int i = 1; i <= MAXPLAYERS; i++) resetClientState(i);

	// General
	SetConVarInt(FindConVar("mp_autoteambalance"), 0); // ServerCommand("sm_cvar mp_autoteambalance 0");
	SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0); // ServerCommand("sm_cvar mp_teams_unbalance_limit 0");
	// Engineer
	ServerCommand("sm_cvar tf_obj_upgrade_per_hit 0"); // SetConVarInt(FindConVar("tf_obj_upgrade_per_hit"), 0);
	ServerCommand("sm_cvar tf_sentrygun_metal_per_shell 201"); // SetConVarInt(FindConVar("tf_sentrygun_metal_per_shell"), 201);
	// Spy
	ServerCommand("sm_cvar tf_spy_invis_time 0.5"); // SetConVarFloat(FindConVar("tf_spy_invis_time"), 0.5);
	ServerCommand("sm_cvar tf_spy_invis_unstealth_time 0.75"); // SetConVarFloat(FindConVar("tf_spy_invis_unstealth_time"), 0.75);
	ServerCommand("sm_cvar tf_spy_cloak_no_attack_time 1.0"); // SetConVarFloat(FindConVar("tf_spy_cloak_no_attack_time"), 1.0);

	// [Re]Enable periodic timers.
	if (zf_tMain != INVALID_HANDLE) CloseHandle_2(zf_tMain);
	zf_tMain = CreateTimer(1.0, timer_main, _, TIMER_REPEAT);

	if (zf_tMainSlow != INVALID_HANDLE) CloseHandle_2(zf_tMainSlow);
	zf_tMainSlow = CreateTimer(240.0, timer_mainSlow, _, TIMER_REPEAT);

	if (zf_tMainFast != INVALID_HANDLE) CloseHandle_2(zf_tMainFast);
	zf_tMainFast = CreateTimer(0.5, timer_mainFast, _, TIMER_REPEAT);

	if (zf_tHoarde != INVALID_HANDLE) CloseHandle_2(zf_tHoarde);
	zf_tHoarde = CreateTimer(5.0, timer_hoarde, _, TIMER_REPEAT);

	if (zf_tDataCollect != INVALID_HANDLE) CloseHandle_2(zf_tDataCollect);
	zf_tDataCollect = CreateTimer(2.0, timer_datacollect, _, TIMER_REPEAT);
}

void zfDisable()
{
	zf_bEnabled = false;
	zf_bNewRound = true;
	setRoundState(RoundInit2);

	for (int i = 1; i <= MAXPLAYERS; i++) resetClientState(i);

	// General
	SetConVarInt(FindConVar("mp_autoteambalance"), 1); // ServerCommand("sm_cvar mp_autoteambalance 0");
	SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 1); // ServerCommand("sm_cvar mp_teams_unbalance_limit 0");
	// Engineer
	ServerCommand("sm_cvar tf_obj_upgrade_per_hit 25"); // SetConVarInt(FindConVar("tf_obj_upgrade_per_hit"), 25);
	ServerCommand("sm_cvar tf_sentrygun_metal_per_shell 1"); // SetConVarInt(FindConVar("tf_sentrygun_metal_per_shell"), 1);
	// Spy
	ServerCommand("sm_cvar tf_spy_invis_time 1.0"); // SetConVarFloat(FindConVar("tf_spy_invis_time"), 1.0);
	ServerCommand("sm_cvar tf_spy_invis_unstealth_time 2.0"); // SetConVarFloat(FindConVar("tf_spy_invis_unstealth_time"), 2.0);
	ServerCommand("sm_cvar tf_spy_cloak_no_attack_time 2.0"); // SetConVarFloat(FindConVar("tf_spy_cloak_no_attack_time"), 2.0);

	// Disable periodic timers.
	if (zf_tMain != INVALID_HANDLE)
	{
		CloseHandle_2(zf_tMain);
		zf_tMain = INVALID_HANDLE;
	}
	if (zf_tMainSlow != INVALID_HANDLE)
	{
		CloseHandle_2(zf_tMainSlow);
		zf_tMainSlow = INVALID_HANDLE;
	}
	if (zf_tHoarde != INVALID_HANDLE)
	{
		CloseHandle_2(zf_tHoarde);
		zf_tHoarde = INVALID_HANDLE;
	}

	if (zf_tDataCollect != INVALID_HANDLE)
	{
		CloseHandle_2(zf_tDataCollect);
		zf_tDataCollect = INVALID_HANDLE;
	}

	// Enable resupply lockers.
	int index = -1;
	while((index = FindEntityByClassname(index, "func_regenerate")) != -1)
		AcceptEntityInput(index, "Enable");
}

void zfSetTeams()
{
	//
	// Determine team roles.
	// + By default, survivors are RED and zombies are BLU.
	//
	int survivorTeam = view_as<int>(TFTeam_Red);
	int zombieTeam = view_as<int>(TFTeam_Blue);

	//
	// Determine whether to swap teams on payload maps.
	// + For "pl_" prefixed maps, swap teams if sm_zf_swaponpayload is set.
	//
	if (mapIsPL())
	{
		if (GetConVarBool(g_cvarSwapOnPayload))
		{
			survivorTeam = view_as<int>(TFTeam_Blue);
			zombieTeam = view_as<int>(TFTeam_Red);
		}
	}

	//
	// Determine whether to swap teams on attack / defend maps.
	// + For "cp_" prefixed maps with all RED control points, swap teams if sm_zf_swaponattdef is set.
	//
	if (mapIsCP())
	{
		if (GetConVarBool(g_cvarSwapOnAttdef))
		{
			bool isAttdef = true;
			int index = -1;
			while((index = FindEntityByClassname(index, "team_control_point")) != -1)
			{
				if (GetEntProp(index, Prop_Send, "m_iTeamNum") != view_as<int>(TFTeam_Red))
				{
					isAttdef = false;
					break;
				}
			}

			if (isAttdef)
			{
				survivorTeam = view_as<int>(TFTeam_Blue);
				zombieTeam = view_as<int>(TFTeam_Red);
			}
		}
	}

	// Set team roles.
	setSurTeam(survivorTeam);
	setZomTeam(zombieTeam);
}

////////////////////////////////////////////////////////////
//
// Utility Functionality
//
////////////////////////////////////////////////////////////
void resetClientState(int iClient)
{
	g_iSurvivorMorale[iClient] = 0;
	zf_hordeBonus[iClient] = 0;
	zf_screamerNearby[iClient] = false;
	SetRageCooldown(iClient, 0);
	g_bInControlPoint[iClient] = false;
	g_fEscapePlanPostBoost[iClient] = 0.0;
	g_iPickupWeaponSlotFromSpawn[iClient] = 0;
}

////////////////////////////////////////////////////////////
//
// Help Functionality
//
////////////////////////////////////////////////////////////
public void help_printZFInfoChat(int iClient)
{
	// format initial message
	char strMessage[255];
	Format(strMessage, sizeof(strMessage), "{greenyellow}[SZF] {orange}Welcome to Super Zombie Fortress.\nFor help, open the menu using {greenyellow}/szf{orange}.\n{yellow}Custom version {orange}by {green}sasch{orange} with special thanks to {green}Benoist3012{orange}.");
	if (iClient == 0)
		CPrintToChatAll(strMessage);
	else
		CPrintToChat(iClient, strMessage);

	// format votem message
	if (!GetRandomInt(0, 3) && !g_bMutationNextRound && !g_bMutationActive)
		CPrintToChatAll("{greenyellow}[SZF] {yellow}Daily Mutation: \x01You can vote for the {yellow}'%s'\x01-mutation with {greenyellow}/votem\x01.", g_strMutationTitles[GetActiveMutation()-1]);
}

void SetGlow()
{
	int iCount = GetSurvivorCount();
	int iGlow = 0;
	int iGlow2;

	if (iCount >= 1 && iCount <= 3) iGlow = 1;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingPlayer(i))
		{
			iGlow2 = iGlow;

			// Non-Survivors cannot glow by default
			if (!IsSurvivor(i))
				iGlow2 = 0;

			// Kingpin or Tank
			if (IsZombie(i) && (g_iSpecialInfected[i] == INFECTED_TANK || g_iSpecialInfected[i] == INFECTED_KINGPIN))
				iGlow2 = 1;

			// Survivor with lower than 30 health or backstabbed
			if (IsSurvivor(i))
			{
				if (GetClientHealth(i) <= g_cvarSurvivorHealthSpeedDrain.IntValue)
					iGlow2 = 1;
				if (g_bBackstabbed[i])
					iGlow2 = 1;
			}

			if (IsMutationActive(MUTATION_ALLSEEINGEYE))
				iGlow2 = 1;

			SetEntProp(i, Prop_Send, "m_bGlowEnabled", iGlow2);
		}
	}
}

int UpdateZombieDamageScale()
{
	g_fZombieDamageScale = 1.0;

	if (g_iStartSurvivors <= 0) return;
	if (!zf_bEnabled) return;
	if (roundState() != RoundActive) return;

	float fTime = 1.0 - GetTimePercentage();
	if (fTime <= 0.0) return;

	int iSurvivors = GetSurvivorCount();
	if (iSurvivors < 1) iSurvivors = 1; // division by 0 error

	int iZombies = GetZombieCount();
	if (iZombies < 1) iZombies = 1; // division by 0 error

	// Get starting survivors and expected survivors, generate ratio based on time
	int iExpectedSurvivors = RoundFloat(float(g_iStartSurvivors) * (SquareRoot(fTime) + fTime) * 0.5);
	int iSurvivorDifference = iSurvivors - iExpectedSurvivors;
	g_fZombieDamageScale = fMax(0.0, (float(iSurvivorDifference) / float(g_iStartSurvivors)) + 1.0);

	// Get the amount of Infected killed since last survivor death
	// 0.4% damage for every Infected killed, max 20% damage increase
	if (zf_spawnZombiesKilledSpree > 0) g_fZombieDamageScale += fMin(0.2, zf_spawnZombiesKilledSpree * 0.004);

	// Get total amount of Infected killed
	// 0.01% damage for every Infected killed, max 20% damage increase
	if (zf_spawnZombiesKilledCounter > 0) g_fZombieDamageScale += fMin(0.2, zf_spawnZombiesKilledCounter * 0.001);

	// Get the amount of points captured
	g_fZombieDamageScale += zf_pointsCaptured * 0.025; // 4 = +0.1

	// Zombie rage increases damage
	if (g_bZombieRage) g_fZombieDamageScale += 0.1;

	// If the last point is being captured, set the damage scale to 110% if lower than 110%
	if (g_bCapturingLastPoint && g_fZombieDamageScale < 1.1) g_fZombieDamageScale = 1.1;

	// Start seperating frenzy / tank events from Survival / non-Survival
	// ...
	// In survival
	if (g_bSurvival)
	{
		// zombie to survivor ratio is also taken to calculate damage.
		g_fZombieDamageScale += fMax(0.0, (iSurvivors / iZombies / 30) + 0.08); // 28-4 = +0.213, 16-16 = +0.113
	
		// trigger frenzy when 9-10% of map time is left
		if (fTime >= 0.09 && fTime <= 0.10) ZombieRage();
	}
	// Not survival
	else if (!g_bSurvival)
	{
		// rage events
		if (GetGameTime() > g_flRageCooldown)
		{
			// trigger frenzy when 9-10% of map time is left
			if (fTime >= 0.09 && fTime <= 0.10) ZombieRage();

			// the frenzy chance rng is triggered
			if (GetRandomInt(0, 100) <= GetConVarInt(g_cvarFrenzyChance))
			{
				// if zombie damage scale is high and the frenzy chance for tank is triggered
				if (GetRandomInt(0, 100) <= GetConVarInt(g_cvarFrenzyTankChance) && g_fZombieDamageScale >= 1.1)
				{
					ZombieTank();
				}
				else
				{
					ZombieRage();
				}
			}
		}

		// tank events, requires high zombie damage scale
		if (g_fZombieDamageScale >= 1.1 && !g_bTankOnce && GetGameTime() > g_flTankCooldown)
		{
			// remaining time % <= g_cvarTankOnce
			if (fTime <= GetConVarFloat(g_cvarTankOnce) * 0.01) ZombieTank();

			// very high zombie damage scale high and half-way in the match
			if (g_fZombieDamageScale >= 1.6 && fTime >= 0.46 && fTime <= 0.54) ZombieTank();
		}
	}

	// Post-calculation, this should be the last bit where the damage scale actually gets calculated
	if (g_fZombieDamageScale < 1.0) g_fZombieDamageScale *= g_fZombieDamageScale;
	if (g_fZombieDamageScale < 0.25) g_fZombieDamageScale = 0.25;
	if (g_fZombieDamageScale > 2.0) g_fZombieDamageScale = 2.0;
}

public Action RespawnPlayer(Handle hTimer, any iClient)
{
	if (IsClientInGame(iClient) && !IsPlayerAlive(iClient))
	{
		TF2_RespawnPlayer(iClient);
		CreateTimer(0.1, timer_postSpawn, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action CheckLastPlayer(Handle hTimer)
{
	int iCount = GetSurvivorCount();
	if (iCount == 1 && !zf_lastSurvivor)
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsValidLivingSurvivor(iClient))
			{
				// set health, morale and last survivor state
				SetEntityHealth(iClient, 400);
				zf_lastSurvivor = true;
				SetMorale(iClient, 100);

				char strName[80];
				SZF_GetClientName(iClient, strName, sizeof(strName));

				// ex. Gold Best Boss Owner Dispenz0r is the last survivor!
				CPrintToChatAllEx(iClient, "%s{green} is the last survivor!", strName);

				MusicHandleClient(iClient);
			}
		}
	}
	return Plugin_Handled;
}

public Action EventTimeAdded(Event event, const char[] name, bool dontBroadcast)
{
	int iAddedTime = event.GetInt("seconds_added");
	g_AdditionalTime = g_AdditionalTime + iAddedTime;

	if ( GetGameTime() > g_flTankCooldown && (!g_bTankOnce && !GetRandomInt(0, 9) || !GetRandomInt( 0, RoundToCeil(50.0 / g_fZombieDamageScale)) ) )
	{
		ZombieTank();
	}
}

public void OnMapStart()
{
	// Lots of precache going on here.
	VocalsPrecache();
	LoadSoundSystem();
	FastRespawnReset();
	DetermineControlPoints();

	for (int i = 0; i < sizeof(g_strSpawnModels); i++) PrecacheModel(g_strSpawnModels[i]);
	for (int i = 0; i < sizeof(g_strPickupModels); i++) PrecacheModel(g_strPickupModels[i]);
	for (int i = 0; i < sizeof(g_strWeaponModels); i++) PrecacheModel(g_strWeaponModels[i]);
	for (int i = 0; i < sizeof(g_strRareModels); i++) PrecacheModel(g_strRareModels[i]);

	// TODO: make this more... modular, i guess.
	iScoutZombieIndex = PrecacheModel("models/player/items/scout/scout_zombie.mdl");
	iSoldierZombieIndex = PrecacheModel("models/player/items/soldier/soldier_zombie.mdl");
	iPyroZombieIndex = PrecacheModel("models/player/items/pyro/pyro_zombie.mdl");
	iDemomanZombieIndex = PrecacheModel("models/player/items/demo/demo_zombie.mdl");
	iHeavyZombieIndex = PrecacheModel("models/player/items/heavy/heavy_zombie.mdl");
	iMedicZombieIndex = PrecacheModel("models/player/items/medic/medic_zombie.mdl");
	iEngineerZombieIndex = PrecacheModel("models/player/items/engineer/engineer_zombie.mdl");
	iSniperZombieIndex = PrecacheModel("models/player/items/sniper/sniper_zombie.mdl");
	iSpyZombieIndex = PrecacheModel("models/player/items/spy/spy_zombie.mdl");

	// zombie rage
	PrecacheParticle("spell_cast_wheel_blue");
	// goo
	PrecacheParticle("asplode_hoodoo_green");
	// boomer
	PrecacheParticle("asplode_hoodoo_debris");
	PrecacheParticle("asplode_hoodoo_dust");
	// map pickup sfx
	PrecacheSound("ui/item_paint_can_pickup.wav"); // szf_carry items
	PrecacheSound("ui/item_heavy_gun_pickup.wav"); // rare pick-ups
	PrecacheSound("ui/item_heavy_gun_drop.wav");
	PrecacheSound("ui/item_default_gun_pickup.wav"); // normal pick-ups
	PrecacheSound("ui/item_default_gun_drop.wav");
	PrecacheSound("ui/item_light_gun_pickup.wav"); // spawn pick-ups
	// PrecacheSound("ui/item_light_gun_drop.wav");
	// win and lose music
	PrecacheSound2("left4fortress/death.mp3");
	PrecacheSound2("left4fortress/we_survived.mp3");
	// special infected spawning music
	PrecacheSound2("left4fortress/bacteria/boomerbacteria.mp3");
	PrecacheSound2("left4fortress/bacteria/chargerbacteria.mp3");
	PrecacheSound2("left4fortress/bacteria/hunterbacteria.mp3");
	PrecacheSound2("left4fortress/bacteria/jockeybacteria.mp3");
	PrecacheSound2("left4fortress/bacteria/smokerbacteria.mp3");
	PrecacheSound2("left4fortress/bacteria/kingpinbacteria.mp3"); // modified
	PrecacheSound2("left4fortress/bacteria/spitterbacteria.mp3");
	PrecacheSound2("left4fortress/bacteria/witchbacteria.mp3"); // modified

	PrecacheSound2("left4fortress/ui/beep_synthtone01.mp3"); // mutation vote added
	PrecacheSound2("left4fortress/ui/menu_enter05.mp3"); // mutation vote success
	PrecacheSound2("left4fortress/ui/pickup_scifi37.mp3"); // spawned as special
	PrecacheSound2("left4fortress/ui/pickup_secret01.mp3"); // can become special

	
	// kingpin scream
	PrecacheSound("ambient/halloween/male_scream_15.wav");
	PrecacheSound("ambient/halloween/male_scream_16.wav");
	// hopper scream
	PrecacheSound("ambient/halloween/male_scream_18.wav");
	PrecacheSound("ambient/halloween/male_scream_19.wav");
	// charger ka-klunk
	PrecacheSound("weapons/demo_charge_hit_flesh_range1.wav");
	// smoker beam
	g_iSprite = PrecacheModel("materials/sprites/laser.vmt");
	// goo overlay
	AddFileToDownloadsTable("materials/left4fortress/goo.vmt");
	// bonus overlays
	PrecacheBonus("zombie_assist");
	PrecacheBonus("zombie_kill");
	PrecacheBonus("zombie_kill_2");
	PrecacheBonus("zombie_kill_lot");
	PrecacheBonus("zombie_stab_death");

	for (int i = 0; i < sizeof(g_strSoundFleshHit); i++) PrecacheSound(g_strSoundFleshHit[i]);
	for (int i = 0; i < sizeof(g_strSoundCritHit); i++) PrecacheSound(g_strSoundCritHit[i]);

	HookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger); // for people to spawn stuff
}

void LoadSoundSystem()
{
	if (g_hMusicArray != INVALID_HANDLE) CloseHandle_2(g_hMusicArray);
	g_hMusicArray = CreateArray();

	for (int iLoop = 0; iLoop < sizeof(g_iMusicCount); iLoop++)
	{
		g_iMusicCount[iLoop] = 0;
	}

	Handle hKeyvalue = CreateKeyValues("music");

	char strValue[PLATFORM_MAX_PATH];

	char strPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, strPath, sizeof(strPath), "data/superzombiefortress.txt");
	//LogMessage("Loading sound system: %s", strPath);
	FileToKeyValues(hKeyvalue, strPath);
	KvRewind(hKeyvalue);
	//KeyValuesToFile(hKeyvalue, "test.txt");
	KvGotoFirstSubKey(hKeyvalue);
	do
	{
		Handle hEntry = CreateArray(PLATFORM_MAX_PATH);
		KvGetString(hKeyvalue, "path", strValue, sizeof(strValue), "error");
		PushArrayString(hEntry, strValue);

		PrecacheSound2(strValue);

		//LogMessage("Found: %s", strValue);
		KvGetString(hKeyvalue, "category", strValue, sizeof(strValue), "error");
		PushArrayString(hEntry, strValue);

		int iCategory = MusicCategoryToNumber(strValue);
		//LogMessage("Category: %s (%d)", strValue, iCategory);
		if (iCategory < 0)
		{
			LogError("Invalid music category %d (%s)", iCategory, strValue);
		}
		else
		{
			g_iMusicCount[iCategory]++;

			KvGetString(hKeyvalue, "length", strValue, sizeof(strValue), "error");
			PushArrayString(hEntry, strValue);
			PushArrayCell(g_hMusicArray, hEntry);
		}
	} while (KvGotoNextKey(hKeyvalue));
	//LogMessage("Done with the sound system");

	CloseHandle_2(hKeyvalue);
}

int MusicCategoryToNumber(char[] strCategory)
{
	if (StrEqual(strCategory, "drums", false)) return MUSIC_DRUMS;
	if (StrEqual(strCategory, "slayermild", false)) return MUSIC_SLAYER_MILD;
	if (StrEqual(strCategory, "slayer", false)) return MUSIC_SLAYER;
	if (StrEqual(strCategory, "trumpet", false)) return MUSIC_TRUMPET;
	if (StrEqual(strCategory, "snare", false)) return MUSIC_SNARE;
	if (StrEqual(strCategory, "banjo", false)) return MUSIC_BANJO;
	if (StrEqual(strCategory, "heartslow", false)) return MUSIC_HEART_SLOW;
	if (StrEqual(strCategory, "heartmedium", false)) return MUSIC_HEART_MEDIUM;
	if (StrEqual(strCategory, "heartfast", false)) return MUSIC_HEART_FAST;
	if (StrEqual(strCategory, "rabies", false)) return MUSIC_RABIES;
	if (StrEqual(strCategory, "dead", false)) return MUSIC_DEAD;
	if (StrEqual(strCategory, "incoming", false)) return MUSIC_INCOMING;
	if (StrEqual(strCategory, "prepare", false)) return MUSIC_PREPARE;
	if (StrEqual(strCategory, "drown", false)) return MUSIC_DROWN;
	if (StrEqual(strCategory, "tank", false)) return MUSIC_TANK;
	if (StrEqual(strCategory, "laststand", false)) return MUSIC_LASTSTAND;
	if (StrEqual(strCategory, "neardeath", false)) return MUSIC_NEARDEATH;
	if (StrEqual(strCategory, "neardeath2", false)) return MUSIC_NEARDEATH2;
	if (StrEqual(strCategory, "award", false)) return MUSIC_AWARD;
	if (StrEqual(strCategory, "last_ten_seconds", false)) return MUSIC_LASTTENSECONDS;
	if (StrEqual(strCategory, "jarate", false)) return MUSIC_JARATE;
	if (StrEqual(strCategory, "zadvantage", false)) return MUSIC_DANGER;
	if (StrEqual(strCategory, "prepare_zombies", false)) return MUSIC_PREPARE_ZOMBIE;
	return -1;
}

int MusicChannel(int iMusic)
{
	switch (iMusic)
	{
		case MUSIC_DRUMS: return CHANNEL_MUSIC_DRUMS;
		case MUSIC_SLAYER_MILD: return CHANNEL_MUSIC_SLAYER;
		case MUSIC_SLAYER: return CHANNEL_MUSIC_SLAYER;
		case MUSIC_TRUMPET: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_SNARE: return CHANNEL_MUSIC_DRUMS;
		case MUSIC_BANJO: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_HEART_SLOW: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_HEART_MEDIUM: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_HEART_FAST: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_RABIES: return CHANNEL_MUSIC_NONE;
		case MUSIC_DEAD: return CHANNEL_MUSIC_NONE;
		case MUSIC_INCOMING: return CHANNEL_MUSIC_NONE;
		case MUSIC_PREPARE: return CHANNEL_MUSIC_NONE;
		case MUSIC_DROWN: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_TANK: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_LASTSTAND: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_LASTTENSECONDS: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_NEARDEATH: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_NEARDEATH2: return CHANNEL_MUSIC_NONE;
		case MUSIC_AWARD: return CHANNEL_MUSIC_NONE;
		case MUSIC_JARATE: return CHANNEL_MUSIC_SINGLE;
		case MUSIC_DANGER: return CHANNEL_MUSIC_NONE;
		case MUSIC_PREPARE_ZOMBIE: return CHANNEL_MUSIC_NONE;
	}
	return CHANNEL_MUSIC_DRUMS;
}

void MusicGetPath(int iCategory = MUSIC_DRUMS, int iNumber, char[] strInput, int iMaxSize)
{
	//CPrintToChatAll("Attempting to get path for category %d (num %d)", iCategory, iNumber);
	int iCount = 0;
	int iEntryCategory;
	char strValue[PLATFORM_MAX_PATH];
	Handle hEntry;
	for (int i = 0; i < GetArraySize(g_hMusicArray); i++)
	{
		hEntry = GetArrayCell(g_hMusicArray, i);
		GetArrayString(hEntry, 1, strValue, sizeof(strValue));
		iEntryCategory = MusicCategoryToNumber(strValue);
		//CPrintToChatAll("Entry category: %s (%d)", strValue, iEntryCategory);
		if (iEntryCategory == iCategory)
		{
			if (iCount == iNumber)
			{
				GetArrayString(hEntry, 0, strInput, iMaxSize);
				return;
			}
			iCount++;
		}
	}
	Format(strInput, iMaxSize, "error");
	return;
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)) StopSoundSystem(i);
	}
}

void StopSoundSystem(int iClient, bool bLogic = true, bool bMusic = true, bool bConsiderFull = false, int iLevel = MUSIC_NONE)
{
	if (bMusic)
	{
		StopSound2(iClient, MUSIC_SLAYER_MILD);
		StopSound2(iClient, MUSIC_SLAYER);
		StopSound2(iClient, MUSIC_TRUMPET);
		StopSound2(iClient, MUSIC_HEART_MEDIUM);
		StopSound2(iClient, MUSIC_HEART_FAST);

		if ((!bConsiderFull) || (g_iMusicFull[iClient] % 2 == 0))
		{
			StopSound2(iClient, MUSIC_DRUMS);
			StopSound2(iClient, MUSIC_SNARE);
			StopSound2(iClient, MUSIC_BANJO);
			StopSound2(iClient, MUSIC_HEART_SLOW);
		}
		if ((!bConsiderFull) || (g_iMusicFull[iClient] % 4 == 0))
		{
			StopSound2(iClient, MUSIC_DROWN);
			StopSound2(iClient, MUSIC_JARATE);
		}
		if (!bConsiderFull)
		{
			StopSound2(iClient, MUSIC_TANK);
			StopSound2(iClient, MUSIC_LASTSTAND);
			StopSound2(iClient, MUSIC_LASTTENSECONDS);
			StopSound2(iClient, MUSIC_NEARDEATH);
		}
	}

	if (bLogic)
	{
		//CPrintToChatAll("Killed timer");
		Handle hTimer = g_hMusicTimer[iClient];
		g_hMusicTimer[iClient] = INVALID_HANDLE;
		g_iMusicLevel[iClient] = MUSIC_NONE;

		if (MusicCanReset(iLevel))
		{
			g_iMusicRandom[iClient][0] = -1;
			g_iMusicRandom[iClient][1] = -1;
		}

		g_iMusicFull[iClient] = 0;

		if (hTimer != INVALID_HANDLE) KillTimer(hTimer);
	}
}

void StopSound2(int iClient, int iMusic)
{
	if (StrEqual(g_strMusicLast[iClient][iMusic], "")) return;

	int iChannel = MusicChannel(iMusic);
	StopSound(iClient, iChannel, g_strMusicLast[iClient][iMusic]);

	Format(g_strMusicLast[iClient][iMusic], PLATFORM_MAX_PATH, "");
}

void StartSoundSystem(int iClient, int iLevel = -1)
{
	if (iLevel == -1) iLevel = g_iMusicLevel[iClient];

	StopSoundSystem(iClient, false, true, true, iLevel);

	//CPrintToChatAll("Emitting");

	// the sound system "ticks" every 2.8 second 
	// if the previous level and the "requested" level are not equal, stop all music
	if (g_iMusicLevel[iClient] != iLevel)
	{
		StopSoundSystem(iClient, true, true, false, iLevel);
		g_iMusicLevel[iClient] = iLevel;
		if (iLevel != MUSIC_NONE)
		{
			g_hMusicTimer[iClient] = CreateTimer(2.8, SoundSystemRepeat, iClient, TIMER_REPEAT);
		}
	}

	if (iLevel == MUSIC_GOO)
	{
		StartSoundSystem2(iClient, MUSIC_DROWN);
	}
	if (iLevel == MUSIC_JARATED)
	{
		StartSoundSystem2(iClient, MUSIC_JARATE);
	}

	if (iLevel == MUSIC_TANKMOOD)
	{
		StartSoundSystem2(iClient, MUSIC_TANK);
	}
	if (iLevel == MUSIC_LASTSTANDMOOD)
	{
		StartSoundSystem2(iClient, MUSIC_LASTSTAND);
	}
	if (iLevel == MUSIC_LASTTENSECONDSMOOD)
	{
		StartSoundSystem2(iClient, MUSIC_LASTTENSECONDS);
	}
	if (iLevel == MUSIC_PLAYERNEARDEATH)
	{
		StartSoundSystem2(iClient, MUSIC_NEARDEATH);
	}

	if (iLevel == MUSIC_INTENSE)
	{
		int iRandom = GetClientRandom(iClient, 0, 0, 1);
		StartSoundSystem2(iClient, MUSIC_SLAYER);
		if (iRandom == 0) StartSoundSystem2(iClient, MUSIC_BANJO);
		else StartSoundSystem2(iClient, MUSIC_DRUMS);
	}
	if (iLevel == MUSIC_MILD)
	{
		int iRandom = GetClientRandom(iClient, 0, 0, 1);
		int iRandom2 = GetClientRandom(iClient, 1, 0, 1);

		if (iRandom == 0) StartSoundSystem2(iClient, MUSIC_SLAYER_MILD);
		else StartSoundSystem2(iClient, MUSIC_TRUMPET);

		if (iRandom2 == 0) StartSoundSystem2(iClient, MUSIC_DRUMS);
		else StartSoundSystem2(iClient, MUSIC_SNARE);
	}
	if (iLevel == MUSIC_VERYMILD1)
	{
		StartSoundSystem2(iClient, MUSIC_HEART_SLOW);
	}
	if (iLevel == MUSIC_VERYMILD2)
	{
		StartSoundSystem2(iClient, MUSIC_HEART_MEDIUM);
	}
	if (iLevel == MUSIC_VERYMILD3)
	{
		StartSoundSystem2(iClient, MUSIC_HEART_FAST);
	}

	g_iMusicFull[iClient]++;
}

public Action SoundSystemRepeat(Handle hTimer, any iClient)
{
	if (!IsClientInGame(iClient))
	{
		g_hMusicTimer[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	StartSoundSystem(iClient);
	return Plugin_Continue;
}

void StartSoundSystem2(int iClient, int iMusic)
{
	// client turned off music OR map disabled music
	if (g_bNoMusicForClient[iClient] || g_bNoMusic) return;

	// if exactly 2 channels are not occupied but they contain these sounds, forbid another sound
	if (g_iMusicFull[iClient] % 2 != 0)
	{
		if (iMusic == MUSIC_DRUMS) return;
		if (iMusic == MUSIC_SNARE) return;
		if (iMusic == MUSIC_BANJO) return;
		if (iMusic == MUSIC_HEART_SLOW) return;
	}
	// if exactly 4 channels are not occupied but they contain these sounds, forbid another sound
	if (g_iMusicFull[iClient] % 4 != 0)
	{
		if (iMusic == MUSIC_DROWN) return;
		if (iMusic == MUSIC_JARATE) return;
	}
	// if any of these songs are playing, forbid another sound to be played
	if (g_iMusicFull[iClient] != 0)
	{
		if (iMusic == MUSIC_TANK) return;
		if (iMusic == MUSIC_LASTSTAND) return;
		if (iMusic == MUSIC_LASTTENSECONDS) return;
		if (iMusic == MUSIC_NEARDEATH) return;
	}

	int iRandom = GetRandomInt(0, g_iMusicCount[iMusic]-1);
	char strPath[PLATFORM_MAX_PATH];
	MusicGetPath(iMusic, iRandom, strPath, sizeof(strPath));
	//CPrintToChatAll("Emitting: %s", strPath);
	int iChannel = MusicChannel(iMusic);
	EmitSoundToClient(iClient, strPath, _, iChannel, _, _, 1.0);
	Format(g_strMusicLast[iClient][iMusic], PLATFORM_MAX_PATH, "%s", strPath);
}

bool ShouldHearEventSounds(int iClient)
{
	if (g_bNoMusicForClient[iClient]) return false;
	if (g_bNoMusic) return false;
	if (g_iMusicLevel[iClient] == MUSIC_INTENSE) return false;
	if (g_iMusicLevel[iClient] == MUSIC_MILD) return false;
	return true;
}

int GetClientRandom(int iClient, int iNumber, int iMin, int iMax)
{
	if (g_iMusicRandom[iClient][iNumber] >= 0) return g_iMusicRandom[iClient][iNumber];
	int iRandom = GetRandomInt(iMin, iMax);
	g_iMusicRandom[iClient][iNumber] = iRandom;
	return iRandom;
}

stock void PrecacheSound2(char[] strSound)
{
	char strPath[PLATFORM_MAX_PATH];
	Format(strPath, sizeof(strPath), "sound/%s", strSound);

	PrecacheSound(strSound, true);
	AddFileToDownloadsTable(strPath);
}

int ZombieRage(float flDuration = 20.0)
{
	// round not active, map disabled rage logic, rage already ongoing or tank alive on infected team
	if (roundState() != RoundActive || g_bNoDirectorRages || g_bZombieRage || ZombiesHaveTank()) return;

	g_bZombieRage = true;
	g_iZombiesRespawnedSinceFrenzy = 0;

	// zombies are enraged, decrease morale
	AddMoraleAll(-25);

	g_bZombieRageAllowRespawn = true;
	if (flDuration < 20.0) g_bZombieRageAllowRespawn = false;

	CreateTimer(flDuration, StopZombieRage);

	//CPrintToChatAll("Zombie rage");

	if (flDuration >= 20.0)
	{
		int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_INCOMING]-1);
		char strPath[PLATFORM_MAX_PATH];
		MusicGetPath(MUSIC_INCOMING, iRandom, strPath, sizeof(strPath));
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				CPrintToChat(i, "{greenyellow}[SZF] %sZombies are frenzied: they respawn instantly and are more powerful!", (IsZombie(i)) ? "{green}" : "{red}");

				if (ShouldHearEventSounds(i))
				{
					EmitSoundToClient(i, strPath, _, SNDLEVEL_AIRCRAFT);
				}
				if (IsZombie(i) && !IsPlayerAlive(i))
				{
					TF2_RespawnPlayer(i);
					CreateTimer(0.1, timer_postSpawn, i, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}

	g_flRageCooldown = GetGameTime() + flDuration + 20.0;
}

public Action StopZombieRage(Handle hTimer)
{
	g_bZombieRage = false;
	UpdateZombieDamageScale();

	if (roundState() == RoundActive)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				CPrintToChat(i, "{greenyellow}[SZF] %sZombies are resting...", (IsZombie(i)) ? "{red}" : "{green}");
			}
		}
	}
}

public Action SpookySound(Handle hTimer)
{
	if (roundState() != RoundActive) return;

	int iRandom = GetRandomInt(0, g_iMusicCount[MUSIC_RABIES]-1);
	char strPath[PLATFORM_MAX_PATH];
	MusicGetPath(MUSIC_RABIES, iRandom, strPath, sizeof(strPath));

	int iTarget = -1;
	int iFail = 0;
	do
	{
		iTarget = GetRandomInt(1, MaxClients);
		iFail++;
	} while ((!IsValidLivingPlayer(iTarget) || !ShouldHearEventSounds(iTarget)) && iFail < 100);

	if (IsValidLivingPlayer(iTarget))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidLivingPlayer(i) && ShouldHearEventSounds(i) && i != iTarget && !IsZombie(i)) EmitSoundToClient(i, strPath, iTarget);
		}
	}
}

float GetZombieNumber(int iClient)
{
	float fPosClient[3];
	float fPosZombie[3];
	GetClientEyePosition(iClient, fPosClient);
	float fDistance;
	float fZombieNumber = 0.0;
	for (int z = 1; z <= MaxClients; z++)
	{
		if (IsValidLivingZombie(z))
		{
			GetClientEyePosition(z, fPosZombie);
			fDistance = GetVectorDistance(fPosClient, fPosZombie);
			fDistance /= 50.0;
			if (fDistance <= 20.0)
			{
				fDistance = 20.0 - fDistance;
				if (fDistance >= 15.0) fDistance = 15.0;
				fZombieNumber += fDistance;
			}
		}
	}
	fZombieNumber *= 1.2;
	return fZombieNumber;
}

void MusicHandleAll()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		MusicHandleClient(iClient);
	}
}

void MusicHandleClient(int iClient)
{
	if (!IsValidClient(iClient)) return;

	if (g_bNoMusicForClient[iClient] || g_bNoMusic)
	{
		StartSoundSystem(iClient, MUSIC_NONE);
	}

	// if not on a team, the "valid client" check happens above already
	if (!IsValidPlayer(iClient))
	{
		int iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
		if (IsValidLivingPlayer(iTarget))
		{
			StartSoundSystem(iClient, g_iMusicLevel[iTarget]);
		}

		else
		{
			StartSoundSystem(iClient, MUSIC_NONE);
		}
	}
	else
	{
		/*
			Scared need to involve the following:
			Client health
			number of zombies surrounding him
			Zombie Rage
			on control point

			NONE            0
			VERYMILD1   >= 10
			VERYMILD2   >= 30
			VERYMILD3   >= 50
			MILD        >= 70
			INTENSE     >= 100

			Zombie calculation
			Zombies within 10 meters are counted
			The total inverted distance of all the zombies. ie 10 for a zombie right up your face.

			Scared = ZombieNum * 3 / Health% + Rage*20
		*/
		int iCurrentHealth = GetClientHealth(iClient);
		int iMaxHealth = SDK_GetMaxHealth(iClient);
		float fHealth = float(iCurrentHealth) / float(iMaxHealth);
		if (fHealth < 0.5) fHealth = 0.5;
		if (fHealth > 1.1) fHealth = 1.1;

		float fRage = 0.0;
		if (g_bZombieRage) fRage = 1.0;
		if (g_bInControlPoint[iClient]) fRage += 0.5;

		float fZombies = GetZombieNumber(iClient);

		float fScared = fZombies / fHealth + fRage * 20.0;

		int iMusic = MUSIC_NONE;
		// applies for only survivors
		if (IsSurvivor(iClient))
		{
			if (g_bRoundActive)
			{
				if (fScared >= 5.0) iMusic = MUSIC_VERYMILD1;
				if (fScared >= 30.0) iMusic = MUSIC_VERYMILD2;
				if (fScared >= 50.0) iMusic = MUSIC_VERYMILD3;
				if (fScared >= 70.0) iMusic = MUSIC_MILD;
				if (fScared >= 100.0) iMusic = MUSIC_INTENSE;

				if (g_bBackstabbed[iClient]) iMusic = MUSIC_PLAYERNEARDEATH;
				if (g_bGooified[iClient]) iMusic = MUSIC_JARATED;
				if (TF2_IsPlayerInCondition(iClient, TFCond_Jarated)) iMusic = MUSIC_GOO;
			}
		}

		// Applies for all
		if (g_bRoundActive)
		{
			if (ZombiesHaveTank() && (iMusic != MUSIC_GOO && iMusic != MUSIC_JARATED)) iMusic = MUSIC_TANKMOOD;
			if (GetSurvivorCount() == 1) iMusic = MUSIC_LASTSTANDMOOD;
			if (g_bCapturingLastPoint) iMusic = MUSIC_LASTSTANDMOOD;
			if (GetSecondsLeft() <= 9 && GetSecondsLeft() > -1) iMusic = MUSIC_LASTTENSECONDSMOOD;
		}

		StartSoundSystem(iClient, iMusic);
	}
}

void FastRespawnReset()
{
	if (g_hFastRespawnArray != INVALID_HANDLE) CloseHandle_2(g_hFastRespawnArray);
	g_hFastRespawnArray = CreateArray(3);
}

int FastRespawnNearby(int iClient, float fDistance, bool bMustBeInvisible = true)
{
	if (g_hFastRespawnArray == INVALID_HANDLE) return -1;

	Handle hTombola = CreateArray();

	float fPosClient[3];
	float fPosEntry[3];
	float fPosEntry2[3];
	float fEntryDistance;
	GetClientAbsOrigin(iClient, fPosClient);
	for (int i = 0; i < GetArraySize(g_hFastRespawnArray); i++)
	{
		GetArrayArray(g_hFastRespawnArray, i, fPosEntry);
		fPosEntry2[0] = fPosEntry[0];
		fPosEntry2[1] = fPosEntry[1];
		fPosEntry2[2] = fPosEntry[2] += 90.0;

		bool bAllow = true;

		fEntryDistance = GetVectorDistance(fPosClient, fPosEntry);
		fEntryDistance /= 50.0;
		if (fEntryDistance > fDistance) bAllow = false;

		// check if survivors can see it
		if (bMustBeInvisible && bAllow)
		{
			for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
			{
				if (IsValidLivingSurvivor(iSurvivor))
				{
					if (PointsAtTarget(fPosEntry, iSurvivor)) bAllow = false;
					if (PointsAtTarget(fPosEntry2, iSurvivor)) bAllow = false;
				}
			}
		}

		if (bAllow)
		{
			PushArrayCell(hTombola, i);
		}
	}

	if (GetArraySize(hTombola) > 0)
	{
		int iRandom = GetRandomInt(0, GetArraySize(hTombola)-1);
		int iResult = GetArrayCell(hTombola, iRandom);
		CloseHandle_2(hTombola);
		return iResult;
	}
	else
	{
		CloseHandle_2(hTombola);
	}
	return -1;
}

bool PerformFastRespawn(int iClient)
{
	if (!g_bZombieRage) return false;
	if (!g_bZombieRageAllowRespawn) return false;

	return PerformFastRespawn2(iClient);
}

bool PerformFastRespawn2(int iClient)
{
	// first let's find a target
	Handle hTombola = CreateArray();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingSurvivor(i)) PushArrayCell(hTombola, i);
	}

	if (GetArraySize(hTombola) <= 0)
	{
		CloseHandle_2(hTombola);
		return false;
	}

	int iTarget = GetArrayCell(hTombola, GetRandomInt(0, GetArraySize(hTombola)-1));
	CloseHandle_2(hTombola);

	int iResult = FastRespawnNearby(iTarget, 7.0);
	if (iResult < 0) return false;

	float fPosSpawn[3];
	float fPosTarget[3];
	float fAngle[3];
	GetArrayArray(g_hFastRespawnArray, iResult, fPosSpawn);
	GetClientAbsOrigin(iTarget, fPosTarget);
	VectorTowards(fPosSpawn, fPosTarget, fAngle);

	TeleportEntity(iClient, fPosSpawn, fAngle, NULL_VECTOR);
	return true;
}

void FastRespawnDataCollect()
{
	if (g_hFastRespawnArray == INVALID_HANDLE) FastRespawnReset();

	float fPos[3];
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient) && IsValidLivingPlayer(iClient) && FastRespawnNearby(iClient, 1.0, false) < 0 && !(GetEntityFlags(iClient) & FL_DUCKING == FL_DUCKING) && (GetEntityFlags(iClient) & FL_ONGROUND == FL_ONGROUND))
		{
			GetClientAbsOrigin(iClient, fPos);
			PushArrayArray(g_hFastRespawnArray, fPos);
		}
	}
}

stock void VectorTowards(float vOrigin[3], float vTarget[3], float vAngle[3])
{
	float vResults[3];

	MakeVectorFromPoints(vOrigin, vTarget, vResults);
	GetVectorAngles(vResults, vAngle);
}

stock bool PointsAtTarget(float fBeginPos[3], any iTarget)
{
	float fTargetPos[3];
	GetClientEyePosition(iTarget, fTargetPos);

	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(fBeginPos, fTargetPos, MASK_VISIBLE, RayType_EndPoint, TraceDontHitOtherEntities, iTarget);

	int iHit = -1;
	if (TR_DidHit(hTrace)) iHit = TR_GetEntityIndex(hTrace);

	CloseHandle_2(hTrace);
	return (iHit == iTarget);
}

stock int IsTouchingSurvivor(int iClient) {
    float vecMin[3], vecMax[3], vecOrigin[3];
    
    GetClientMins(iClient, vecMin);
    GetClientMaxs(iClient, vecMax);
    
    GetClientAbsOrigin(iClient, vecOrigin);
    
    TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceHitSurvivor);
    return TR_GetEntityIndex();
}

public bool TraceHitSurvivor(int iEntity, int iMask, any iData) {
    return (iEntity != iData && IsValidLivingSurvivor(iData));
}  

public bool TraceDontHitOtherEntities(int iEntity, int iMask, any iData)
{
	if (iEntity == iData) return true;
	if (iEntity > 0) return false;
	return true;
}

public bool TraceDontHitEntity(int iEntity, int iMask, any iData)
{
	if (iEntity == iData) return false;
	return true;
}

stock bool CanRecieveDamage(int iClient)
{
	if (iClient <= 0) return true;
	if (!IsClientInGame(iClient)) return true;
	if (isUbered(iClient)) return false;
	if (isBonked(iClient)) return false;

	return true;
}

stock bool ObstactleBetweenEntities(int iEntity1, int iEntity2)
{
	float vOrigin1[3];
	float vOrigin2[3];

	if (IsValidClient(iEntity1)) GetClientEyePosition(iEntity1, vOrigin1);
	else GetEntPropVector(iEntity1, Prop_Send, "m_vecOrigin", vOrigin1);
	GetEntPropVector(iEntity2, Prop_Send, "m_vecOrigin", vOrigin2);

	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin1, vOrigin2, MASK_ALL, RayType_EndPoint, TraceDontHitEntity, iEntity1);

	bool bHit = TR_DidHit(hTrace);
	int iHit = TR_GetEntityIndex(hTrace);
	CloseHandle_2(hTrace);

	if (!bHit) return true;
	if (iHit != iEntity2) return true;

	return false;
}

void HandleSurvivorLoadout(int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient)) return;
	char strChanges[255];
	TFClassType tfClass = TF2_GetPlayerClass(iClient);
	int iEntity = -1;

	// szf_ and survival mode is NOT enabled
	if (mapIsSZF() && !g_bSurvival)
	{
		// remove primary weapon
		TF2_RemoveWeaponSlot(iClient, 0);

		// remove secondary weapon and wearables
		iEntity = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary);
		if (iEntity > 0 && IsValidEdict(iEntity)) TF2_RemoveWeaponSlot(iClient, 1);
		RemoveWearableWeapons(iClient);
	}

	iEntity = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	if (iEntity > MaxClients && IsValidEdict(iEntity))
	{
		int iIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex"); // get item index

		switch (iIndex)
		{
			// half zatoichi: 50% base hp restored -> 20% base hp restored
			case 357:
			{
				TF2Attrib_SetByName(iEntity, "restore health on kill", view_as<float>(20));
				Format(strChanges, sizeof(strChanges), "{unique}The Half-Zatoichi {red}heals less.");
			}

			// market gardener: 80% blast damage from rocket jumps
			case 416:
			{
				TF2Attrib_SetByName(iEntity, "rocket jump damage reduction", 0.8);
				Format(strChanges, sizeof(strChanges), "{unique}The Market Gardener {green}makes you take 20pct less damage from Rocket Jumping.");
			}

			// homewrecker: no dmg penalty
			case 153, 466:
			{
				TF2Attrib_SetByName(iEntity, "dmg penalty vs players", 1.0);
				Format(strChanges, sizeof(strChanges), "{unique}The Homewrecker & reskins {green}have their damage penalty removed.");
			}

			// southern hospitality: 15% firing speed penalty
			case 155:
			{
				TF2Attrib_SetByName(iEntity, "fire rate penalty", 1.15);
				Format(strChanges, sizeof(strChanges), "{unique}The Southern Hospitality {red}has a 15pct firing speed penalty.");
			}

			// ubersaw: reduced uber gained on hit
			case 37, 1003:
			{
				TF2Attrib_SetByName(iEntity, "add uber charge on hit", 0.1);
				Format(strChanges, sizeof(strChanges), "{unique}The Ubersaw {red}gives 10pct uber on hit.");
			}

			// shiv: reduced damage penalty to 80%
			case 171:
			{
				TF2Attrib_SetByName(iEntity, "damage penalty", 0.8);
				Format(strChanges, sizeof(strChanges), "{unique}The Tribalman's Shiv {green}has its damage penalty reduced to 20pct.");
			}

			case 304:
			{
				TF2Attrib_SetByName(iEntity, "enables aoe heal", view_as<float>(0));
				TF2Attrib_SetByName(iEntity, "active health regen", view_as<float>(1));
				Format(strChanges, sizeof(strChanges), "{unique}The Amputator {red}does not heal when taunting.");
			}

			// pain train: 10% damage taken.
			case 333:
			{
				// THIS IS HANDLED IN OnTakeDamage
				Format(strChanges, sizeof(strChanges), "{unique}The Pain Train {red}makes you take 10pct additional damage.");
			}

			// eureka effect: replaced with stock
			case 589:
			{
				TF2_CreateAndEquipWeapon(iClient, 7);
				Format(strChanges, sizeof(strChanges), "{unique}The Eureka Effect {red}is disabled.");
			}

			// holiday punch: laugh is shorter and is treated as a backstab
			case ZFWEAP_MITTENS:
			{
				// THIS IS HANDLED IN OnTakeDamage
				Format(strChanges, sizeof(strChanges), "{unique}The Holiday Punch {red}has a shorter stun duration and is given the same treatment as other stuns.");
			}

			// kgb: crit is replaced with perma mini-crits
			case 43:
			{
				// THIS IS HANDLED IN handle_gameFrameLogic
				Format(strChanges, sizeof(strChanges), "{unique}The Killing Gloves of Boxing {green}gives you mini-crits on kill, lasting until you die.");
			}
		}

		// Apply healing drain for medic
		if (tfClass == TFClass_Medic)
		{
			TF2Attrib_SetByName(iEntity, "health drain", view_as<float>(-3));
		}

		// add penalty from medic healing
		TF2Attrib_SetByName(iEntity, "health from healers reduced", 0.5);
		TF2Attrib_ClearCache(iEntity); // refresh, go go!
	}
	else
	{
		// no melee, okay.. weird
		TF2_RespawnPlayer(iClient);
	}
	// Prevent chat spam
	if (g_flStopChatSpam[iClient] + 0.5 < GetGameTime() && strlen(strChanges) > 8)
	{
		CPrintToChat(iClient, strChanges);
		g_flStopChatSpam[iClient] = GetGameTime();
	}

	// robin hood: give jarate and huntsman
	if (IsMutationActive(MUTATION_ROBINHOOD))
	{
		TF2_CreateAndEquipWeapon(iClient, 56);
		TF2_CreateAndEquipWeapon(iClient, 58);
	}

	// This will affect people who were "Voodooified" and will do nothing on players not affected
	SetEntProp(iClient, Prop_Send, "m_bForcedSkin", 0);
	SetEntProp(iClient, Prop_Send, "m_nForcedSkin", 0);

	SetValidSlot(iClient);
}

void HandleZombieLoadout(int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient)) return;

	// Get melee, for later
	int iEntity = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);

	// No melee? force respawn
	if (iEntity <= MaxClients || !IsValidEdict(iEntity))
	{
		TF2_RespawnPlayer(iClient);
		return;
	}

	// Reset size
	ResizePlayer(iClient, 1.0);

	// Remove all weapons
	// For Secondary, some classes can use them in certain conditions.
	// For Melee, this update will allow Infected players to use a melee of their choice.
	TF2_RemoveWeaponSlot(iClient, 0);
	// TF2_RemoveWeaponSlot(iClient, 2);
	TF2_RemoveWeaponSlot(iClient, 3);
	TF2_RemoveWeaponSlot(iClient, 4);

	if (isScout(iClient))
	{
		// Allow drinks
		if (!isSlotClassname(iClient, 1, "tf_weapon_lunchbox_drink")) TF2_RemoveWeaponSlot(iClient, 1);

		// No choice in Melee weapons
		// TODO: for now.
		TF2_RemoveWeaponSlot(iClient, 2);

		iEntity = TF2_CreateAndEquipWeapon(iClient, (g_iSpecialInfected[iClient] == INFECTED_NONE) ? 44 : 0);
		if (g_iSpecialInfected[iClient] == INFECTED_NONE)
		{
			// Lower health because Sandman
			SetEntityHealth(iClient, 110);
			// Resize because internal damage nerf
			ResizePlayer(iClient, 0.9);
		}
	}

	if (isHeavy(iClient))
	{
		// Allow food items
		if (!isSlotClassname(iClient, 1, "tf_weapon_lunchbox")) TF2_RemoveWeaponSlot(iClient, 1);
	}

	if (isSpy(iClient))
	{
		TF2_RemoveWeaponSlot(iClient, 1);

		TF2_CreateAndEquipWeapon(iClient, 30); // Cloak
	}

	// Set zombie model / soul wearable
	Voodooify(iClient);

	// Set max health if Special Infected, no tanks allowed though
	if (g_iSpecialInfected[iClient] > INFECTED_TANK)
	{
		int iBonusHealth = g_cvarSpecialBonusHealth.IntValue;
		float flHealth = float(SDK_GetMaxHealth(iClient) + iBonusHealth);
		TF2Attrib_SetByName(iEntity, "max health additive bonus", float(iBonusHealth));
		SetEntityHealth(iClient, RoundToFloor(flHealth));
	}
	else
    {        
		TF2Attrib_RemoveByName(iEntity, "max health additive bonus");
		SetEntityHealth(iClient, SDK_GetMaxHealth(iClient));
    }

	// Set slot to melee
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iEntity);
	// Refresh attribute cache
	TF2Attrib_ClearCache(iEntity);
}

void SetValidSlot(int iClient)
{
	int iOld = GetEntProp(iClient, Prop_Send, "m_hActiveWeapon");
	if (iOld > 0) return;

	int iSlot;
	int iEntity;
	for (iSlot = 0; iSlot <= 5; iSlot++)
	{
		iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (iEntity > 0 && IsValidEdict(iEntity))
		{
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iEntity);
			return;
		}
	}
}

void SpitterGoo(int iClient, int iAttacker = 0, float flDuration = TIME_GOO)
{
	if (roundState() != RoundActive) return;
	//CPrintToChatAll("Spitter goo at %N!", iClient);

	if (g_hGoo == INVALID_HANDLE) g_hGoo = CreateArray(5);

	float fClientPos[3];
	float fClientEye[3];
	GetClientEyePosition(iClient, fClientPos);
	GetClientEyeAngles(iClient, fClientEye);

	g_iGooId++;
	int iEntry[5];
	iEntry[0] = RoundFloat(fClientPos[0]);
	iEntry[1] = RoundFloat(fClientPos[1]);
	iEntry[2] = RoundFloat(fClientPos[2]);
	iEntry[3] = iAttacker;
	iEntry[4] = g_iGooId;
	PushArrayArray(g_hGoo, iEntry);

	ShowParticle("asplode_hoodoo_dust", TIME_GOO, fClientPos, fClientEye);
	ShowParticle("asplode_hoodoo_green", TIME_GOO, fClientPos, fClientEye);

	CreateTimer(flDuration, GooExpire, g_iGooId);
	CreateTimer(1.0, GooEffect, g_iGooId, TIMER_REPEAT);
}

void GooDamageCheck()
{
	float fPosGoo[3];
	int iEntry[5];
	float fPosClient[3];
	float fDistance;
	int iAttacker;

	bool bWasGooified[MAXPLAYERS+1];

	int iClient;
	for (iClient = 1; iClient <= MaxClients; iClient++)
	{
		bWasGooified[iClient] = g_bGooified[iClient];
		g_bGooified[iClient] = false;
	}

	if (g_hGoo != INVALID_HANDLE)
	{
		for (int i = 0; i < GetArraySize(g_hGoo); i++)
		{
			GetArrayArray(g_hGoo, i, iEntry);
			fPosGoo[0] = float(iEntry[0]);
			fPosGoo[1] = float(iEntry[1]);
			fPosGoo[2] = float(iEntry[2]);
			iAttacker = iEntry[3];

			for (iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (IsValidLivingSurvivor(iClient) && !g_bGooified[iClient] && CanRecieveDamage(iClient) && !g_bBackstabbed[iClient])
				{
					GetClientEyePosition(iClient, fPosClient);
					fDistance = GetVectorDistance(fPosGoo, fPosClient) / 50.0;
					if (fDistance <= DISTANCE_GOO)
					{
						// deal damage
						g_iGooMultiplier[iClient] += GOO_INCREASE_RATE;
						float fPercentageDistance = (DISTANCE_GOO-fDistance) / DISTANCE_GOO;
						if (fPercentageDistance < 0.5) fPercentageDistance = 0.5;
						float fDamage = float(g_iGooMultiplier[iClient])/float(GOO_INCREASE_RATE) * fPercentageDistance;
						if (fDamage < 1.0) fDamage = 1.0;
						if (g_bInControlPoint[iClient] && fDamage > 4.0) fDamage = 4.0;
						int iDamage = RoundFloat(fDamage);
						DealDamage(iClient, iDamage, iAttacker, _, "projectile_stun_ball");
						g_bGooified[iClient] = true;
						EmitHitSoundToClient(iClient, fDamage >= 7.0);
					}
				}
			}
		}
	}
	for (iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			if (IsValidLivingPlayer(iClient) && !g_bGooified[iClient] && g_iGooMultiplier[iClient] > 0)
			{
				g_iGooMultiplier[iClient]--;
			}

			//ScreenFade(iClient, red, green, blue, alpha, delay, type)
			if (!bWasGooified[iClient] && g_bGooified[iClient] && IsPlayerAlive(iClient))
			{
				// fade screen slightly green
				ClientCommand(iClient, "r_screenoverlay\"left4fortress/goo\"");
				MusicHandleClient(iClient);
				//CPrintToChat(iClient, "You got goo'd!");
			}
			if (bWasGooified[iClient] && !g_bGooified[iClient])
			{
				// reset screen
				ClientCommand(iClient, "r_screenoverlay\"\"");
				MusicHandleClient(iClient);
				//CPrintToChat(iClient, "You are no longer goo'd!");
			}
		}
	}
}

public Action GooExpire(Handle hTimer, any iGoo)
{
	if (g_hGoo == null) return Plugin_Handled;

	int iEntry[5];
	int iEntryId;
	for (int i = 0; i < GetArraySize(g_hGoo); i++)
	{
		GetArrayArray(g_hGoo, i, iEntry);
		iEntryId = iEntry[4];
		if (iEntryId == iGoo)
		{
			RemoveFromArray(g_hGoo, i);
		}
	}

	return Plugin_Handled;
}

void RemoveAllGoo()
{
	if (g_hGoo == INVALID_HANDLE) return;

	ClearArray(g_hGoo);
}

public Action GooEffect(Handle hTimer, any iGoo)
{
	if (g_hGoo == INVALID_HANDLE) return Plugin_Stop;

	int iEntry[5];
	float fPos[3];
	int iEntryId;
	for (int i = 0; i < GetArraySize(g_hGoo); i++)
	{
		GetArrayArray(g_hGoo, i, iEntry);
		iEntryId = iEntry[4];
		fPos[0] = float(iEntry[0]);
		fPos[1] = float(iEntry[1]);
		fPos[2] = float(iEntry[2]);
		if (iEntryId == iGoo)
		{
			ShowParticle("asplode_hoodoo_green", TIME_GOO, fPos);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

public void OnEntityCreated(int iEntity, const char[] strClassname)
{
	if (StrEqual(strClassname, "tf_dropped_weapon"))
	{
		AcceptEntityInput(iEntity, "kill");
	}
	
	if (StrEqual(strClassname, "tf_projectile_stun_ball", false))
	{
		SDKHook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SDKHook(iEntity, SDKHook_Touch, BallTouch);
	}

	if (StrEqual(strClassname, "item_healthkit_medium"))
	{
		SDKHook(iEntity, SDKHook_StartTouch, OnSandvichTouch);
	}

	if (StrEqual(strClassname, "item_healthkit_small"))
	{
		SDKHook(iEntity, SDKHook_StartTouch, OnBananaTouch);
	}

	if (StrContains(strClassname, "item_healthkit") != -1
	|| StrContains(strClassname, "item_ammopack") != -1
	|| StrEqual(strClassname, "tf_ammo_pack"))
	{
		SDKHook(iEntity, SDKHook_StartTouch, OnPickup);
		SDKHook(iEntity, SDKHook_Touch, OnPickup);
	}
}

public Action BallStartTouch(int iEntity, int iOther)
{
	if (!zf_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "tf_projectile_stun_ball")) return Plugin_Continue;

	if (IsValidClient(iOther) && IsPlayerAlive(iOther) && IsSurvivor(iOther))
	{
		int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
		SDKUnhook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SpitterGoo(iOther, iOwner);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action BallTouch(int iEntity, int iOther)
{
	if (!zf_bEnabled) return Plugin_Continue;
	if (!IsClassname(iEntity, "tf_projectile_stun_ball")) return Plugin_Continue;

	if (iOther > 0 && iOther <= MaxClients && IsClientInGame(iOther) && IsPlayerAlive(iOther) && IsSurvivor(iOther))
	{
		SDKUnhook(iEntity, SDKHook_StartTouch, BallStartTouch);
		SDKUnhook(iEntity, SDKHook_Touch, BallTouch);
		AcceptEntityInput(iEntity, "kill");
	}

	return Plugin_Stop;
}

public Action OnSandvichTouch(int iEntity, int iClient)
{
	int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
	int iToucher = iClient;

	// if owner is valid, toucher is valid and are not on the same team
	if (IsValidClient(iOwner)
	&& IsValidClient(iToucher)
	&& GetClientTeam(iToucher) != GetClientTeam(iOwner))
	{
		// Disable Sandvich and kill it
		SetEntProp(iEntity, Prop_Data, "m_bDisabled", 1);
		AcceptEntityInput(iEntity, "Kill");

		DealDamage(iToucher, min(65, RoundToCeil(65 * g_fZombieDamageScale * 0.5)), iOwner);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action OnBananaTouch(int iEntity, int iClient)
{
	int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
	int iToucher = iClient;

	// if owner is valid, toucher is valid and are not on the same team
	if (IsValidClient(iOwner)
	&& IsValidClient(iToucher)
	&& GetClientTeam(iToucher) != GetClientTeam(iOwner))
	{
		// Disable Sandvich and kill it
		SetEntProp(iEntity, Prop_Data, "m_bDisabled", 1);
		AcceptEntityInput(iEntity, "Kill");

		DealDamage(iToucher, min(49, RoundToCeil(49 * g_fZombieDamageScale * 0.5)), iOwner);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

stock int ShowParticle(char[] particlename, float time, float pos[3], float ang[3]=NULL_VECTOR)
{
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, RemoveParticle, particle);
	}

	else
	{
		LogError("ShowParticle: could not create info_particle_system");
		return -1;
	}

	return particle;
}

stock void PrecacheParticle(char[] strName)
{
	if (IsValidEntity(0))
	{
		int iParticle = CreateEntityByName("info_particle_system");
		if (IsValidEdict(iParticle))
		{
			char tName[32];
			GetEntPropString(0, Prop_Data, "m_iName", tName, sizeof(tName));
			DispatchKeyValue(iParticle, "targetname", "tf2particle");
			DispatchKeyValue(iParticle, "parentname", tName);
			DispatchKeyValue(iParticle, "effect_name", strName);
			DispatchSpawn(iParticle);
			SetVariantString(tName);
			AcceptEntityInput(iParticle, "SetParent", 0, iParticle, 0);
			ActivateEntity(iParticle);
			AcceptEntityInput(iParticle, "start");
			CreateTimer(0.01, RemoveParticle, iParticle);
		}
	}
}

public Action RemoveParticle( Handle timer, any particle )
{
	if (particle >= 0 && IsValidEntity(particle))
	{
		char classname[32];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "Kill");
			particle = -1;
		}
	}
}

int GetMostDamageZom()
{
	Handle hArray = CreateArray();
	int i;
	int iHighest = 0;

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsValidZombie(i))
		{
			if (g_iDamage[i] > iHighest) iHighest = g_iDamage[i];
		}
	}

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsValidZombie(i) && g_iDamage[i] >= iHighest)
		{
			PushArrayCell(hArray, i);
		}
	}

	if (GetArraySize(hArray) <= 0)
	{
		CloseHandle_2(hArray);
		return 0;
	}

	int iClient = GetArrayCell(hArray, GetRandomInt(0, GetArraySize(hArray)-1));
	CloseHandle_2(hArray);
	return iClient;
}

bool ZombiesHaveTank()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingZombie(i) && g_iSpecialInfected[i] == INFECTED_TANK) return true;
	}
	return false;
}

void ZombieTank(int iCaller = 0)
{
	if (!zf_bEnabled) return;
	if (roundState() != RoundActive) return;
	if (iCaller <= 0 && g_bNoDirectorTanks) return;

	if (ZombiesHaveTank())
	{
		if (IsValidClient(iCaller)) CPrintToChat(iCaller, "{greenyellow}[SZF] {red}Zombies already have a tank.");
		return;
	}
	if (g_iZombieTank > 0)
	{
		if (IsValidClient(iCaller)) CPrintToChat(iCaller, "{greenyellow}[SZF] {red}A zombie tank is already on the way.");
		return;
	}
	if (g_bZombieRage)
	{
		if (IsValidClient(iCaller)) CPrintToChat(iCaller, "{greenyellow}[SZF] {red}Zombies are frenzied, tanks cannot spawn during frenzy.");
		return;
	}

	g_iZombieTank = GetMostDamageZom();
	if (g_iZombieTank <= 0) return;

	/* if the return above did not trigger, it is safe to make it
	** get the name of the selected tank so we can print it to the chat
	*/
	char strName[80];
	SZF_GetClientName(g_iZombieTank, strName, sizeof(strName));

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidZombie(i))
		{
			// ex. Gold Best Boss Owner Dispenz0r was chosen to become the TANK!
			CPrintToChat(i, "{greenyellow}[SZF] %s{green} was chosen to become the TANK!", strName);
		}
	}

	if (IsValidClient(iCaller))
	{
		CPrintToChat(iCaller, "{greenyellow}[SZF] {green}Called tank.");
	}

	g_bTankOnce = true;
	g_flTankCooldown = GetGameTime() + 60.0; // set new cooldown
	SetMoraleAll(0); // tank spawn, reset morale
}

bool TankCanReplace(int iClient)
{
	if (g_iZombieTank <= 0) return false;
	if (g_iZombieTank == iClient) return false;
	if (g_iSpecialInfected[iClient] != INFECTED_NONE) return false;
	if (TF2_GetPlayerClass(iClient) != TF2_GetPlayerClass(g_iZombieTank)) return false;

	int intHealth = GetClientHealth(g_iZombieTank);
	float fPos[3];
	float fAng[3];
	float fVel[3];

	GetClientAbsOrigin(g_iZombieTank, fPos);
	GetClientAbsAngles(g_iZombieTank, fVel);
	GetEntPropVector(g_iZombieTank, Prop_Data, "m_vecVelocity", fVel);
	SetEntityHealth(iClient, intHealth);
	TeleportEntity(iClient, fPos, fAng, fVel);

	TF2_RespawnPlayer(g_iZombieTank);
	CreateTimer(0.1, timer_postSpawn, g_iZombieTank, TIMER_FLAG_NO_MAPCHANGE);

	return true;
}

stock bool HasRazorback(int iClient)
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable")) != -1)
	{
		if (IsClassname(iEntity, "tf_wearable") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient && GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 57) return true;
	}
	return false;
}

void RemoveWearableWeapons(int iClient)
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable_demoshield")) != -1)
	{
		if (IsClassname(iEntity, "tf_wearable_demoshield") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			RemoveEdict(iEntity);
		}
	}

	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable")) != -1)
	{
		if (IsClassname(iEntity, "tf_wearable") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient &&
			(GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 57
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 231
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 642
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 405
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 608
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 133
			|| GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex") == 444))
		{
			RemoveEdict(iEntity);
		}
	}
}

stock bool RemoveSecondaryWearable(int iClient)
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "tf_wearable")) != -1)
	{
		if (IsClassname(iEntity, "tf_wearable") && GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			RemoveEdict(iEntity);
			return true;
		}
	}
	return false;
}

bool MusicCanReset(int iMusic)
{
	if (iMusic == MUSIC_INTENSE) return false;
	if (iMusic == MUSIC_MILD) return false;
	if (iMusic == MUSIC_VERYMILD3) return false;
	return true;
}

int GetAverageDamage()
{
	int iTotalDamage = 0;
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			iTotalDamage += g_iDamage[i];
			iCount++;
		}
	}
	return RoundFloat(float(iTotalDamage) / float(iCount));
}

int GetActivePlayerCount()
{
	int i = 0;
	for (int j = 1; j <= MaxClients; j++)
	{
		if (IsValidLivingPlayer(j)) i++;
	}
	return i;
}

void DetermineControlPoints()
{
	g_bCapturingLastPoint = false;
	g_iControlPoints = 0;

	for (int i = 0; i < sizeof(g_iControlPointsInfo); i++)
	{
		g_iControlPointsInfo[i][0] = -1;
	}

	//LogMessage("SZF: Calculating cps...");

	int iMaster = -1;

	int iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "team_control_point_master")) != -1) {
		if (IsClassname(iEntity, "team_control_point_master")) {
			iMaster = iEntity;
		}
	}

	if (iMaster <= 0)
	{
		//LogMessage("No master found");
		return;
	}

	iEntity = -1;
	while ((iEntity = FindEntityByClassname2(iEntity, "team_control_point")) != -1)
	{
		if (IsClassname(iEntity, "team_control_point") && g_iControlPoints < sizeof(g_iControlPointsInfo))
		{
			int iIndex = GetEntProp(iEntity, Prop_Data, "m_iPointIndex");
			g_iControlPointsInfo[g_iControlPoints][0] = iIndex;
			g_iControlPointsInfo[g_iControlPoints][1] = 0;
			g_iControlPoints++;

			//LogMessage("Found CP with index %d", iIndex);
		}
	}

	//LogMessage("Found a total of %d cps", g_iControlPoints);

	CheckRemainingCP();
}

void CheckRemainingCP()
{
	g_bCapturingLastPoint = false;
	if (g_iControlPoints <= 0) return;

	//LogMessage("Checking remaining CP");

	int iCaptureCount = 0;
	int iCapturing = 0;
	for (int i = 0; i < g_iControlPoints; i++)
	{
		if (g_iControlPointsInfo[i][1] >= 2) iCaptureCount++;
		if (g_iControlPointsInfo[i][1] == 1) iCapturing++;
	}

	//LogMessage("Capture count: %d, Max CPs: %d, Capturing: %d", iCaptureCount, g_iControlPoints, iCapturing);

	if (iCaptureCount == g_iControlPoints-1 && iCapturing > 0)
	{
		g_bCapturingLastPoint = true;
		if (!g_bSurvival && (!g_bTankOnce || g_fZombieDamageScale >= 1.4)) ZombieTank();
	}
}

bool AttemptCarryItem(int iClient)
{
	if (DropCarryingItem(iClient)) return true;

	int iTarget = GetEntityInClientCrosshair(iClient);

	char strClassname[255];
	if (iTarget > 0) GetEdictClassname(iTarget, strClassname, sizeof(strClassname));
	if (iTarget <= 0 || !(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override"))) return false;

	char strName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", strName, sizeof(strName));
	if (!(StrContains(strName, "szf_carry", false) != -1 || StrEqual(strName, "gascan", false) || StrContains(strName, "szf_pick", false) != -1 || StrContains(strName, "redsun_pickup", false) != -1)) return false;

	g_iCarryingItem[iClient] = iTarget;
	SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 0);
	//CPrintToChat(iClient, "Picked up gas can %d", iTarget);
	AcceptEntityInput(iTarget, "DisableMotion");
	//CPrintToChat(iClient, "m_usSolidFlags: %d", GetEntProp(iTarget, Prop_Send, "m_usSolidFlags"));
	SetEntProp(iTarget, Prop_Send, "m_nSolidType", SOLID_NONE); 
	EmitSoundToClient(iClient, "ui/item_paint_can_pickup.wav");
	PrintHintText(iClient, "Call 'MEDIC!' to drop your item!\nYou can attack while wielding an item.");

	if (isSoldier(iClient))
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_Soldier)-1);
		EmitSoundToAll(g_strCarryVO_Soldier[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (isPyro(iClient))
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_Pyro)-1);
		EmitSoundToAll(g_strCarryVO_Pyro[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (isDemoman(iClient))
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_DemoMan)-1);
		EmitSoundToAll(g_strCarryVO_DemoMan[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (isEngineer(iClient))
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_Engineer)-1);
		EmitSoundToAll(g_strCarryVO_Engineer[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (isMedic(iClient))
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_Medic)-1);
		EmitSoundToAll(g_strCarryVO_Medic[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	if (isSniper(iClient))
	{
		int iRandom = GetRandomInt(0, sizeof(g_strCarryVO_Sniper)-1);
		EmitSoundToAll(g_strCarryVO_Sniper[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
	}

	return true;
}

void UpdateClientCarrying(int iClient)
{
	int iTarget = g_iCarryingItem[iClient];

	//PrintCenterText(iClient, "Teleporting gas can (%d)", iTarget);

	if (iTarget <= 0) return;
	if (!(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override")))
	{
		DropCarryingItem(iClient);
		return;
	}

	//PrintCenterText(iClient, "Teleporting gas can 1");

	char strName[255];
	GetEntPropString(iTarget, Prop_Data, "m_iName", strName, sizeof(strName));
	if (!(StrContains(strName, "szf_carry", false) != -1 || StrEqual(strName, "gascan", false) || StrContains(strName, "szf_pick", false) != -1 || StrContains(strName, "redsun_pickup", false) != -1)) return;

	float vOrigin[3];
	float vAngles[3];
	float vDistance[3];
	float vEmpty[3];
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);
	vAngles[0] = 5.0;

	vOrigin[2] -= 20.0;

	vAngles[2] += 35.0;
	AnglesToVelocity(vAngles, vDistance, 60.0);
	AddVectors(vOrigin, vDistance, vOrigin);
	TeleportEntity(iTarget, vOrigin, vAngles, vEmpty);

	//PrintCenterText(iClient, "Teleporting gas can");
}

bool DropCarryingItem(int iClient, bool bDrop = true)
{
	int iTarget = g_iCarryingItem[iClient];
	if (iTarget <= 0) return false;

	g_iCarryingItem[iClient] = -1;
	SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 1);

	if (!(IsClassname(iTarget, "prop_physics") || IsClassname(iTarget, "prop_physics_override"))) return true;

	//CPrintToChat(iClient, "Dropped gas can");
	SetEntProp(iTarget, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
	AcceptEntityInput(iTarget, "EnableMotion");

	if (bDrop)
	{
		float vOrigin[3];
		GetClientEyePosition(iClient, vOrigin);

		if (!IsEntityStuck(iTarget) && !ObstactleBetweenEntities(iClient, iTarget))
		{
			vOrigin[0] += 20.0;
			vOrigin[2] -= 30.0;
		}

		TeleportEntity(iTarget, vOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	return true;
}

stock void AnglesToVelocity(float fAngle[3], float fVelocity[3], float fSpeed = 1.0)
{
	fVelocity[0] = Cosine(DegToRad(fAngle[1]));
	fVelocity[1] = Sine(DegToRad(fAngle[1]));
	fVelocity[2] = Sine(DegToRad(fAngle[0])) * -1.0;

	NormalizeVector(fVelocity, fVelocity);

	ScaleVector(fVelocity, fSpeed);
}

stock bool IsEntityStuck(int iEntity)
{
	float vecMin[3];
	float vecMax[3];
	float vecOrigin[3];

	GetEntPropVector(iEntity, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vecMax);
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);

	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceDontHitEntity, iEntity);
	return (TR_DidHit());
}

public Action SoundHook(int clients[64], int &numClients, char sound[PLATFORM_MAX_PATH], int &Ent, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	int iClient = Ent;

	if (!IsValidClient(iClient))
	{
		return Plugin_Continue;
	}

	if (StrContains(sound, "vo/", false) != -1 && IsZombie(iClient))
	{
		// normal infected & kingpin(pitch only)
		if (g_iSpecialInfected[iClient] == INFECTED_NONE || g_iSpecialInfected[iClient] == INFECTED_KINGPIN)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				// TODO: add this? has never been implemented
				// if (isOnFire(iClient))
				// {
				// 	Format(sound, sizeof(sound), "left4fortress/zombie_vo/ignite0%d.mp3", GetRandomInt(7, 9));
				// }

				if (GetClientHealth(iClient) < 50 || StrContains(sound, "critical", false) != -1)
				{
					Format(sound, sizeof(sound), "left4fortress/zombie_vo/death_2%d.mp3", GetRandomInt(2, 9));
				}

				else
				{
					int iRandom = GetRandomInt(18, 22);
					if (iRandom == 15 || iRandom == 16 || iRandom == 17 || iRandom == 23) iRandom = GetRandomInt(12, 14);
					Format(sound, sizeof(sound), "left4fortress/zombie_vo/been_shot_%d.mp3", iRandom);
				}
			}

			if (StrContains(sound, "_laugh", false) != -1 || StrContains(sound, "_no", false) != -1 || StrContains(sound, "_yes", false) != -1)
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/mumbling0%d.mp3", GetRandomInt(1, 8));
			}

			if (StrContains(sound, "_go", false) != -1 || StrContains(sound, "_jarate", false) != -1)
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/shoved_%d.mp3", GetRandomInt(1, 4));
			}

			if (StrContains(sound, "_medic", false) != -1)
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/rage_at_victim2%d.mp3", !GetRandomInt(0, 2) ? GetRandomInt(1, 2) : GetRandomInt(5, 6));
			}

			else
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/idle_breath_0%d.mp3", GetRandomInt(1, 4));
			}

			if (g_iSpecialInfected[iClient] == INFECTED_KINGPIN) pitch = 80;
		}


		// tank
		if (g_iSpecialInfected[iClient] == INFECTED_TANK)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				if (isOnFire(iClient))
				{
					Format(sound, sizeof(sound), "left4fortress/zombie_vo/tank_fire_0%d.mp3", GetRandomInt(2, 5));
				}

				else
				{
					Format(sound, sizeof(sound), "left4fortress/zombie_vo/tank_pain_0%d.mp3", GetRandomInt(1, 4));
				}
			}

			else
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/tank_voice_0%d.mp3", GetRandomInt(1, 4));
			}
		}

		// charger
		if (g_iSpecialInfected[iClient] == INFECTED_CHARGER)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/charger_pain_0%d.mp3", GetRandomInt(1, 3));
			}

			else
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/charger_spotprey_0%d.mp3", GetRandomInt(1, 3));
			}
		}

		// hunter
		if (g_iSpecialInfected[iClient] == INFECTED_HUNTER)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/hunter_pain_1%d.mp3", GetRandomInt(2, 4));
			}

			else
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/hunter_stalk_0%d.mp3", GetRandomInt(4, 6));
			}
		}

		// boomer
		if (g_iSpecialInfected[iClient] == INFECTED_BOOMER)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/male_boomer_pain_%d.mp3", GetRandomInt(1, 3));
			}

			else
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/male_boomer_lurk_0%d.mp3", GetRandomInt(2, 4));
			}
		}

		// smoker
		if (g_iSpecialInfected[iClient] == INFECTED_SMOKER)
		{
			if (StrContains(sound, "_pain", false) != -1)
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/smoker_pain_0%d.mp3", GetRandomInt(2, 4));
			}

			else
			{
				Format(sound, sizeof(sound), "left4fortress/zombie_vo/smoker_lurk_1%d.mp3", GetRandomInt(1, 3));
			}
		}

		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action OnPickup(int iEntity, int iClient)
{
	// if picker is a zombie and entity has no owner (sandvich)
	if (IsValidZombie(iClient) && GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity") == -1)
	{
		char strClassname[32];
		GetEntityClassname(iEntity, strClassname, sizeof(strClassname));
		if (StrContains(strClassname, "item_ammopack") != -1 || StrContains(strClassname, "item_healthkit") != -1 || StrEqual(strClassname, "tf_ammo_pack"))
		{
			return Plugin_Handled;
		}
	}

	// if picker is a survivor and is stunned, do not allow people to pick up anything
	if (IsValidSurvivor(iClient) && g_bBackstabbed[iClient])
	{
		char strClassname[32];
		GetEntityClassname(iEntity, strClassname, sizeof(strClassname));
		if (StrContains(strClassname, "item_ammopack") != -1 || StrContains(strClassname, "item_healthkit") != -1 || StrEqual(strClassname, "tf_ammo_pack"))
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (IsValidLivingZombie(iClient))
	{
		// smoker
		if (g_iSpecialInfected[iClient] == INFECTED_SMOKER)
		{
			if (iButtons & IN_ATTACK2 && isGrounded(iClient))
			{
				// nullify all movement
				SetEntityMoveType(iClient, MOVETYPE_NONE);
				fVelocity[0] = 0.0;
				fVelocity[1] = 0.0;
				// beam
				DoSmokerBeam(iClient);
				iButtons &= ~IN_ATTACK2;
			}

			// we use this to reset smoker's movement speed stuff back
			else if (GetEntityMoveType(iClient) == MOVETYPE_NONE)
			{
				g_iSmokerBeamHits[iClient] = 0;
				g_iSmokerBeamHitVictim[iClient] = 0;
				SetEntityMoveType(iClient, MOVETYPE_WALK);
			}
		}

		// stalker
		if (g_iSpecialInfected[iClient] == INFECTED_STALKER)
		{
			// to prevent fuckery with cloaking
			if (iButtons & IN_ATTACK2)
			{
				iButtons &= ~IN_ATTACK2;
			}
		}

		// if on the ground
		if (isGrounded(iClient)) {
			// and crouching
			if (isCrouching(iClient)) {
				// and size is not modified and higher than this value
				if (g_flSetSize[iClient] > 0.99) {
					// lower size, to prevent getting stuck when crouching through stuff
					ResizePlayer(iClient, 0.99);
				}
			}

			// not crouching AND not touching a survivor while having their size modified
			else if (!isCrouching(iClient) && !IsEntityStuck(iClient) && !IsTouchingSurvivor(iClient) && g_flSetSize[iClient] == 0.99) {
				// special infected, not tank
				if (g_iSpecialInfected[iClient] > INFECTED_TANK) {
					ResizePlayer(iClient, 1.05);
				}
				// tank
				else if (g_iSpecialInfected[iClient] == INFECTED_TANK) {
					ResizePlayer(iClient, 1.2);
				}
			}
		}
	}

	if (IsSurvivor(iClient))
	{
		// if in primary or secondary attack, no weapon cooldown and a weapon was picked up
		if ((iButtons & IN_ATTACK || iButtons & IN_ATTACK2)
			&& g_fLastPickup[iClient] + PICKUP_COOLDOWN < GetGameTime()
			&& AttemptGrabItem(iClient))
		{
			// block the primary and secondary attack
			iButtons &= ~IN_ATTACK;
			iButtons &= ~IN_ATTACK2;
		}
	}

	return Plugin_Continue;
}

bool AttemptGrabItem(int iClient)
{
	int iEntity = GetEntityInClientCrosshair(iClient);
	int iItem = -1; // weapon id
	char strModel[255]; // weapon model path

	if (iEntity <= 0 || !IsClassname(iEntity, "prop_dynamic") || GetWeaponType(iEntity) <= 0) return false;

	// Get model path
	GetEntityModel(iEntity, strModel, sizeof(strModel));

	// Pick-ups
	if (StrEqual(strModel, "models/items/ammopack_large.mdl") || StrEqual(strModel, "models/items/medkit_large.mdl"))
	{
		SpawnPickup(iClient, StrEqual(strModel, "models/items/ammopack_large.mdl") ? "item_ammopack_full" : "item_healthkit_full");
		EmitSoundToClient(iClient, "ui/item_heavy_gun_pickup.wav"); // TODO: CHANGE SOUND
		AcceptEntityInput(iEntity, ENT_ONKILL);
		AcceptEntityInput(iEntity, "Kill");
		return true;
	}

	//
	// Multi-Class
	//
	if (StrContainsWeapon(strModel, "shotgun"))
	{
		if (isSoldier(iClient)) iItem = 10;
		if (isPyro(iClient)) iItem = 12;
		if (isEngineer(iClient)) iItem = 9;
	}
	else if (StrContainsWeapon(strModel, "reserve_shooter")) iItem = 415;
	else if (StrContainsWeapon(strModel, "trenchgun")) iItem = 1153;

	//
	// Soldier
	//
	else if (StrContainsWeapon(strModel, "rocketlauncher")) iItem = 18;
	else if (StrContainsWeapon(strModel, "directhit")) iItem = 127;
	else if (StrContainsWeapon(strModel, "blackbox")) iItem = 228;
	else if (StrContainsWeapon(strModel, "drg_cowmangler")) iItem = 441;
	else if (StrContainsWeapon(strModel, "drg_righteousbison")) iItem = 442;
	else if (StrContainsWeapon(strModel, "liberty_launcher")) iItem = 414;
	else if (StrContainsWeapon(strModel, "bet_rocketlauncher")) iItem = 513;
	else if (StrContainsWeapon(strModel, "dumpster_device")) iItem = 730;
	else if (StrContainsWeapon(strModel, "atom_launcher")) iItem = 1104;
	// Secondary
	else if (StrContainsWeapon(strModel, "shogun_warhorn")) iItem = 354;
	else if (StrContainsWeapon(strModel, "bugle")) iItem = 129;
	else if (StrContainsWeapon(strModel, "battalion_bugle")) iItem = 226;

	//
	// Pyro
	//
	else if (StrContainsWeapon(strModel, "flamethrower")) iItem = 21;
	else if (StrContainsWeapon(strModel, "backburner")) iItem = 40;
	else if (StrContainsWeapon(strModel, "degreaser")) iItem = 215;
	else if (StrContainsWeapon(strModel, "rainblower")) iItem = 741;
	else if (StrContainsWeapon(strModel, "flameball")) iItem = 1178;
	// Secondary
	else if (StrContainsWeapon(strModel, "flaregun_pyro")) iItem = 39;
	else if (StrContainsWeapon(strModel, "detonator")) iItem = 351;
	else if (StrContainsWeapon(strModel, "scorch_shot")) iItem = 740;
	else if (StrContainsWeapon(strModel, "drg_manmelter")) iItem = 595;

	//
	// Demoman
	//
	else if (StrContainsWeapon(strModel, "grenadelauncher")) iItem = 19;
	else if (StrContainsWeapon(strModel, "lochnload")) iItem = 308;
	else if (StrContainsWeapon(strModel, "demo_cannon")) iItem = 996;
	else if (StrContainsWeapon(strModel, "quadball")) iItem = 1151;
	// Secondary
	else if (StrContainsWeapon(strModel, "scottish_resistance")) iItem = 130;
	else if (StrContainsWeapon(strModel, "stickybomb_launcher")) iItem = 20;
	else if (StrContainsWeapon(strModel, "kingmaker_sticky")) iItem = 1150;
	// Secondary, shields
	else if (StrContainsWeapon(strModel, "targe")) iItem = 131;
	else if (StrContainsWeapon(strModel, "persian_shield")) iItem = 406;
	else if (StrContainsWeapon(strModel, "wheel_shield")) iItem = 1099;

	//
	// Engineer
	//
	else if (StrContainsWeapon(strModel, "frontierjustice")) iItem = 141;
	else if (StrContainsWeapon(strModel, "dex_shotgun")) iItem = 527;
	else if (StrContainsWeapon(strModel, "drg_pomson")) iItem = 588;
	else if (StrContainsWeapon(strModel, "tele_shotgun")) iItem = 997;
	// Secondary
	else if (StrContainsWeapon(strModel, "pistol")) iItem = 22;
	else if (StrContainsWeapon(strModel, "wrangler")) iItem = 140;

	//
	// Medic
	//
	else if (StrContainsWeapon(strModel, "syringegun")) iItem = 17;
	else if (StrContainsWeapon(strModel, "leechgun")) iItem = 36;
	else if (StrContainsWeapon(strModel, "crusaders_crossbow")) iItem = 305;
	else if (StrContainsWeapon(strModel, "proto_syringegun")) iItem = 412;
	// Secondary
	else if (StrContainsWeapon(strModel, "medigun")) iItem = 29;
	else if (StrContainsWeapon(strModel, "proto_medigun")) iItem = 411;
	else if (StrContainsWeapon(strModel, "medigun_defense")) iItem = 998;

	//
	// Sniper
	//
	else if (StrContainsWeapon(strModel, "sniperrifle")) iItem = 14;
	else if (StrContainsWeapon(strModel, "dartgun")) iItem = 230;
	else if (StrContainsWeapon(strModel, "bazaar_sniper")) iItem = 402;
	else if (StrContainsWeapon(strModel, "dex_sniperrifle")) iItem = 526;
	else if (StrContainsWeapon(strModel, "pro_rifle")) iItem = 752;
	else if (StrContainsWeapon(strModel, "tfc_sniperrifle")) iItem = 1098;
	// Secondary
	else if (StrContainsWeapon(strModel, "smg")) iItem = 16;
	else if (StrContains(strModel, "urinejar.mdl") != -1) iItem = 58;
	else if (StrContainsWeapon(strModel, "bow")) iItem = 56;
	else if (StrContainsWeapon(strModel, "pro_smg")) iItem = 751;
	
	// No item found, return
	if (iItem == -1) return false;

	// Start processing 
	int iSlot = TF2Econ_GetItemSlot(iItem, TF2_GetPlayerClass(iClient));
	char strWeaponName[64]; // weapon name in tf2

	// Automatically determine "rarity"
	for (int i = 0; i < sizeof(g_intRareWeapon); i++) {
		if (iItem == g_intRareWeapon[i]) {
			TF2Econ_GetLocalizedItemName(iItem, strWeaponName, sizeof(strWeaponName));
			break;
		}
	}

	// does this item fit in a slot of our player?
	if (iSlot != -1) 
	{
		// Is it a rare weapon? (this string is not empty if it is)
		if (strlen(strWeaponName) > 0 && g_fLastRarePickup[iClient] + 10.0 < GetGameTime())
		{
			SZF_CPrintToChatAll(iClient, "I have picked up {unique}{param3}\x01!", true, _, _, strWeaponName);
			g_fLastRarePickup[iClient] = GetGameTime();
		}

		PickupWeapon(iClient, iItem, iEntity);
		return true;
	}
	// else, does it not fit, but is it a rare weapon we can call out?
	else if (strlen(strWeaponName) > 0 && g_fLastCallout[iClient] + 5.0 < GetGameTime())
	{
		SZF_CPrintToChatAll(iClient, "{unique}{param3} \x01here!", true, _, _, strWeaponName);
		ShowAnnotationOnObject(iEntity, strWeaponName, surTeam(), 5.0);

		g_fLastCallout[iClient] = GetGameTime();
	}

	return false;
}

void PickupWeapon(int iClient, int iItemIndex, int iWeaponEntity)
{
	int iSlot = TF2Econ_GetItemSlot(iItemIndex, TF2_GetPlayerClass(iClient));
	char strPath[255];

	// Pick-up vocals
	switch(TF2_GetPlayerClass(iClient))
	{
		// case TFClass_Scout:
		case TFClass_Soldier: strPath = g_strWeaponVO_Soldier[GetRandomInt(0, sizeof(g_strWeaponVO_Soldier)-1)];
		case TFClass_Pyro: strPath = g_strWeaponVO_Pyro[GetRandomInt(0, sizeof(g_strWeaponVO_Pyro)-1)];
		case TFClass_DemoMan: strPath = g_strWeaponVO_DemoMan[GetRandomInt(0, sizeof(g_strWeaponVO_DemoMan)-1)];
		// case TFClass_Heavy:
		case TFClass_Medic: strPath = g_strWeaponVO_Medic[GetRandomInt(0, sizeof(g_strWeaponVO_Medic)-1)];
		case TFClass_Engineer: strPath = g_strWeaponVO_Engineer[GetRandomInt(0, sizeof(g_strWeaponVO_Engineer)-1)];
		case TFClass_Sniper: strPath = g_strWeaponVO_Sniper[GetRandomInt(0, sizeof(g_strWeaponVO_Sniper)-1)];
		// case TFClass_Spy:
	} EmitSoundToAll(strPath, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);

	// Gun sounds
	if (IsWeaponTypeRare(iWeaponEntity)) {
		// rare
		EmitSoundToClient(iClient, "ui/item_heavy_gun_pickup.wav");
	} else if (IsWeaponTypeSpawn(iWeaponEntity)) {
		// spawn
		EmitSoundToClient(iClient, "ui/item_light_gun_pickup.wav");
	} else {
		// everything else
		EmitSoundToClient(iClient, "ui/item_pack_pickup.wav");
	}

	// Is it a non-spawn (replaceable) weapon?
	if (!IsWeaponTypeSpawn(iWeaponEntity))
	{
		char strModel[99]; // weapon model path

		// Weapons
		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (iEntity > MaxClients && IsValidEdict(iEntity))
		{
			int iItem = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
			TF2Econ_GetItemDefinitionString(iItem, "model_player", strModel, sizeof(strModel));
			if (strlen(strModel) > 0) PrecacheModel(strModel);
		}

		// tf_wearable weapons
		int iWearable = SDK_GetEquippedWearable(iClient, iSlot);
		if (iWearable > MaxClients)
		{
			int iItem = GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex");
			TF2Econ_GetItemDefinitionString(iItem, "model_player", strModel, sizeof(strModel));
			if (strlen(strModel) > 0) PrecacheModel(strModel);

			SDK_RemoveWearable(iClient, iWearable);
		}

		if (strlen(strModel) > 0) {
			// Replace
			SetEntityModel(iWeaponEntity, strModel);
		} else {
			// Kill it completely
			AcceptEntityInput(iWeaponEntity, ENT_ONKILL);
			AcceptEntityInput(iWeaponEntity, "Kill");
		}

		// is a slot was marked as being filled from a spawn weapon, undo variable storing that
		if (g_iPickupWeaponSlotFromSpawn[iClient] == iSlot)
		{
			g_iPickupWeaponSlotFromSpawn[iClient] = -1;
		}
	}

	// is it a spawn weapon?
	if (IsWeaponTypeSpawn(iWeaponEntity))
	{
		// make sure player can only pick up one spawn weapon at a time
		if (g_iPickupWeaponSlotFromSpawn[iClient] > -1)
		{
			int iSlotToRemove = g_iPickupWeaponSlotFromSpawn[iClient];
			TF2_RemoveWeaponSlot(iClient, iSlotToRemove);

			// wearables check
			int iWearable = SDK_GetEquippedWearable(iClient, iSlotToRemove);
			if (iWearable > MaxClients) {
					SDK_RemoveWearable(iClient, iWearable);
					AcceptEntityInput(iWearable, "Kill");
			}

			CPrintToChat(iClient, "{greenyellow}[SZF] {red}You can only have one slot occupied by a weapon from the spawn.");
		}

		// set the weapon slot which is now filled by a spawn weapon
		g_iPickupWeaponSlotFromSpawn[iClient] = iSlot;
	}

	// force crit reset
	SetEntProp(iClient, Prop_Send, "m_iRevengeCrits", 0);

	// Generate and Equip the model, switch to it if not a wearable item
	int iWeapon = TF2_CreateAndEquipWeapon(iClient, iItemIndex);

	char strWeaponClassName[32];
	TF2Econ_GetItemClassName(iItemIndex, strWeaponClassName, sizeof(strWeaponClassName));
	if (StrContains(strWeaponClassName, "tf_wearable") != 0)
	{
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	}

	// trigger ENT_ONPICKUP
	if (g_bTriggerEntity[iWeaponEntity])
	{
		AcceptEntityInput(iWeaponEntity, ENT_ONPICKUP);
		g_bTriggerEntity[iWeaponEntity] = false;
	}

	g_fLastPickup[iClient] = GetGameTime();
}

stock bool IsClassname(int iEntity, char[] strClassname)
{
	if (iEntity <= 0) return false;
	if (!IsValidEdict(iEntity)) return false;

	char strClassname2[32];
	GetEdictClassname(iEntity, strClassname2, sizeof(strClassname2));
	if (StrEqual(strClassname, strClassname2, false)) return true;
	return false;
}

stock int FindEntityByClassname2(int startEnt, const char[] classname)
{
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, classname);
}

stock void SwitchToSlot(int iClient, int iSlot)
{
	if (GetPlayerWeaponSlot(iClient, iSlot) > 0)
	{
		EquipPlayerWeapon(iClient, weapon);
	}
}

// Grabs the entity model by looking in the precache database of the server
stock void GetEntityModel(int iEntity, char[] strModel, int iMaxSize, char[] strPropName = "m_nModelIndex")
{
	int iIndex = GetEntProp(iEntity, Prop_Send, strPropName);
	GetModelPath(iIndex, strModel, iMaxSize);
}

stock void GetModelPath(int iIndex, char[] strModel, int iMaxSize)
{
	int iTable = FindStringTable("modelprecache");
	ReadStringTable(iTable, iIndex, strModel, iMaxSize);
}

stock int GetEntityInClientCrosshair(int iClient)
{
	float vOrigin[3], vAngles[3], vEndOrigin[3];
	GetClientEyePosition(iClient, vOrigin);
	GetClientEyeAngles(iClient, vAngles);

	Handle hTrace = INVALID_HANDLE;
	hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_ALL, RayType_Infinite, TraceDontHitEntity, iClient);
	TR_GetEndPosition(vEndOrigin, hTrace);

	int iReturn = -1;
	int iHit = TR_GetEntityIndex(hTrace);

	if (TR_DidHit(hTrace) && iHit != iClient && GetVectorDistance(vOrigin, vEndOrigin) <= 96.0) // Why is John As dividing by 50?
	{
		iReturn = iHit;
	}

	delete hTrace;

	return iReturn;
}

void SDK_Init()
{
	Handle hGameData = LoadGameConfigFile("sdkhooks.games");
	if (hGameData == null) SetFailState("Could not find sdkhooks.games gamedata!");
	
	//This function is used to retreive player's max health
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxHealth = EndPrepSDKCall();
	if(g_hSDKGetMaxHealth == null)
	{
		LogMessage("Failed to create call: CTFPlayer::GetMaxHealth!");
	}
	
	delete hGameData;
	
	hGameData = LoadGameConfigFile("szf");
	
	// This call gets wearable equipped in loadout slots
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKGetEquippedWearable = EndPrepSDKCall();
	if(g_hSDKGetEquippedWearable == null)
	{
		LogMessage("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot!");
	}
	
	delete hGameData;
	
	hGameData = LoadGameConfigFile("sm-tf2.games");
	if (hGameData == null) SetFailState("Could not find sm-tf2.games gamedata!");
	
	int iRemoveWearableOffset = GameConfGetOffset(hGameData, "RemoveWearable");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(iRemoveWearableOffset);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveWearable = EndPrepSDKCall();
	if (g_hSDKRemoveWearable == null)
	{
		LogMessage("Failed to create call: CBasePlayer::RemoveWearable!");
	}
	
	// This call allows us to equip a wearable
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(iRemoveWearableOffset-1);//In theory the virtual function for EquipWearable is rigth before RemoveWearable, 
													//if it's always true (valve don't put a new function between these two), then we can use SM auto update offset for RemoveWearable and find EquipWearable from it
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if (g_hSDKEquipWearable == null)
	{
		LogMessage("Failed to create call: CBasePlayer::EquipWearable!");
	}

	delete hGameData;
}

int SDK_GetMaxHealth(int iClient)
{
	if (g_hSDKGetMaxHealth != INVALID_HANDLE) return SDKCall(g_hSDKGetMaxHealth, iClient);
	return 0;
}

void SDK_RemoveWearable(int client, int iWearable)
{
	if (g_hSDKRemoveWearable != null)
		SDKCall(g_hSDKRemoveWearable, client, iWearable);
}

int SDK_GetEquippedWearable(int client, int iSlot)
{
	if (g_hSDKGetEquippedWearable != null)
		return SDKCall(g_hSDKGetEquippedWearable, client, iSlot);
	return -1;
}

void SDK_EquipWearable(int client, int iWearable)
{
	if (g_hSDKEquipWearable != null)
		SDKCall(g_hSDKEquipWearable, client, iWearable);
}

stock void SetBackstabState(int iClient, float flDuration = BACKSTABDURATION_FULL, float flSlowdown = 0.5)
{
	if (IsValidLivingSurvivor(iClient))
	{
		int iSurvivors = GetSurvivorCount();
		int iZombies = GetZombieCount();

		// reduce backstab duration if:
		// 3 or less survivors are left while there are 12 or more zombies
		// there are 24 or more zombies
		// zombie damage scale is 50% or lower
		// victim has the defense buff
		if ( flDuration > BACKSTABDURATION_REDUCED && (
				( iSurvivors <= 3 && iZombies >= 12 )
				|| iZombies >= 24
				|| g_fZombieDamageScale <= 0.5
				|| TF2_IsPlayerInCondition(iClient, TFCond_DefenseBuffed) ) )
		{
			flDuration = BACKSTABDURATION_REDUCED;
		}

		g_bBackstabbed[iClient] = true;
		TF2_StunPlayer(iClient, flDuration, flSlowdown, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_SLOWDOWN, 0);

		// music and sound
		MusicHandleClient(iClient);
		SZF_EmitNearDeathToAll(iClient);
		ClientCommand(iClient, "voicemenu 2 0"); // "HEEEELP!"
		// show overlay
		ScreenOverlay(flDuration, "debug/yuv", iClient);
		// resets backstab state
		CreateTimer(flDuration, RemoveBackstab, iClient); 
	}
}

public Action RemoveBackstab(Handle hTimer, int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient)) return;
	g_bBackstabbed[iClient] = false;
}

void SetPickupWeapons()
{
	int iEntity = -1;
	// for rare weapons
	int iRare = 0;
	int iMaxRare = GetConVarInt(g_cvarMaxRareWeapons);
	// for spawn weapons
	int iSpawn = 0;
	int iMaxSpawn = max(GetConVarInt(g_cvarMinSpawnWeapons), RoundToFloor(GetSurvivorCount() / 2.5));
	bool inSpawn[sizeof(g_strSpawnModels)] = false;

	while ((iEntity = FindEntityByClassname2(iEntity, "prop_dynamic")) != -1)
	{
		// if weapon
		if (GetWeaponType(iEntity) > 0)
		{
			// robin hood means no weapons outside or inside
			if (IsMutationActive(MUTATION_ROBINHOOD))
			{
				AcceptEntityInput(iEntity, "Kill");
				continue;
			}


			// if a spawn weapon
			if (GetWeaponType(iEntity) == WEAPON_SPAWN)
			{
				// we have exceeded maximum spawn weapons allowed
				if (iSpawn >= iMaxSpawn) AcceptEntityInput(iEntity, "Kill");

				int iSpawnIndex = GetRandomInt(0, sizeof(g_strSpawnModels)-1);
				int iFail = 0;
				// no duplicate weapons allowed
				while (inSpawn[iSpawnIndex] && iFail < 100)
				{
					iSpawnIndex = GetRandomInt(0, sizeof(g_strSpawnModels)-1);
					iFail++;
				} if (iFail >= 100) AcceptEntityInput(iEntity, "Kill");

				SetEntityModel(iEntity, g_strSpawnModels[iSpawnIndex]);
				inSpawn[iSpawnIndex] = true;
				iSpawn++;
				
			}

			// rare weapon
			else if (GetWeaponType(iEntity) == WEAPON_RARE)
			{
				// if rare weapon cap is unreached, make it a "rare" weapon
				if (iRare < iMaxRare)
				{
					SetEntityModel(iEntity, g_strRareModels[GetRandomInt(0, sizeof(g_strRareModels)-1)]);
					iRare++;
				}

				// else make it a "out of spawn" weapon
				else
				{
					SetEntityModel(iEntity, g_strWeaponModels[GetRandomInt(0, sizeof(g_strWeaponModels)-1)]);
				}
			}

			// rare weapon that doesnt dissapear and is not affected by max rare cap
			else if (GetWeaponType(iEntity) == WEAPON_RARE_SPAWN)
			{
				SetEntityModel(iEntity, g_strRareModels[GetRandomInt(0, sizeof(g_strRareModels)-1)]);
			}

			// else if not a spawn weapon
			else if (GetWeaponType(iEntity) == WEAPON_DEFAULT || GetWeaponType(iEntity) == WEAPON_DEFAULT_NOPICKUP)
			{
				// if rare weapon cap is unreached and a dice roll is met, make it a "rare" weapon
				if (iRare < iMaxRare && !GetRandomInt(0, 5))
				{
					SetEntityModel(iEntity, g_strRareModels[GetRandomInt(0, sizeof(g_strRareModels)-1)]);
					iRare++;
				}

				// pick-ups
				else if (!GetRandomInt(0, 9) && GetWeaponType(iEntity) != WEAPON_DEFAULT_NOPICKUP)
				{
					MakeWeaponPickup(iEntity);
				}

				// else make it a "out of spawn" weapon
				else
				{
					SetEntityModel(iEntity, g_strWeaponModels[GetRandomInt(0, sizeof(g_strWeaponModels)-1)]);
				}
			}

			AcceptEntityInput(iEntity, "DisableShadow");
			AcceptEntityInput(iEntity, "EnableCollision");
			// SetEntProp(iTarget, Prop_Send, "m_nSolidType", SOLID_BBOX);
			SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 1); // Collides with nothing but world and static stuff

			// relocate weapon to higher height, looks much better
			float flPosition[3];
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flPosition);
			flPosition[2] += 0.8;
			TeleportEntity(iEntity, flPosition, NULL_VECTOR, NULL_VECTOR);

			g_bTriggerEntity[iEntity] = true; // indicate reset of the OnUser triggers
		}
	}
}

// Benoist3012 is the man :heart:
stock void Voodooify(int iClient)
{
	if (TF2_IsPlayerInCondition(iClient, TFCond_HalloweenGhostMode)) return;
	switch(TF2_GetPlayerClass(iClient))
	{
		case TFClass_Scout: TF2_CreateAndEquipFakeModel(iClient, iScoutZombieIndex);
		case TFClass_Soldier: TF2_CreateAndEquipFakeModel(iClient, iSoldierZombieIndex);
		case TFClass_Pyro: TF2_CreateAndEquipFakeModel(iClient, iPyroZombieIndex);
		case TFClass_DemoMan: TF2_CreateAndEquipFakeModel(iClient, iDemomanZombieIndex);
		case TFClass_Heavy: TF2_CreateAndEquipFakeModel(iClient, iHeavyZombieIndex);
		case TFClass_Medic: TF2_CreateAndEquipFakeModel(iClient, iMedicZombieIndex);
		case TFClass_Engineer: TF2_CreateAndEquipFakeModel(iClient, iEngineerZombieIndex);
		case TFClass_Sniper: TF2_CreateAndEquipFakeModel(iClient, iSniperZombieIndex);
		case TFClass_Spy: TF2_CreateAndEquipFakeModel(iClient, iSpyZombieIndex);
	}

	SetEntProp(iClient, Prop_Send, "m_bForcedSkin", true);
	SetEntProp(iClient, Prop_Send, "m_nForcedSkin", (isSpy(iClient)) ? SKIN_ZOMBIE_SPY : SKIN_ZOMBIE);
}

int TF2_CreateAndEquipWeapon(int iClient, int iItemDefinitionIndex, bool clearSlot = true)
{
	char sWeaponClassName[64];
	TF2Econ_GetItemClassName(iItemDefinitionIndex, sWeaponClassName, sizeof(sWeaponClassName));
	TF2Econ_TranslateWeaponEntForClass(sWeaponClassName, sizeof(sWeaponClassName), TF2_GetPlayerClass(iClient));
	
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION|PRESERVE_ATTRIBUTES);
	if (hWeapon == INVALID_HANDLE)
		return -1;
	
	TF2Items_SetItemIndex(hWeapon, iItemDefinitionIndex);
	TF2Items_SetLevel(hWeapon, GetRandomInt(0,100));
	TF2Items_SetQuality(hWeapon, 1);
	TF2Items_SetClassname(hWeapon, sWeaponClassName);
	TF2Items_SetNumAttributes(hWeapon, 0);

	int iWeapon = TF2Items_GiveNamedItem(iClient, hWeapon);
	delete hWeapon;
	
	if (clearSlot)
	{
		int iSlot = TF2Econ_GetItemSlot(iItemDefinitionIndex, TF2_GetPlayerClass(iClient));
		TF2_RemoveWeaponSlot(iClient, iSlot);

		int iWearable = SDK_GetEquippedWearable(iClient, iSlot);
		if (iWearable > MaxClients)
		{
			SDK_RemoveWearable(iClient, iWearable);
			AcceptEntityInput(iWearable, "Kill");
		}
	}
	
	if (strncmp(sWeaponClassName, "tf_wearable", 11) == 0)
		SDK_EquipWearable(iClient, iWeapon);
	else
	{
		int iAmmotype = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmotype != -1) GivePlayerAmmo(iClient, 500, iAmmotype);
		EquipPlayerWeapon(iClient, iWeapon);
	}
	
	SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
	return iWeapon;
}

int TF2_CreateAndEquipFakeModel(int iClient, int iModelAvoidCompilerTantrum)
{
	Handle hWearable = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);

	if (hWearable == INVALID_HANDLE)
	return -1;

	TF2Items_SetClassname(hWearable, "tf_wearable");
	TF2Items_SetItemIndex(hWearable, 5023);
	TF2Items_SetLevel(hWearable, 50);
	TF2Items_SetQuality(hWearable, 6);

	int iWearable = TF2Items_GiveNamedItem(iClient, hWearable);
	delete hWearable;
	if (IsValidEdict(iWearable))
	{
		SetEntProp(iWearable, Prop_Send, "m_bValidatedAttachedEntity", true);
		if (g_hSDKEquipWearable != INVALID_HANDLE)
		{
			SDKCall(g_hSDKEquipWearable, iClient, iWearable);
			SetEntProp(iWearable, Prop_Send, "m_bValidatedAttachedEntity", true);
			SetEntProp(iWearable, Prop_Send, "m_nModelIndexOverrides", iModelAvoidCompilerTantrum);
			return iWearable;
		}
	}

	return -1;
}
