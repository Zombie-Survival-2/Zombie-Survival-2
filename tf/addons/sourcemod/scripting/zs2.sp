/* Includes
==================================================================================================== */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf_econ_data>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#include <advanced_motd>
#include <json>
#include <morecolors>
#include <nativevotes>

#pragma newdecls required

/* Global variables and plugin information
==================================================================================================== */

// Defines
#define MESSAGE_PREFIX "{collectors}[ZS2]"
#define MESSAGE_PREFIX_NO_COLOR "[ZS2]"
#define PLUGIN_VERSION "0.1.2 Beta"
#define MOTD_VERSION "0.1"
#define IsValidClient(%1) (1 <= %1 <= MaxClients && IsClientInGame(%1))

// Plugin information
public Plugin myinfo = {
	name = "Zombie Survival 2",
	author = "Jack5 & yelks",
	description = "A zombie game mode featuring all-class action with multiple modes, inspired by the Left 4 Dead series.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Zombie-Survival-2"
};

enum
{
	TEAM_UNASSIGNED,
	TEAM_SPEC,
	TEAM_RED,
	TEAM_BLUE
};

enum RoundType
{
	Game_Attack,
	Game_Defend,
	Game_Survival
	// Game_Waves,
	// Game_Scavenge
};

bool setupTime;
bool roundStarted;
bool waitingForPlayers;
bool attackTeamSwap;
bool autoHandleDoors;
bool freezeInSetup;
bool selectedAsSurvivor[MAXPLAYERS+1];

int roundTimer;
int	TEAM_SURVIVORS;
int	TEAM_ZOMBIES;
int	objectiveBonus;
int	roundDuration;
int	roundDurationCP;
int	setupDuration;
int	queuePoints[MAXPLAYERS+1];
int	damageDealt[MAXPLAYERS+1];
int	g_LastButtons[MAXPLAYERS+1];
int	jumpCount[MAXPLAYERS+1];

char objectiveEntities[][] = { "team_control_point_master", "team_control_point", "trigger_capture_area", "item_teamflag", "func_capturezone", "mapobj_cart_dispenser"};
char roundTypeStrings[][] = { "Attack", "Defend", "Survival" /*"Waves", "Scavenge"*/};
char introCP[64];
char introST[64];	

ConVar smDebug;
ConVar smTeamRatio;
ConVar smTeamMax;
ConVar smPointsDamage;
ConVar smPointsTime;
ConVar smPointsWhilePlaying;
ConVar smPointsOnKill;
ConVar smPointsOnAssist;

Handle roundTimerHandle;

RoundType roundType;

ArrayList allowedRoundTypes;

// Method includes
#include "zs2/cp.sp"
#include "zs2/attack.sp"
#include "zs2/defend.sp"
#include "zs2/survival.sp"
#include "zs2/maps.sp"
#include "zs2/weapons.sp"

/* Plugin initialisation
==================================================================================================== */

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_TF2)
	{
		SetFailState("This game mode can only run on a Team Fortress 2 Dedicated Server.");
	}

	// Events
	HookEvent("building_healed", Event_OnHealBuilding);
	HookEvent("ctf_flag_captured", Event_OnCapture);
	HookEvent("player_dropobject", Event_DropObject);
	HookEvent("player_death", Event_OnDeath);
	HookEvent("player_spawn", Event_OnSpawn);
	HookEvent("post_inventory_application", Event_OnRegen);
	HookEvent("teamplay_broadcast_audio", Event_Audio, EventHookMode_Pre);
	HookEvent("teamplay_point_captured", Event_OnCapture);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("teamplay_setup_finished", Event_SetupFinished);

	// ConVars
	smDebug = CreateConVar("sm_zs2_debug", "1", "Disables or enables debug messages in chat.");
	smPointsDamage = CreateConVar("sm_zs2_points_damage", "200", "Minimum damage to earn queue points.", _, true, 0.0);
	smPointsOnAssist = CreateConVar("sm_zs2_points_onassist", "3", "X points when zombie assists.", _, true, 0.0);
	smPointsOnKill = CreateConVar("sm_zs2_points_onkill", "5", "X points when zombie kills.", _, true, 0.1);
	smPointsTime = CreateConVar("sm_zs2_points_time", "30", "Time interval for giving queue points.", _, true, 0.0);
	smPointsWhilePlaying = CreateConVar("sm_zs2_points_whileplaying", "5", "X points for playing on the server.", _, true, 0.0);
	smTeamMax = CreateConVar("sm_zs2_team_max", "6", "Maximum number of survivors allowed.", _, true, 0.0);
	smTeamRatio = CreateConVar("sm_zs2_team_ratio", "3", "Number of zombies per survivor.", _, true, 0.0, true, 1.0);

	// Commands
	RegConsoleCmd("sm_zs", Command_ZS2);
	RegConsoleCmd("sm_zs2", Command_ZS2);
	RegConsoleCmd("sm_zsnext", Command_Next);
	RegConsoleCmd("sm_zs_next", Command_Next);
	RegConsoleCmd("sm_zs2next", Command_Next);
	RegConsoleCmd("sm_zs2_next", Command_Next);
	RegConsoleCmd("sm_zsqueue", Command_Next);
	RegConsoleCmd("sm_zs_queue", Command_Next);
	RegConsoleCmd("sm_zs2queue", Command_Next);
	RegConsoleCmd("sm_zs2_queue", Command_Next);
	RegConsoleCmd("sm_zsreset", Command_Reset);
	RegConsoleCmd("sm_zs_reset", Command_Reset);
	RegConsoleCmd("sm_zs2reset", Command_Reset);
	RegConsoleCmd("sm_zs2_reset", Command_Reset);
	RegConsoleCmd("sm_zsclass", Command_Class);
	RegConsoleCmd("sm_zs_class", Command_Class);
	RegConsoleCmd("sm_zs2class", Command_Class);
	RegConsoleCmd("sm_zs2_class", Command_Class);
	RegAdminCmd("sm_zs_reloadconfig", AdminCommand_ReloadConfig, ADMFLAG_CONFIG);
	RegAdminCmd("sm_zsmaxpoints", AdminCommand_MaxPoints, ADMFLAG_ROOT);
	RegAdminCmd("sm_zs_maxpoints", AdminCommand_MaxPoints, ADMFLAG_ROOT);
	RegAdminCmd("sm_zs2maxpoints", AdminCommand_MaxPoints, ADMFLAG_ROOT);
	RegAdminCmd("sm_zs2_maxpoints", AdminCommand_MaxPoints, ADMFLAG_ROOT);

	// Listeners
	AddCommandListener(Listener_Build, "build");
	AddCommandListener(Listener_JoinClass, "joinclass");
	AddCommandListener(Listener_JoinTeam, "autoteam");
	AddCommandListener(Listener_JoinTeam, "jointeam");
	AddCommandListener(Listener_JoinTeam, "spectate");

	// Translations
	LoadTranslations("common.phrases");

	// Prepare weapons array list
	Weapons_Initialise();
}

