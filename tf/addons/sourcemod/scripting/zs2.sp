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
#define PLUGIN_VERSION "0.1 Beta"
#define MOTD_VERSION "0.1"
#define IsValidClient(%1) (1 <= %1 <= MaxClients && IsClientInGame(%1))

// Plugin information
public Plugin myinfo = {
	name = "Zombie Survival 2",
	author = "Jack5 & poonit",
	description = "A zombie game mode featuring all-class action with multiple modes, inspired by the Left 4 Dead series.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Zombie-Survival-2"
};

// Variables
public const char gamemods[2][] = {
	// "Attack",
	"Defend",
	"Survival"
	// "Waves",
	// "Scavenge"
};
enum GameMod
{
	// Game_Attack,
	Game_Defend,
	Game_Survival
	// Game_Waves,
	// Game_Scavenge
};
public const char captures[6][32] = {
	"team_control_point_master",
	"team_control_point",
	"trigger_capture_area",
	"item_teamflag",
	"func_capturezone",
	"mapobj_cart_dispenser"
};
bool setupTime,
	roundStarted,
	waitingForPlayers,
	firstConnection[MAXPLAYERS+1] = {true, ...},
	selectedAsSurvivor[MAXPLAYERS+1];
int iSeconds,
	TEAM_SURVIVORS = 2,
	TEAM_ZOMBIES = 3,
	queuePoints[MAXPLAYERS+1],
	damageDealt[MAXPLAYERS+1];
GameMod gameMod = Game_Survival;
Handle roundTimer;

// JSON-controlled variables, allowing gamemods should also be included here
bool freezeInSetup;
int roundDuration,
	setupDuration;
char introCP[64],
	introST[64];
ArrayList allowedGamemods;

// ConVars
ConVar gcv_debug,
	gcv_ratio,
	gcv_maxsurvivors,
	gcv_mindamage, 
	gcv_timerpoints,
	gcv_playtimepoints,
	gcv_killpoints,
	gcv_assistpoints;

// Method includes
#include "zs2/defend.sp"
#include "zs2/survival.sp"

/* Plugin initialisation
==================================================================================================== */

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_TF2)
	{
		SetFailState("This gamemod can only run on Team Fortress 2.");
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
	gcv_debug = CreateConVar("sm_zs2_debug", "1", "Disables or enables debug messages in chat, set to 0 as default before release.");
	gcv_ratio = CreateConVar("sm_zs2_ratio", "3", "Number of zombies per survivor.", _, true, 0.0, true, 1.0);
	gcv_maxsurvivors = CreateConVar("sm_zs2_maxsurvivors", "6", "Maximum number of survivors allowed.", _, true, 0.0);
	gcv_mindamage = CreateConVar("sm_zs2_mindamage", "200", "Minimum damage to earn queue points.", _, true, 0.0);
	gcv_timerpoints = CreateConVar("sm_zs2_pointsinterval", "30.0", "Timer interval for giving queue points.", _, true, 0.0);
	gcv_playtimepoints = CreateConVar("sm_zs2_playtimepoints", "5", "X points for playing on the server.", _, true, 0.0);
	gcv_killpoints = CreateConVar("sm_zs2_killpoints", "5", "X points when zombie kills.", _, true, 0.1);
	gcv_assistpoints = CreateConVar("sm_zs2_assistpoints", "3", "X points when zombie assists.", _, true, 0.0);

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
	
	// Setting JSON variables
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	JSON_Object serverdata = ReadScript(mapName);
	allowedGamemods = new ArrayList(16, 2); // Increase with each added round type
	if (serverdata != null)
	{
		DebugText("JSON file found");
		freezeInSetup = !serverdata.GetBool("donotfreeze"); // Reversed because default is false
		int intval = serverdata.GetInt("t_round");
		if (intval > 0)
			roundDuration = intval;
		else
		{
			DebugText("Round time out of bounds or not found, using default");
			roundDuration = 300;
		}
		intval = serverdata.GetInt("t_setup");
		if (intval > 0)
			setupDuration = intval;
		else
		{
			DebugText("Setup time out of bounds or not found, using default");
			setupDuration = 30;
		}
		if (!serverdata.GetString("cp_intro", introCP, sizeof(introCP)))
		{
			DebugText("No definition for CP intro music found, disabled");
			introCP = "";
		}
		if (!serverdata.GetString("st_intro", introST, sizeof(introST)))
		{
			DebugText("No definition for ST intro music found, disabled");
			introST = "";
		}
		if (serverdata.GetBool("cp_d"))
			allowedGamemods.PushString("Defend");
		if (serverdata.GetBool("st_s"))
			allowedGamemods.PushString("Survival");
	}
	else
	{
		DebugText("JSON file not found, using defaults");
		freezeInSetup = true;
		roundDuration = 300;
		setupDuration = 30;
		introCP = "";
		introST = "";
		for (int i = 0; i < sizeof(gamemods); i++)
			allowedGamemods.PushString(gamemods[i]);
	}
	json_cleanup_and_delete(serverdata);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "tf_logic_koth") == 0 || strcmp(classname, "tf_logic_arena") == 0)
		AcceptEntityInput(entity, "KillHierarchy");
}

