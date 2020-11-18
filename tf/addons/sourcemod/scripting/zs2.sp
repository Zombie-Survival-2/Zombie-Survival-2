/* Includes
==================================================================================================== */

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
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
#define PLUGIN_VERSION "0.1"
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

// Standard variables
bool setupTime,
	roundStarted,
	waitingForPlayers,
	firstConnection[MAXPLAYERS+1] = {true, ...},
	selectedAsSurvivor[MAXPLAYERS+1];
int roundTimer,
	TEAM_SURVIVORS = 2,
	TEAM_ZOMBIES = 3,
	queuePoints[MAXPLAYERS+1],
	damageDealt[MAXPLAYERS+1];
public const char objectiveEntities[6][32] = {
	"team_control_point_master",
	"team_control_point",
	"trigger_capture_area",
	"item_teamflag",
	"func_capturezone",
	"mapobj_cart_dispenser"
};
Handle roundTimerHandle;

// Round type variables
enum RoundType
{
	// Game_Attack,
	Game_Defend,
	Game_Survival
	// Game_Waves,
	// Game_Scavenge
};
public const char roundTypeStrings[2][] = {
	// "Attack",
	"Defend",
	"Survival"
	// "Waves",
	// "Scavenge"
};
RoundType roundType;

// JSON-controlled variables
bool freezeInSetup;
int roundDuration,
	setupDuration;
char introCP[64],
	introST[64];
ArrayList allowedRoundTypes;

// ConVars
ConVar smDebug,
	smTeamRatio,
	smTeamMax,
	smPointsDamage,
	smPointsTime,
	smPointsWhilePlaying,
	smPointsOnKill,
	smPointsOnAssist;

// Method includes
#include "zs2/defend.sp"
#include "zs2/survival.sp"

/* Plugin initialisation
==================================================================================================== */

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_TF2)
	{
		SetFailState("This game mode can only run on a Team Fortress 2 Dedicated Server.");
	}

	// Events
	HookEvent("player_death", Event_OnDeath);
	HookEvent("player_spawn", Event_OnSpawn);
	HookEvent("post_inventory_application", Event_PlayerRegen);
	HookEvent("teamplay_broadcast_audio", Event_Audio, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("teamplay_setup_finished", Event_SetupFinished);

	// ConVars
	smDebug = CreateConVar("sm_zs2_debug", "0", "Disables or enables debug messages in chat.");
	smPointsDamage = CreateConVar("sm_zs2_points_damage", "200", "Minimum damage to earn queue points.", _, true, 0.0);
	smPointsOnAssist = CreateConVar("sm_zs2_points_onassist", "3", "X points when zombie assists.", _, true, 0.0);
	smPointsOnKill = CreateConVar("sm_zs2_points_onkill", "5", "X points when zombie kills.", _, true, 0.1);
	smPointsTime = CreateConVar("sm_zs2_points_time", "30.0", "Time interval for giving queue points.", _, true, 0.0);
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
	RegConsoleCmd("sm_zsreset", Command_Reset);
	RegConsoleCmd("sm_zs_reset", Command_Reset);
	RegConsoleCmd("sm_zs2reset", Command_Reset);
	RegConsoleCmd("sm_zs2_reset", Command_Reset);
	RegConsoleCmd("sm_zsqueue", Command_Next);
	RegConsoleCmd("sm_zs_queue", Command_Next);
	RegConsoleCmd("sm_zs2queue", Command_Next);
	RegConsoleCmd("sm_zs2_queue", Command_Next);

	// Listeners
	AddCommandListener(Listener_Build, "build");
	AddCommandListener(Listener_JoinClass, "joinclass");
	AddCommandListener(Listener_JoinTeam, "jointeam");

	// Translations
	LoadTranslations("common.phrases");
}

/* Map initialisation + server tags
==================================================================================================== */