/* Map initialisation + server tags
==================================================================================================== */

public void OnMapStart()
{
	roundStarted = false;
	waitingForPlayers = true;

	// Standard sounds precaching
	PrecacheSound("replay/replaydialog_warn.wav");
	
	// Custom sounds precaching and downloading
	PrecacheSound("zs2/death.mp3");
	AddFileToDownloadsTable("sound/zs2/death.mp3");
	PrecacheSound("zs2/defeat.mp3");
	AddFileToDownloadsTable("sound/zs2/defeat.mp3");
	PrecacheSound("zs2/oneleft.mp3");
	AddFileToDownloadsTable("sound/zs2/oneleft.mp3");
	PrecacheSound("zs2/victory.mp3");
	AddFileToDownloadsTable("sound/zs2/victory.mp3");
	PrecacheSound("zs2/intro_cp/bloodharvest.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_cp/bloodharvest.mp3");
	PrecacheSound("zs2/intro_cp/crashcourse.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_cp/crashcourse.mp3");
	PrecacheSound("zs2/intro_cp/deadair.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_cp/deadair.mp3");
	PrecacheSound("zs2/intro_cp/deathtoll.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_cp/deathtoll.mp3");
	PrecacheSound("zs2/intro_cp/nomercy.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_cp/nomercy.mp3");
	PrecacheSound("zs2/intro_st/bloodharvest.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_st/bloodharvest.mp3");
	PrecacheSound("zs2/intro_st/crashcourse.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_st/crashcourse.mp3");
	PrecacheSound("zs2/intro_st/darkcarnival.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_st/darkcarnival.mp3");
	PrecacheSound("zs2/intro_st/deadair.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_st/deadair.mp3");
	PrecacheSound("zs2/intro_st/deathtoll.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_st/deathtoll.mp3");
	PrecacheSound("zs2/intro_st/hardrain.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_st/hardrain.mp3");
	PrecacheSound("zs2/intro_st/nomercy.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_st/nomercy.mp3");
	PrecacheSound("zs2/intro_st/swampfever.mp3");
	AddFileToDownloadsTable("sound/zs2/intro_st/swampfever.mp3");
	
	TEAM_SURVIVORS = TEAM_RED;
	TEAM_ZOMBIES = TEAM_BLUE;
	delete roundTimerHandle;
	
	// Read weapons CFG file
	Weapons_Refresh();
	
	// Read JSON file and set related variables
	Maps_Initialise();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "tf_logic_koth") == 0 || strcmp(classname, "tf_logic_arena") == 0)
		AcceptEntityInput(entity, "KillHierarchy");
	else if (strcmp(classname, "team_round_timer") == 0 && !waitingForPlayers)
		AcceptEntityInput(entity, "Kill");
}

public void OnGameFrame() {
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_sentrygun")) != -1) {
		SetEntProp(entity, Prop_Send, "m_iUpgradeMetal", 0);
	}
	entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_dispenser")) != -1) {
		SetEntProp(entity, Prop_Send, "m_iUpgradeMetal", 0);
	}
}