public void OnConfigsExecuted()
{
	// Server tags
	InsertServerTag("zombies");
	InsertServerTag("zombie survival 2");
	InsertServerTag("zs2");

	// Cvars
	FindConVar("tf_ctf_bonus_time").SetInt(0);
	FindConVar("tf_flag_caps_per_round").SetInt(2);
	FindConVar("mp_scrambleteams_auto").SetInt(0);
	FindConVar("tf_weapon_criticals").SetInt(0);

	// Timers
	CreateTimer(gcv_timerpoints.FloatValue, Timer_PlaytimePoints, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void InsertServerTag(const char[] insertThisTag)
{
	ConVar tags = FindConVar("sv_tags");
	if (tags != null) 
	{
		char serverTags[256];
		// Insert server tag at end
		tags.GetString(serverTags, sizeof(serverTags));
		if (StrContains(serverTags, insertThisTag, true) == -1) 
		{
			Format(serverTags, sizeof(serverTags), "%s,%s", serverTags, insertThisTag);
			tags.SetString(serverTags);
			// If failed, insert server tag at start
			tags.GetString(serverTags, sizeof(serverTags));
			if (StrContains(serverTags, insertThisTag, true) == -1) 
			{
				Format(serverTags, sizeof(serverTags), "%s,%s", insertThisTag, serverTags);
				tags.SetString(serverTags);
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
	if (!waitingForPlayers)
	{
		int ent = -1;
		while ((ent = FindEntityByClassname(ent, "team_round_timer")) != -1)
		{
			AcceptEntityInput(ent, "Kill");
		}

		setupTime = true;
		iSeconds = setupDuration;
		delete roundTimer;
		roundTimer = CreateTimer(1.0, CountDown, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

		// Determine required number of survivors
		int playerCount = GetClientCount(true);
		int ratio = gcv_ratio.IntValue;
		if (ratio > 32 || ratio < 1)
			ratio = 3;
		int maxsurvivors = gcv_maxsurvivors.IntValue;
		if (maxsurvivors > 32 || maxsurvivors < 1)
			maxsurvivors = 6;

		// Set up required survivors, do not let it exceed the maximum value
		int required;
		if (playerCount <= ratio * maxsurvivors - ratio)
			required = RoundToCeil(float(playerCount) / float(ratio));
		else
			required = maxsurvivors;

		// Populate survivor team, will need to be fired for the zombie team during setup time if someone disconnects
		for (int i = 0; i < required; i++)
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
		switch (gameMod)
		{
			case Game_Defend:
				Defend_RoundStart();
			case Game_Survival: 
				Survival_RoundStart();
		}

		roundStarted = true;
	}
}

void Event_SetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	DebugText("Setup time finished");
	setupTime = false;
	iSeconds = roundDuration;
	delete roundTimer;
	roundTimer = CreateTimer(1.0, CountDown2, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

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
	{
		ForceWin(TEAM_ZOMBIES);
	}
}

public Action CountDown(Handle timer)
{
    iSeconds--;

    if (iSeconds < 0)
    {
        roundTimer = null;
        Event event = CreateEvent("teamplay_setup_finished");
        event.Fire();

        int ent = -1;
        while ((ent = FindEntityByClassname(ent, "func_door")) != -1)
        {
            AcceptEntityInput(ent, "Unlock");
            AcceptEntityInput(ent, "Open");
        }

        return Plugin_Stop;
    }

    SetHudTextParams(-1.0, 0.05, 1.1, 255, 255, 255, 255);
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && !IsFakeClient(i))
            ShowHudText(i, -1, "Setup ends in %d:%02d", iSeconds / 60, iSeconds % 60);
    }

    return Plugin_Continue;
}

public Action CountDown2(Handle timer)
{
	iSeconds--;

	if (iSeconds < 0)
	{
		roundTimer = null;
		switch (gameMod)
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
			ShowHudText(i, -1, "%d:%02d remaining", iSeconds / 60, iSeconds % 60);
	}

	return Plugin_Continue;
}

void VoteGamemod()
{
	// If no or only one round type is available, force the default
	if (allowedGamemods.Length <= 1)
	{
		DebugText("Only one round type available, forcing");
		if (allowedGamemods.Length == 1)
		{
			char strval[32];
			allowedGamemods.GetString(0, strval, sizeof(strval));
			if (StrEqual(strval, "Defend"))
				gameMod = Game_Defend;
			else
				gameMod = Game_Survival;
		}
		else
			gameMod = Game_Survival;
	}
	// Use a vote if there are more round types to choose from
	else
	{
		NativeVote vote = new NativeVote(GameVote, NativeVotesType_Custom_Mult);
		vote.Initiator = NATIVEVOTES_SERVER_INDEX;
		vote.SetDetails("Select next round type:");
		char info[2];
		for (int i = 0; i < 2; i++)
		{
			IntToString(i, info, sizeof(info));
			vote.AddItem(info, gamemods[i]);
		}
		vote.DisplayVoteToAll(13);
	}
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
			char info[2];
			vote.GetItem(param1, info, sizeof(info));
			int i = StringToInt(info);
			int votes, totalVotes;
			NativeVotes_GetInfo(param2, votes, totalVotes);
			vote.DisplayPassCustom("Round type set to %s", gamemods[i], votes, totalVotes);
			CPrintToChatAll("%s {haunted}The next round type will be {normal}%s {haunted}(%d/%d).", MESSAGE_PREFIX, gamemods[i], votes, totalVotes);
			gameMod = view_as<GameMod>(i);
		}
	}
}

/* Round end + audio blocking
==================================================================================================== */

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	delete roundTimer;
	CreateTimer(3.0, Timer_CalcQueuePoints, _, TIMER_FLAG_NO_MAPCHANGE);
	int team = event.GetInt("team");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			selectedAsSurvivor[i] = false;
			damageDealt[i] = 0;

			if (team == GetClientTeam(i))
				EmitSoundToClient(i, "zs2/victory.mp3", i);
			else
				EmitSoundToClient(i, "zs2/defeat.mp3", i);
		}
	}

	roundStarted = false;
	
	VoteGamemod();

	if (GetTeamClientCount(TEAM_SURVIVORS) == 1 && team == TEAM_ZOMBIES) // Important! Call switch after `roundStarted` is set to false.
	{
		CreateTimer(12.0, Timer_Switch, _, TIMER_FLAG_NO_MAPCHANGE);
		// This may be causing the zombie with the most queue points to be forcibly moved to the red team for no reason, fix if possible
	}
}