public void OnMapStart()
{
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
	
	// Read JSON file and set related variables
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	char mapScriptPath[128];
	Format(mapScriptPath, sizeof(mapScriptPath), "scripts/zs2/%s.json", mapName);
	allowedRoundTypes = new ArrayList(16, 2); // Increase with each added round type
	if (FileExists(mapScriptPath))
	{
		DebugText("JSON file found");
		char mapScriptText[1024];
		File mapScriptFile = OpenFile(mapScriptPath, "r");
		mapScriptFile.ReadString(mapScriptText, sizeof(mapScriptText));
		mapScriptFile.Close();
		JSON_Object mapScript = json_decode(mapScriptText);
		freezeInSetup = !mapScript.GetBool("donotfreeze"); // Reversed because default is false
		int intval = mapScript.GetInt("t_round");
		if (intval > 0)
			roundDuration = intval;
		else
		{
			DebugText("Round time out of bounds or not found, using default");
			roundDuration = 300;
		}
		intval = mapScript.GetInt("t_setup");
		if (intval > 0)
			setupDuration = intval;
		else
		{
			DebugText("Setup time out of bounds or not found, using default");
			setupDuration = 30;
		}
		if (!mapScript.GetString("cp_intro", introCP, sizeof(introCP)))
		{
			DebugText("No definition for CP intro music found, disabled");
			introCP = "";
		}
		if (!mapScript.GetString("st_intro", introST, sizeof(introST)))
		{
			DebugText("No definition for ST intro music found, disabled");
			introST = "";
		}
		if (mapScript.GetBool("cp_d"))
			allowedRoundTypes.PushString("Defend");
		if (mapScript.GetBool("st_s"))
		{
			allowedRoundTypes.PushString("Survival");
			roundType = Game_Survival;
		}
		else
			SetDefaultRoundType();
		json_cleanup_and_delete(mapScript);
	}
	else
	{
		DebugText("JSON file not found, using defaults");
		freezeInSetup = true;
		roundDuration = 300;
		setupDuration = 30;
		introCP = "";
		introST = "";
		for (int i = 0; i < sizeof(roundTypeStrings); i++)
			allowedRoundTypes.PushString(roundTypeStrings[i]);
		roundType = Game_Survival;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "tf_logic_koth") == 0 || strcmp(classname, "tf_logic_arena") == 0)
		AcceptEntityInput(entity, "KillHierarchy");
	else if (strcmp(classname, "team_round_timer") == 0 && !waitingForPlayers)
		AcceptEntityInput(entity, "Kill");
}

public void OnConfigsExecuted()
{
	// Server tags
	InsertServerTag("zombies");
	InsertServerTag("zombie survival 2");
	InsertServerTag("zs2");

	// Cvars
	FindConVar("mp_scrambleteams_auto").SetInt(0);
	FindConVar("tf_ctf_bonus_time").SetInt(0);
	FindConVar("tf_flag_caps_per_round").SetInt(2);
	FindConVar("tf_weapon_criticals").SetInt(0);

	// Timers
	CreateTimer(smPointsTime.FloatValue, Timer_PlaytimePoints, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
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
	firstConnection[client] = true;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	queuePoints[client] = 0;
	damageDealt[client] = 0;
	selectedAsSurvivor[client] = false;
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

public void TF2_OnWaitingForPlayersStart()
{
	waitingForPlayers = true;
}

public void TF2_OnWaitingForPlayersEnd()
{
	waitingForPlayers = false;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (waitingForPlayers)
		return;

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
			DebugText("Player %i does not exist and cannot be placed on the survivor team", player);
			break;
		}

		DebugText("Placing player %i on the survivor team", player);
		Survivor_Setup(player);
		CPrintToChat(player, "%s {haunted}You have been selected to become a {normal}Survivor.", MESSAGE_PREFIX);
	}

	// Notify players of their selected team and alter their loadout and movement if necessary
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !selectedAsSurvivor[i])
		{
			Zombie_Setup(i);
			if (freezeInSetup)
				SetEntityMoveType(i, MOVETYPE_NONE);
			else
				SetEntityMoveType(i, MOVETYPE_WALK);
			CPrintToChat(i, "%s {haunted}You have been selected to become a {normal}Zombie.", MESSAGE_PREFIX);
		}
	}

	// Dynamically call methods based on current mode
	switch (roundType)
	{
		case Game_Defend:
			Defend_RoundStart();
		case Game_Survival:
			Survival_RoundStart();
	}

	roundStarted = true;
}