public void OnConfigsExecuted()
{
	// Server tags
	InsertServerTag("zombies");
	InsertServerTag("zombie survival 2");
	InsertServerTag("zs2");

	// Cvars
	FindConVar("mp_idledealmethod").SetInt(2);
	FindConVar("mp_scrambleteams_auto").SetInt(0);
	FindConVar("mp_teams_unbalance_limit").SetInt(0);
	FindConVar("tf_avoidteammates_pushaway").SetInt(0);
	FindConVar("tf_bot_melee_only").SetInt(1);
	FindConVar("tf_ctf_bonus_time").SetInt(0);
	FindConVar("tf_flag_caps_per_round").SetInt(2);
	FindConVar("tf_forced_holiday").SetInt(2);
	FindConVar("tf_sentrygun_metal_per_shell").SetInt(201);
	FindConVar("tf_weapon_criticals").SetInt(0);
}

void InsertServerTag(const char[] tagToInsert)
{
	ConVar tags = FindConVar("sv_tags");
	if (tags != null)
	{
		char tagsText[256];
		// Insert server tag at end
		tags.GetString(tagsText, sizeof(tagsText));
		if (StrContains(tagsText, tagToInsert, true) == -1)
		{
			Format(tagsText, sizeof(tagsText), "%s,%s", tagsText, tagToInsert);
			tags.SetString(tagsText);
			// If failed, insert server tag at start
			tags.GetString(tagsText, sizeof(tagsText));
			if (StrContains(tagsText, tagToInsert, true) == -1)
			{
				Format(tagsText, sizeof(tagsText), "%s,%s", tagToInsert, tagsText);
				tags.SetString(tagsText);
			}
		}
	}
}

/* Client connection functions + server intro
==================================================================================================== */

public void OnClientPutInServer(int client)
{
	CreateTimer(15.0, Timer_DisplayIntro, client);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public void OnClientDisconnect(int client)
{
	queuePoints[client] = 0;
	damageDealt[client] = 0;
	selectedAsSurvivor[client] = false;
	
	if (GetClientCount() == 1) // GetClientCount is called before the player disconnects
	{
		DebugText("No players left, reverting to waiting for players mode");
		waitingForPlayers = true;
	}
}

Action Timer_DisplayIntro(Handle timer, int client)
{
	if (IsValidClient(client)) // Required because player might disconnect before this fires
	{
		CPrintToChat(client, "%s {haunted}This server is running {collectors}Zombie Survival 2 {normal}v%s!", MESSAGE_PREFIX, PLUGIN_VERSION);
		CPrintToChat(client, "{haunted}If you would like to know more, type the command {normal}!zs2 {haunted}into chat.");
	}
}

/* Round initialisation
==================================================================================================== */

public void TF2_OnWaitingForPlayersEnd()
{
	waitingForPlayers = false;
	
	// Playtime points timer
	CreateTimer(smPointsTime.FloatValue, Timer_PlaytimePoints, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (waitingForPlayers)
		return;
		
	// Dynamically call methods based on current mode
	switch (roundType)
	{
		case Game_Attack:
			Attack_RoundStart();
		case Game_Defend:
			Defend_RoundStart();
		case Game_Survival:
			Survival_RoundStart();
	}

	setupTime = true;
	roundTimer = setupDuration;
	delete roundTimerHandle;
	roundTimerHandle = CreateTimer(1.0, CountdownSetup, _, TIMER_REPEAT);

	// Determine required number of survivors
	int playerCount = GetClientCount(true);
	int teamRatio = smTeamRatio.IntValue;
	if (teamRatio > 32 || teamRatio < 1)
		teamRatio = 3;
	int teamMax = smTeamMax.IntValue;
	if (teamMax > 32 || teamMax < 1)
		teamMax = 6;

	// Set up required survivors, do not let it exceed the maximum value
	int teamRequired;
	if (playerCount <= teamRatio * teamMax - teamRatio)
		teamRequired = RoundToCeil(float(playerCount) / float(teamRatio));
	else
		teamRequired = teamMax;

	// Populate survivor team, will need to be fired for the zombie team during setup time if someone disconnects
	for (int i = 0; i < teamRequired; i++)
	{
		int player = GetClientWithMostQueuePoints(selectedAsSurvivor);
		if (!player)
		{
			break;
		}

		Survivor_Setup(player);
		CPrintToChat(player, "%s {haunted}You have been selected to become a {normal}Survivor. {haunted}Your queue points have been reset.", MESSAGE_PREFIX);
	}

	// Notify players of their selected team and alter their loadout and movement if necessary
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (!selectedAsSurvivor[i])
			{
				Zombie_Setup(i);
				CPrintToChat(i, "%s {haunted}You have been selected to become a {normal}Zombie.", MESSAGE_PREFIX);
			}
			if (GetClientTeam(i) == TEAM_BLUE && freezeInSetup)
				SetEntityMoveType(i, MOVETYPE_NONE);
			else
				SetEntityMoveType(i, MOVETYPE_WALK);
		}
	}
	
	switch (roundType)
	{
		case Game_Attack:
			Attack_RoundStartPost();
		case Game_Defend:
			Defend_RoundStartPost();
		case Game_Survival:
			Survival_RoundStartPost();
	}

	roundStarted = true;
}