Action Event_Audio(Event event, const char[] name, bool dontBroadcast)
{
    char strAudio[40];
    GetEventString(event, "sound", strAudio, sizeof(strAudio));
    
	// Block victory and loss sounds
    if (strncmp(strAudio, "Game.Your", 9) == 0)
        return Plugin_Handled;
    
    return Plugin_Continue;
}

/* Client actions
==================================================================================================== */

Action Listener_JoinTeam(int client, const char[] command, int args)
{
	char arg[8];
	GetCmdArg(1, arg, sizeof(arg));

	if (CheckCommandAccess(client, "", ADMFLAG_KICK) && StrContains(arg, "red", false) == -1)
		return Plugin_Continue;

	if (StrContains(arg, "spec", false) > -1)
		return Plugin_Handled;

	if (firstConnection[client])
	{
		CreateTimer(3.0, Timer_DisplayIntro, client);
		firstConnection[client] = false;
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

Action Listener_JoinClass(int client, const char[] command, int args)
{
	if (!waitingForPlayers)
	{
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg));

		if (GetClientTeam(client) == TEAM_SURVIVORS && !IsAllowedClass(TF2_GetClass(arg)))
		{
			EmitSoundToClient(client, "replay/replaydialog_warn.wav", client);
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

Action Listener_Build(int client, const char[] command, int args)
{
	char arg[2];
	GetCmdArg(1, arg, sizeof(arg));

	// Block everything except teleporters (1)
	if (client && GetClientTeam(client) == TEAM_ZOMBIES && strcmp(arg, "1") != 0)
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
			if (!setupTime)
			{
				EmitSoundToClient(victim, "zs2/death.mp3", victim);
				
				int survivorsLiving = GetTeamClientCount(TEAM_SURVIVORS) - 1;
				DebugText("%i survivors are alive", survivorsLiving);
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
				else if (survivorsLiving == 0)
				{
					ForceWin(TEAM_ZOMBIES);
				}
				
				RequestFrame(Zombie_Setup, victim);
			}
		}

		if (attacker < 1 || !IsValidClient(attacker) || victim == attacker)
			return Plugin_Continue;

		// This part deals with attacker and victim

		if (team == TEAM_SURVIVORS)
		{
			queuePoints[attacker] += gcv_killpoints.IntValue;

			if (assister && IsValidClient(assister))
				queuePoints[assister] += gcv_assistpoints.IntValue;
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
	
	bool[] checked = new bool[MaxClients+1];
	int[] players = new int[MaxClients+1];
	int j = 0;

	for ( ; j < MaxClients + 1; j++) // the array's size = MaxClients + 1
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
		if (gcv_debug.BoolValue)
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
		if (IsValidClient(i) && damageDealt[i] >= gcv_mindamage.IntValue)
			queuePoints[i] += 10;
	}
}

Action Timer_Switch(Handle timer)
{
	int player = GetClientWithMostQueuePoints(selectedAsSurvivor, false);
	if (player) ChangeClientTeam(player, TEAM_SURVIVORS);
	return Plugin_Continue;
}

Action Timer_PlaytimePoints(Handle timer)
{
	if (!roundStarted)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GetClientTeam(i) == TEAM_ZOMBIES)
				queuePoints[i] += gcv_playtimepoints.IntValue;
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

/* JSON reading
==================================================================================================== */

JSON_Object ReadScript(char[] name)
{
	char file[128];
	Format(file, sizeof(file), "scripts/zs2/%s.json", name);
	if (FileExists(file))
	{
		char output[1024];
		File json = OpenFile(file, "r");
		json.ReadString(output, sizeof(output));
		json.Close();
		return json_decode(output);
	}
	return null;
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
	DebugText("Forcing win to %i", team);

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
	if (gcv_debug.BoolValue) {
		int len = strlen(text) + 255;
		char[] format = new char[len];
		VFormat(format, len, text, 2);
		CPrintToChatAll("{collectors}[ZS2 Debug] {white}%s", format);
		PrintToServer("[ZS2 Debug] %s", format);
	}
}