void Event_SetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	DebugText("Setup time finished");
	setupTime = false;
	roundTimer = roundDuration;
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
			SetEntityMoveType(i, MOVETYPE_WALK);
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
		Event event = CreateEvent("teamplay_setup_finished");
		event.Fire();

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
		switch (roundType)
		{
			case Game_Defend, Game_Survival:
				ForceWin(TEAM_SURVIVORS);
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
		for (int i = 0; i < 2; i++)
		{
			IntToString(i, votePosition, sizeof(votePosition));
			vote.AddItem(votePosition, roundTypeStrings[i]);
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
		if (StrEqual(strval, "Defend"))
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
				DebugText("Not enough votes for next round type");
				vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				DebugText("Next round type vote cancelled");
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
			vote.DisplayPassCustom("Round type set to %s", roundTypeStrings[i], votes, totalVotes);
			CPrintToChatAll("%s {haunted}The next round type will be {normal}%s {haunted}(%d/%d).", MESSAGE_PREFIX, roundTypeStrings[i], votes, totalVotes);
			roundType = view_as<RoundType>(i);
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
	char chosenTeam[8];
	GetCmdArg(1, chosenTeam, sizeof(chosenTeam));

	if (CheckCommandAccess(client, "", ADMFLAG_KICK) && StrContains(chosenTeam, "red", false) == -1)
		return Plugin_Continue;

	if (StrContains(chosenTeam, "spec", false) > -1)
	{
		EmitSoundToClient(client, "replay/replaydialog_warn.wav", client);
		return Plugin_Handled;
	}

	if (firstConnection[client])
	{
		CreateTimer(3.0, Timer_DisplayIntro, client);
		firstConnection[client] = false;
		return Plugin_Continue;
	}

	EmitSoundToClient(client, "replay/replaydialog_warn.wav", client);
	return Plugin_Handled;
}

Action Listener_JoinClass(int client, const char[] command, int args)
{
	if (!waitingForPlayers)
	{
		char chosenClass[16];
		GetCmdArg(1, chosenClass, sizeof(chosenClass));

		if (GetClientTeam(client) == TEAM_SURVIVORS && !IsAllowedClass(TF2_GetClass(chosenClass)))
		{
			EmitSoundToClient(client, "replay/replaydialog_warn.wav", client);
			return Plugin_Handled;
		}
	}

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

/* Client events
==================================================================================================== */

Action Event_OnSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	if (!player)
		return Plugin_Continue;

	if (GetClientTeam(player) == TEAM_ZOMBIES)
	{		
		RequestFrame(OnlyMelee, player);
		RequestFrame(RemoveWearable, player);
	}

	return Plugin_Continue;
}

Action Event_PlayerRegen(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	if (!player)
		return Plugin_Continue;

	if (GetClientTeam(player) == TEAM_ZOMBIES)
	{
		OnlyMelee(player);
		RemoveWearable(player);
		if (setupTime)
		{
			if (freezeInSetup)
				SetEntityMoveType(player, MOVETYPE_NONE);
			else
				SetEntityMoveType(player, MOVETYPE_WALK);
		}
	}

	return Plugin_Continue;
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

			int survivorsLiving = -1;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
					survivorsLiving++;
			}

			DebugText("%i survivors are alive", survivorsLiving);
			if (survivorsLiving >= 1)
			{
				RequestFrame(Zombie_Setup, victim);
				DebugText("%N was swapped to blue", victim);
				if (survivorsLiving == 1)
				{
					DebugText("Playing one left music");
					for (int i = 1; i <= MaxClients; i++)
					{
						// Need a way to stop this sound when the round is over
						if (IsValidClient(i))
							EmitSoundToClient(i, "zs2/oneleft.mp3", i);
					}
				}
			}
			else
			{
				DebugText("Not swapping %N, there are no alive survivors", victim);
				ForceWin(TEAM_ZOMBIES);
			}
		}

		if (attacker < 1 || !IsValidClient(attacker) || victim == attacker)
			return Plugin_Continue;

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
	}
	return Plugin_Continue;
}