void Event_SetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	DebugText("Setup time finished");
	setupTime = false;
	
	switch (roundType)
	{
		case Game_Attack:
			roundTimer = roundDurationCP;
		case Game_Defend:
			roundTimer = roundDurationCP;
		default:
			roundTimer = roundDuration;
	}
	
	delete roundTimerHandle;
	roundTimerHandle = CreateTimer(1.0, CountdownRound, _, TIMER_REPEAT);

	// Force resupply lockers to only work for zombies
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_regenerate")) != -1)
	{
		SetVariantInt(TEAM_ZOMBIES);
		AcceptEntityInput(ent, "SetTeam");
	}
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_respawnroomvisualizer")) != -1)
	{
		if (GetEntProp(ent, Prop_Send, "m_iTeamNum") == TEAM_SURVIVORS)
			AcceptEntityInput(ent, "Disable");
	}
	// Allow all players to move again
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			Command_Class(i, 0);
			SetEntityMoveType(i, MOVETYPE_WALK);
		}
	}
	
	// Check if there are no survivors
	if (GetTeamClientCount(TEAM_SURVIVORS) == 0)
		ForceWin(TEAM_ZOMBIES);
}

public Action CountdownSetup(Handle timer)
{
	roundTimer--;

	if (roundTimer < 0)
	{
		roundTimerHandle = null;
		
		if (!waitingForPlayers)
		{
			Event event = CreateEvent("teamplay_setup_finished");
			event.Fire();

			if (autoHandleDoors)
			{
				int ent = -1;
				while ((ent = FindEntityByClassname(ent, "func_door")) != -1)
				{
					AcceptEntityInput(ent, "Unlock");
					AcceptEntityInput(ent, "Open");
					AcceptEntityInput(ent, "Lock");
				}
				ent = -1;
				while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)
				{
					char tName[64];
					GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
					if (StrContains(tName, "door", false) != -1 || StrContains(tName, "gate", false) != -1)
					{
						SetVariantString("open");
						AcceptEntityInput(ent, "SetAnimation");
					}
				}
				ent = -1;
				while ((ent = FindEntityByClassname(ent, "trigger_multiple")) != -1)
				{
					AcceptEntityInput(ent, "Disable");
				}
			}
		}

		return Plugin_Stop;
	}

	SetHudTextParams(-1.0, 0.05, 1.1, 255, 255, 255, 255);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i))
			ShowHudText(i, -1, "Setup ends in %d:%02d", roundTimer / 60, roundTimer % 60);
	}

	return Plugin_Continue;
}

public Action CountdownRound(Handle timer)
{
	roundTimer--;

	if (roundTimer < 0)
	{
		roundTimerHandle = null;
		
		if (!waitingForPlayers)
		{
			switch (roundType)
			{
				case Game_Attack:
					ForceWin(TEAM_ZOMBIES);
				case Game_Defend:
					ForceWin(TEAM_SURVIVORS);
				case Game_Survival:
					ForceWin(TEAM_SURVIVORS);
			}
		}
		return Plugin_Stop;
	}

	SetHudTextParams(-1.0, 0.05, 1.1, 255, 255, 255, 255);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i))
			ShowHudText(i, -1, "%d:%02d remaining", roundTimer / 60, roundTimer % 60);
	}

	return Plugin_Continue;
}

void Event_OnCapture(Event event, const char[] name, bool dontBroadcast)
{
	DebugText("An objective has been captured");
	roundTimer += objectiveBonus;
}

void VoteRoundType()
{
	// If no or only one round type is available, force the default
	if (allowedRoundTypes.Length <= 1)
	{
		SetDefaultRoundType();
	}
	// Use a vote if there are more round types to choose from
	else
	{
		NativeVote vote = new NativeVote(GameVote, NativeVotesType_Custom_Mult);
		vote.Initiator = NATIVEVOTES_SERVER_INDEX;
		vote.SetDetails("Select next round type:");
		char votePosition[2];
		char strval[32];
		for (int i = 0; i < allowedRoundTypes.Length; i++) // This portion of the code is currently broken
		{
			IntToString(i, votePosition, sizeof(votePosition));
			allowedRoundTypes.GetString(i, strval, sizeof(strval));
			DebugText("Adding item %s to position %s", strval, votePosition);
			vote.AddItem(votePosition, strval);
		}
		vote.DisplayVoteToAll(13);
	}
}

void SetDefaultRoundType()
{
	DebugText("Forcing round type without vote");
	if (allowedRoundTypes.Length >= 1)
	{
		char strval[32];
		allowedRoundTypes.GetString(0, strval, sizeof(strval));
		if (StrEqual(strval, "Attack"))
			roundType = Game_Attack;
		else if (StrEqual(strval, "Defend"))
			roundType = Game_Defend;
		else
			roundType = Game_Survival;
	}
	else
		roundType = Game_Survival;
}

// https://forums.alliedmods.net/showpost.php?p=2694813&postcount=260
// https://forums.alliedmods.net/showpost.php?p=2669519&postcount=257
public int GameVote(NativeVote vote, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			vote.Close();
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				vote.DisplayFail(NativeVotesFail_Generic);
			}
		}
		case MenuAction_VoteEnd:
		{
			char votePosition[2];
			vote.GetItem(param1, votePosition, sizeof(votePosition));
			int i = StringToInt(votePosition);
			int votes, totalVotes;
			NativeVotes_GetInfo(param2, votes, totalVotes);
			char strval[32];
			allowedRoundTypes.GetString(i, strval, sizeof(strval));
			vote.DisplayPassCustom("Round type set to %s", strval);
			CPrintToChatAll("%s {haunted}The next round type will be {normal}%s {haunted}(%d/%d).", MESSAGE_PREFIX, strval, votes, totalVotes);

			for (int j = 0; j < sizeof(roundTypeStrings); j++)
			{
				if (StrEqual(roundTypeStrings[j], strval))
				{
					roundType = view_as<RoundType>(j);
					break;
				}
			}
		}
	}
}

/* Round end + audio blocking
==================================================================================================== */

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	delete roundTimerHandle;
	CreateTimer(3.0, Timer_CalcQueuePoints, _, TIMER_FLAG_NO_MAPCHANGE);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			selectedAsSurvivor[i] = false;
			damageDealt[i] = 0;

			if (event.GetInt("team") == GetClientTeam(i))
				EmitSoundToClient(i, "zs2/victory.mp3", i);
			else
				EmitSoundToClient(i, "zs2/defeat.mp3", i);
		}
	}

	roundStarted = false;
	
	VoteRoundType();
}