/* Survivor setup
==================================================================================================== */

void Survivor_Setup(const int client)
{
	if (GetClientTeam(client) != TEAM_SURVIVORS)
		ChangeClientTeam(client, TEAM_SURVIVORS);

	TF2_RespawnPlayer(client);
	TF2_RegeneratePlayer(client);
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 0));
}

/* Zombie setup
==================================================================================================== */

void Zombie_Setup(const int client)
{
	if (GetClientTeam(client) != TEAM_ZOMBIES)
		ChangeClientTeam(client, TEAM_ZOMBIES);

	TF2_RespawnPlayer(client);

	OnlyMelee(client);
	RemoveWearable(client);
}

void OnlyMelee(int client)
{
	for (int i = 0; i < 6; i++)
	{
		if (i == 2)
			continue;
		if (i == 3)
		{
			if (TF2_GetPlayerClass(client) == TFClass_Engineer || TF2_GetPlayerClass(client) == TFClass_Spy)
				continue;
		}
		if (i == 4)
		{
			if (TF2_GetPlayerClass(client) == TFClass_Engineer || TF2_GetPlayerClass(client) == TFClass_Spy)
				continue;
		}
		if (i == 5 && TF2_GetPlayerClass(client) == TFClass_Engineer)
			continue;

		TF2_RemoveWeaponSlot(client, i);
	}

	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 2));
}

void RemoveWearable(int client)
{
	int i = -1;
	while ((i = FindEntityByClassname(i, "tf_wearable_demoshield")) != -1)
	{
		if (client != GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity")) continue;
		AcceptEntityInput(i, "Kill");
	}
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
		DebugText("Player %i on queue menu is client %i", i, players[i]);

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
			DebugText("All queue points reset to 0");
		}
		else
			PrintToServer("%s This command is too destructive to be run outside of debug mode.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}
	queuePoints[client] = 0;
	CPrintToChat(client, "%s {haunted}Your queue points were reset to 0.", MESSAGE_PREFIX);
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
			queuePoints[i] += 10;
	}
}

Action Timer_PlaytimePoints(Handle timer)
{
	if (!roundStarted)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GetClientTeam(i) == TEAM_ZOMBIES)
				queuePoints[i] += smPointsWhilePlaying.IntValue;
		}
	}
	return Plugin_Continue;
}

/* Queue points checking
==================================================================================================== */

int GetClientWithMostQueuePoints(bool[] myArray, bool mark=true)
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

bool IsAllowedClass(const TFClassType class)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == TEAM_SURVIVORS && TF2_GetPlayerClass(i) == class)
			return false;
	}

	return true;
}

void ForceWin(int team)
{
	DebugText("Forcing win for team %i", team);

	int ent = FindEntityByClassname(-1, "game_round_win");
	if (ent < 1)
	{
		ent = CreateEntityByName("game_round_win");
		if (!IsValidEntity(ent))
			return;
	}
	DispatchKeyValue(ent, "force_map_reset", "1");
	DispatchSpawn(ent);
	SetVariantInt(team);
	AcceptEntityInput(ent, "SetTeam");
	AcceptEntityInput(ent, "RoundWin");
}

/* Debug output
==================================================================================================== */

void DebugText(const char[] text, any ...) {
	if (smDebug.BoolValue) {
		int len = strlen(text) + 255;
		char[] format = new char[len];
		VFormat(format, len, text, 2);
		CPrintToChatAll("{collectors}[ZS2 Debug] {white}%s", format);
		PrintToServer("[ZS2 Debug] %s", format);
	}
}