Action Event_Audio(Event event, const char[] name, bool dontBroadcast)
{
	char audioRawName[40];
	GetEventString(event, "sound", audioRawName, sizeof(audioRawName));
	
	// Block victory and loss sounds
	if (strncmp(audioRawName, "Game.Your", 9) == 0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

/* Client actions
==================================================================================================== */

Action Listener_JoinTeam(int client, const char[] command, int args)
{
	char sArg[32], survTeam[16], zombTeam[16], vgui[16];
	
	// Do not permit empty jointeam command
	if (!args && StrEqual(command, "jointeam", false))
		return Plugin_Handled;
	
	// Do not proceed with restrictions if waiting for players
	if (waitingForPlayers)
		return Plugin_Continue;
	
	// Allow all commands for invalid clients
	if (!IsValidClient(client))
		return Plugin_Continue;

	if (setupTime)
	{
		CPrintToChat(client, "%s {haunted}No team switch during setup time.", MESSAGE_PREFIX);
		return Plugin_Handled;
	}
	
	// Get command/arg on which team player joined
	if (StrEqual(command, "jointeam", false)) // "jointeam spectate" takes priority
		GetCmdArg(1, sArg, sizeof(sArg));
	else if (StrEqual(command, "spectate", false))
		strcopy(sArg, sizeof(sArg), "spectate");	
	else if (StrEqual(command, "autoteam", false))
		strcopy(sArg, sizeof(sArg), "autoteam");		
	
	// Assign team-specific strings
	if (TEAM_ZOMBIES == TEAM_BLUE)
	{
		survTeam = "red";
		zombTeam = "blue";
		vgui = "class_blue";
	}
	else
	{
		survTeam = "blue";
		zombTeam = "red";
		vgui = "class_red";
	}
	
	if (roundStarted)
	{
		// If client tries to join survivor team or random team, place them on zombie team with zombie class select
		if (StrEqual(sArg, survTeam, false) || StrEqual(sArg, "auto", false))
		{
			ChangeClientTeam(client, TEAM_ZOMBIES);
			ShowVGUIPanel(client, vgui);
			CPrintToChat(client, "%s {haunted}You cannot be survivor, forced to join zombie team.", MESSAGE_PREFIX);
			return Plugin_Handled;
		}
		// Let anyone join zombie team
		else if (StrEqual(sArg, zombTeam, false))
		{
			return Plugin_Continue;
		}
		// If client tries to join spectator, check their privileges
		else if (StrEqual(sArg, "spectate", false))
		{
			if (!CheckCommandAccess(client, "", ADMFLAG_KICK, true))
				return Plugin_Handled;
			
			return Plugin_Continue;
		}
		else
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

Action Listener_JoinClass(int client, const char[] command, int args)
{
	if (!args)
		return Plugin_Continue;

	char chosenClass[32];
	GetCmdArg(1, chosenClass, sizeof(chosenClass));

	if (!waitingForPlayers && GetClientTeam(client) == TEAM_SURVIVORS)
	{
		if (!setupTime && IsPlayerAlive(client))
			return Plugin_Handled;

		// Allow survivor to switch to their own class but not to one occupied by someone else
		if (TF2_GetPlayerClass(client) == TF2_GetClass(chosenClass))
			return Plugin_Continue;
		else if (!IsAllowedClass(client, TF2_GetClass(chosenClass)))
		{
			CPrintToChat(client, "%s {haunted}You cannot be a class that someone else on the survivor team already is.", MESSAGE_PREFIX);
			EmitSoundToClient(client, "replay/replaydialog_warn.wav", client);
			return Plugin_Handled;
		}
	}

	FakeClientCommand(client, "sm_zsclass %s", chosenClass);
	return Plugin_Continue;
}

Action Listener_Build(int client, const char[] command, int args)
{
	char chosenBuilding[2];
	GetCmdArg(1, chosenBuilding, sizeof(chosenBuilding));

	// Block everything except teleporters
	if (client && GetClientTeam(client) == TEAM_ZOMBIES && strcmp(chosenBuilding, "1") != 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!waitingForPlayers)
	{
		if (victim < 1 || attacker < 1 || !IsValidClient(attacker) || !IsValidClient(victim) || victim == attacker)
			return Plugin_Continue;

		damageDealt[attacker] += view_as<int>(damage);
	}
	return Plugin_Continue;
}

Action OnWeaponSwitch(int client, int weapon) // TODO: Use build and destroy events instead of weapon switch detection
{
	if (!IsValidClient(client) || GetClientTeam(client) == TEAM_ZOMBIES || TF2_GetPlayerClass(client) != TFClass_Engineer || !IsValidEntity(weapon))
	{
		return Plugin_Continue;
	}

	if (GetPlayerWeaponSlot(client, 3) == weapon)
	{
		int ent = -1, dispenserCount = 0;
		while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
		{
			if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") != client)
				continue;

			dispenserCount++;
			SetEntProp(ent, Prop_Send, "m_iObjectType", TFObject_Sapper);
			if (dispenserCount >= 2)
			{
				// Do not allow building if the limit is reached
				SetEntProp(ent, Prop_Send, "m_iObjectType", TFObject_Dispenser);
			}
		}
	}
	else if (GetPlayerWeaponSlot(client, 4) == weapon)
	{
		int ent = -1;
		while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
		{
			if (GetEntPropEnt(ent, Prop_Send, "m_hBuilder") != client)
				continue;

			SetEntProp(ent, Prop_Send, "m_iObjectType", TFObject_Dispenser);
		}
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		if ((buttons & IN_JUMP) && !(g_LastButtons[client] & IN_JUMP) && !(GetEntityFlags(client) & FL_ONGROUND) && jumpCount[client] < 1)
		{
			DoClientDoubleJump(client);
		}
		else if(GetEntityFlags(client) & FL_ONGROUND)
		{
			jumpCount[client] = 0;
		}
	}

	g_LastButtons[client] = buttons;
	return Plugin_Continue;
}

void DoClientDoubleJump(int client)
{
	jumpCount[client]++;
	float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	vVel[2] = 280.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
}

/* Client events
==================================================================================================== */

Action Event_OnSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	if (!player)
		return;
		
	// Apply slow move speed attributes to Scouts
	if (TF2_GetPlayerClass(player) == TFClass_Scout)
	{
		TF2Attrib_SetByName(player, "major move speed bonus", 0.8);
		TF2_AddCondition(player, TFCond_SpeedBuffAlly, 0.001);
	}

	int team = GetClientTeam(player);
	
	if (team == TEAM_BLUE && setupTime)
	{
		if (freezeInSetup)
			SetEntityMoveType(player, MOVETYPE_NONE);
		else
			SetEntityMoveType(player, MOVETYPE_WALK);
	}
}

Action Event_OnRegen(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	if (GetClientTeam(player) <= TEAM_SPEC)
		return;

	if (GetClientTeam(player) == TEAM_SURVIVORS && !IsAllowedClass(player, TF2_GetPlayerClass(player)))
	{
		PickClass(player);
		return;
	}

	WeaponCheck(player);
}

Action Event_OnDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int team = GetClientTeam(victim);

	if (!waitingForPlayers && !setupTime) // It's mid-round
	{
		if (team == TEAM_SURVIVORS && roundStarted) // A survivor died
		{
			EmitSoundToClient(victim, "zs2/death.mp3", victim);

			int survivorsLiving = -1, survAlive;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
				{
					survivorsLiving++;
					survAlive = i;
				}
			}

			if (survivorsLiving >= 1)
			{
				RequestFrame(Zombie_Setup, victim);
				if (survivorsLiving == 1)
				{
					EmitSoundToAll("zs2/oneleft.mp3", survAlive);
				}
			}
			else
			{
				ForceWin(TEAM_ZOMBIES);
			}
		}

		if (attacker < 1 || !IsValidClient(attacker) || victim == attacker)
			return;

		// This part deals with attacker and victim

		if (team == TEAM_SURVIVORS)
		{
			queuePoints[attacker] += smPointsOnKill.IntValue;

			if (assister && IsValidClient(assister))
				queuePoints[assister] += smPointsOnAssist.IntValue;
		}
	}
	else if (setupTime)
	{
		if (team == TEAM_SURVIVORS)
			RequestFrame(Survivor_Setup, victim);
		else if (team == TEAM_ZOMBIES)
			RequestFrame(Zombie_Setup, victim);
	}
}

Action Event_DropObject(Event event, const char[] name, bool dontBroadcast)
{
	int ent = event.GetInt("index");
	TFObjectType objectType = view_as<TFObjectType>(event.GetInt("object"));

	if (objectType == TFObject_Sapper)
	{
		SetEntProp(ent, Prop_Send, "m_bCarried", 1);
		SetEntProp(ent, Prop_Send, "m_iUpgradeMetalRequired", 200);
		SetEntProp(ent, Prop_Send, "m_iObjectType", TFObject_Dispenser);
	}
}

Action Event_OnHealBuilding(Event event, const char[] name, bool dontBroadcast)
{
	int healer = GetEventInt(event, "healer");
	if (IsValidClient(healer) && GetClientTeam(healer) == TEAM_SURVIVORS && GetEventInt(event, "building") == view_as<int>(TFObject_Sentry))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

/* Survivor setup
==================================================================================================== */

void Survivor_Setup(const int client)
{
	ChangeClientTeam(client, TEAM_SURVIVORS);
	queuePoints[client] = 0;
	TF2_RespawnPlayer(client);
	TF2_RegeneratePlayer(client);
}

/* Zombie setup
==================================================================================================== */

void Zombie_Setup(const int client)
{
	ChangeClientTeam(client, TEAM_ZOMBIES);
	TF2_RespawnPlayer(client);
}

/* Commands
==================================================================================================== */

public Action Command_ZS2(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("%s This command cannot be executed by the server console.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}
	char url[200];
	FormatEx(url, sizeof(url), "https://zombie-survival-2.github.io/%s", MOTD_VERSION);
	AdvMOTD_ShowMOTDPanel(client, "", url, MOTDPANEL_TYPE_URL, true, true, true, INVALID_FUNCTION);
	CPrintToChat(client, "%s {haunted}Opening Zombie Survival 2 manual... If nothing happens, open your developer console and {normal}set cl_disablehtmlmotd to 0{haunted}, then try again.", MESSAGE_PREFIX);
	return Plugin_Handled;
}

public Action Command_Next(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("%s This command cannot be executed by the server console.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}
	
	bool[] checked = new bool[MaxClients + 1];
	int[] players = new int[MaxClients + 1];

	int j = 0;
	for ( ; j < MaxClients + 1; j++)
	{
		players[j] = GetClientWithMostQueuePoints(checked);

		if (!players[j])
			break;
	}

	Menu menu = new Menu(Handler_Nothing);
	menu.SetTitle("%s Queue Points", MESSAGE_PREFIX_NO_COLOR);
	char display[64];

	for (int i = 0; i < j; i++)
	{
		FormatEx(display, sizeof(display), "%N - %i points", players[i], queuePoints[players[i]]);
		menu.AddItem("x", display, players[i] == client ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	menu.Display(client, 30);
	return Plugin_Handled;
}

public Action Command_Reset(int client, int args)
{
	if (client == 0)
	{
		if (smDebug.BoolValue)
		{
			for (int i = 0; i < MaxClients; i++)
				queuePoints[i] = 0;
		}
		else
			PrintToServer("%s This command is too destructive to be run outside of debug mode.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}
	queuePoints[client] = 0;
	CPrintToChat(client, "%s {haunted}Your queue points were reset to 0.", MESSAGE_PREFIX);
	return Plugin_Handled;
}

public Action Command_Class(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("%s This command cannot be executed by the server console.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}

	TFClassType class;
	if(!args)
	{
	if (!args)
		class = TF2_GetPlayerClass(client);
	else
	{
		char arg[32];
		GetCmdArg(1, arg, sizeof(arg));
		if (StrEqual(arg, "heavy"))
			arg = "heavyweapons";
		class = TF2_GetClass(arg);
	}
	
	int team = GetClientTeam(client);
	bool displayMenu = true;
	Panel menu2 = new Panel();
	char title[32];
	if (team == TEAM_SURVIVORS)
	{
		if (class == TFClass_Soldier)
		{
			Format(title, sizeof(title), "%s Soldier (Survivor)", MESSAGE_PREFIX_NO_COLOR);
			menu2.SetTitle(title);
			menu2.DrawText("- Rocket Jumper replaced with Rocket Launcher.");
		}
		else if (class == TFClass_Pyro)
		{
			Format(title, sizeof(title), "%s Pyro (Survivor)", MESSAGE_PREFIX_NO_COLOR);
			menu2.SetTitle(title);
			menu2.DrawText("- All flamethrowers have 50% less ammo.");
		}
		else if (class == TFClass_DemoMan)
		{
			Format(title, sizeof(title), "%s Demoman (Survivor)", MESSAGE_PREFIX_NO_COLOR);
			menu2.SetTitle(title);
			menu2.DrawText("- Sticky Jumper replaced with Stickybomb Launcher.");
		}
		else if (class == TFClass_Heavy)
		{
			Format(title, sizeof(title), "%s Heavy (Survivor)", MESSAGE_PREFIX_NO_COLOR);
			menu2.SetTitle(title);
			menu2.DrawText("- All miniguns have 50% less ammo.");
		}
		else if (class == TFClass_Engineer)
		{
			Format(title, sizeof(title), "%s Engineer (Survivor)", MESSAGE_PREFIX_NO_COLOR);
			menu2.SetTitle(title);
			menu2.DrawText("- Cannot upgrade Sentries or Dispensers.");
			menu2.DrawText("- Can build 2 Dispensers at once.");
		}
		else if (class == TFClass_Medic)
		{
			Format(title, sizeof(title), "%s Medic (Survivor)", MESSAGE_PREFIX_NO_COLOR);
			menu2.SetTitle(title);
			menu2.DrawText("- Vaccinator behaves identically to Quick-Fix.");
		}
		else
			displayMenu = false;
	}
	else if (team == TEAM_ZOMBIES)
	{
		if (class == TFClass_Engineer)
		{
			Format(title, sizeof(title), "%s Engineer (Zombie)", MESSAGE_PREFIX_NO_COLOR);
			menu2.SetTitle(title);
			menu2.DrawText("- Can only build Teleporters.");
		}
		else if (class == TFClass_Medic)
		{
			Format(title, sizeof(title), "%s Medic (Zombie)", MESSAGE_PREFIX_NO_COLOR);
			menu2.SetTitle(title);
			menu2.DrawText("- Can perform a redirectless double jump.");
		}
		else if (class == TFClass_Spy)
		{
			Format(title, sizeof(title), "%s Spy (Zombie)", MESSAGE_PREFIX_NO_COLOR);
			menu2.SetTitle(title);
			menu2.DrawText("- Cannot use any sappers.");
		}
		else
			displayMenu = false;
	}
	if (displayMenu)
	{
		menu2.DrawItem("Exit", ITEMDRAW_CONTROL);
		menu2.Send(client, Handler_Nothing, 10);
	}
	return Plugin_Handled;
}

public Action AdminCommand_MaxPoints(int client, int args)
{
	if (smDebug.BoolValue)
		queuePoints[client] = 999;
	return Plugin_Handled;
}

public Action AdminCommand_ReloadConfig(int client, int args)
{
	Weapons_Refresh();
	return Plugin_Handled;
}

public int Handler_Nothing(Menu menu, MenuAction action, int client, int param2) { }

/* Timers
==================================================================================================== */

Action Timer_CalcQueuePoints(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && damageDealt[i] >= smPointsDamage.IntValue)
		{
			queuePoints[i] += 10;
		}
	}
}

Action Timer_PlaytimePoints(Handle timer)
{
	if (roundStarted)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GetClientTeam(i) == TEAM_ZOMBIES)
			{
				queuePoints[i] += smPointsWhilePlaying.IntValue;
				CPrintToChat(i, "%s {haunted}You have earned %i queue points for playing as a zombie.", MESSAGE_PREFIX, smPointsWhilePlaying.IntValue);
			}
		}
	}
	return Plugin_Continue;
}

/* Queue points checking
==================================================================================================== */

int GetClientWithMostQueuePoints(bool[] myArray, bool mark = true)
{
	int chosen = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && queuePoints[i] >= queuePoints[chosen] && !myArray[i])
			chosen = i;
	}

	if (chosen && mark)
		myArray[chosen] = true;

	return chosen;
}

/* Custom Functions
==================================================================================================== */

bool IsAllowedClass(const int client, const TFClassType class)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == TEAM_SURVIVORS && TF2_GetPlayerClass(i) == class && i != client)
			return false;
	}

	return true;
}

void PickClass(const int client)
{
	TF2_SetPlayerClass(client, view_as<TFClassType>(GetRandomInt(1, 9)));
	TF2_RespawnPlayer(client);
}

void ForceWin(int team)
{
	int ent = FindEntityByClassname(-1, "game_round_win");
	if (ent < 1)
	{
		ent = CreateEntityByName("game_round_win");
		if (!IsValidEntity(ent))
		{
			PrintToServer("%s Plugin was not able to force a team to win.", MESSAGE_PREFIX_NO_COLOR);
			return;
		}
	}
	DispatchKeyValue(ent, "force_map_reset", "1");
	DispatchSpawn(ent);
	SetVariantInt(team);
	AcceptEntityInput(ent, "SetTeam");
	AcceptEntityInput(ent, "RoundWin");
}

/* Debug output
==================================================================================================== */

public void DebugText(const char[] text, any ...) {
	if (smDebug.BoolValue) {
		int len = strlen(text) + 255;
		char[] format = new char[len];
		VFormat(format, len, text, 2);
		CPrintToChatAll("{collectors}[ZS2 Debug] {white}%s", format);
		PrintToServer("[ZS2 Debug] %s", format);
	}
}
