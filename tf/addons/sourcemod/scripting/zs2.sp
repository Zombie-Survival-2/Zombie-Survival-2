/* Definitions
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

#pragma newdecls required

// Defines
#define MESSAGE_PREFIX "{collectors}[ZS2]"
#define MESSAGE_PREFIX_NO_COLOR "[ZS2]"
#define PLUGIN_VERSION "0.1 Beta"
#define MOTD_VERSION "0.1"

public Plugin myinfo = {
	name = "Zombie Survival 2",
	author = "Hagvan, Jack5, poonit & SirGreenman",
	description = "A zombie game mode featuring all-class action with multiple modes, inspired by the Left 4 Dead series.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Zombie-Survival-2"
};

// Global Variables
enum {
	TEAM_SPECTATORS = 1,
	TEAM_SURVIVORS = 2,
	TEAM_ZOMBIES = 3
};

bool roundStarted,
	waitingForPlayers,
	firstConnection[MAXPLAYERS+1] = {true, ...},
	selectedAsSurvivor[MAXPLAYERS+1];

int queuePoints[MAXPLAYERS+1], 
	damageDealt[MAXPLAYERS+1];

// ConVars
ConVar gcv_debug,
	gcv_Ratio,
	gcv_maxsurvivors,
	gcv_MinDamage, 
	gcv_timerPoints,
	gcv_playtimePoints,
	gcv_killPoints,
	gcv_assistPoints;

/* Events
==================================================================================================== */

public void OnPluginStart()
{
	// Events
	HookEvent("teamplay_broadcast_audio", Event_Audio, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("teamplay_setup_finished", Event_SetupFinished);
	HookEvent("player_death", Event_OnDeath);
	HookEvent("player_spawn", Event_OnSpawn);
	HookEvent("post_inventory_application", Event_PlayerRegen);

	// Convars
	gcv_debug = CreateConVar("sm_zs2_debug", "1", "Disables or enables debug messages in chat, set to 0 as default before release.");
	gcv_Ratio = CreateConVar("sm_zs2_ratio", "3", "Number of zombies per survivor.", _, true, 0.0, true, 1.0);
	gcv_maxsurvivors = CreateConVar("sm_zs2_maxsurvivors", "6", "Maximum number of survivors allowed.", _, true, 0.0);
	gcv_MinDamage = CreateConVar("sm_zs2_mindamage", "200", "Minimum damage to earn queue points.", _, true, 0.0);
	gcv_timerPoints = CreateConVar("sm_zs2_pointsinterval", "30.0", "Timer Interval for giving queue points", _, true, 0.0);
	gcv_playtimePoints = CreateConVar("sm_zs2_playtimepoints", "5", "X points for playing on the server", _, true, 0.0);
	gcv_killPoints = CreateConVar("sm_zs2_killpoints", "5", "X points when zombie kills", _, true, 0.1);
	gcv_assistPoints = CreateConVar("sm_zs2_gcv_assistpoints", "3", "X points when zombie assists", _, true, 0.0);

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

	// Command Listeners
	AddCommandListener(Listener_JoinTeam, "jointeam");

	// Translations
	LoadTranslations("common.phrases");
}

public void OnMapStart() {
	// Sounds precaching and downloading
	PrecacheSound("zs2/death.mp3");
	AddFileToDownloadsTable("sound/zs2/death.mp3");
	PrecacheSound("zs2/defeat.mp3");
	AddFileToDownloadsTable("sound/zs2/defeat.mp3");
	PrecacheSound("zs2/victory.mp3");
	AddFileToDownloadsTable("sound/zs2/victory.mp3");
	// Wav files need to be changed to mp3 wherever possible, will require re-render on Jack's end
	PrecacheSound("zs2/intro_st/bloodharvest_m22050.wav");
	AddFileToDownloadsTable("sound/zs2/intro_st/bloodharvest_m22050.wav");
}

public void OnConfigsExecuted()
{
	InsertServerTag("zombies");
	InsertServerTag("zombie survival 2");
	InsertServerTag("zs2");

	// Timers
	CreateTimer(gcv_timerPoints.FloatValue, Timer_GiveQueuePoints, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	CreateTimer(5.0, Timer_DisplayIntro, client);
}

public void OnClientDisconnect(int client)
{
	queuePoints[client] = 0;
	damageDealt[client] = 0;
	selectedAsSurvivor[client] = false;
	firstConnection[client] = true;
}

public void TF2_OnWaitingForPlayersStart()
{
	waitingForPlayers = true;
}

public void TF2_OnWaitingForPlayersEnd()
{
	waitingForPlayers = false;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!waitingForPlayers)
	{
		int playerCount = GetClientCount(true);
		int ratio = gcv_Ratio.IntValue;
		if (ratio > 32 || ratio < 1)
			ratio = 3;
		int maxsurvivors = gcv_maxsurvivors.IntValue;
		if (maxsurvivors > 32 || maxsurvivors < 1)
			maxsurvivors = 6;
		int required;
		if (playerCount <= ratio * (maxsurvivors - ratio))
			required = RoundToCeil(float(playerCount) / float(ratio));
		else
			required = maxsurvivors;

		for (int i = 0; i < required; i++)
		{
			int player = GetClientWithMostQueuePoints(selectedAsSurvivor);
			if (!player)
				break;

			Survivor_Setup(player);
			CPrintToChat(player, "%s {haunted}You have been selected to become a {normal}Survivor.", MESSAGE_PREFIX);
		}

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !selectedAsSurvivor[i])
			{
				Zombie_Setup(i);
				CPrintToChat(i, "%s {haunted}You have been selected to become a {normal}Zombie.", MESSAGE_PREFIX);
			}
		}
		
		char map[64];
		GetCurrentMap(map, sizeof(map));
		JSON_Object serverdata = ReadScript(map);
		if (serverdata != null)
		{
			// Set this as the setup time
			// int intval = serverdata.GetInt("t_setup");
			// Set this as the round time
			// intval = serverdata.GetInt("t_round");
			char strval[64];
			// Play this sound to everyone if this is the first round or the player count has grown, need to distinguish between waiting for players eventually
			serverdata.GetString("st_intro", strval, sizeof(strval));
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
					EmitSoundToClient(i, strval, i);
			}
			// Else play this sound to everyone if the player count has not grown
			serverdata.GetString("st_sting", strval, sizeof(strval));
		}
		else
		{
			// Do default stuff here
		}

		roundStarted = true;
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(3.0, Timer_CalcQueuePoints, _, TIMER_FLAG_NO_MAPCHANGE);

	int team = event.GetInt("team");
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			selectedAsSurvivor[i] = false;
			damageDealt[i] = 0;

			if (team == GetClientTeam(i))
			{
				EmitSoundToClient(i, "zs2/victory.mp3", i);
			}
			else
			{
				EmitSoundToClient(i, "zs2/defeat.mp3", i);
			}
		}
	}

	roundStarted = false;

	if (GetTeamClientCount(TEAM_SURVIVORS) == 1 && team == TEAM_ZOMBIES) // Important! Call switch after `roundStarted` is set to false.
	{
		CreateTimer(12.0, Timer_Switch, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Event_PlayerRegen(Event event, const char[] name, bool dontBroadcast)
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

public Action Event_SetupFinished(Event event, const char[] name, bool dontBroadcast) {
	// Set all resupply cabinets to only work for zombies, this currently doesn't work because of bad ent_fire code
	char teamNum[1];
	IntToString(TEAM_ZOMBIES, teamNum, 1);
	EntFire("func_regenerate", "SetTeam", teamNum);
}

public Action Event_OnDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!waitingForPlayers) {
		int victim = GetClientOfUserId(event.GetInt("userid"));
		int assister = GetClientOfUserId(event.GetInt("assister"));
		int attacker = GetClientOfUserId(event.GetInt("attacker"));

		// This part deals with victim only

		int team = GetClientTeam(victim);

		if (roundStarted && GetClientTeam(victim) == TEAM_SURVIVORS)
		{
			RequestFrame(Zombie_Setup, victim);
		}

		if (attacker < 1 || !IsClientInGame(attacker) || victim == attacker)
		{
			return Plugin_Continue;
		}

		// This part deals with attacker and victim

		if (team == TEAM_SURVIVORS)
		{
			EmitSoundToClient(victim, "zs2/death.mp3", victim);

			queuePoints[attacker] += gcv_killPoints.IntValue;

			if (assister && IsClientInGame(assister))
			{
				queuePoints[assister] += gcv_assistPoints.IntValue;
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_OnSpawn(Event event, const char[] name, bool dontBroadcast)
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

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!waitingForPlayers)
		{
		if (victim < 1 || attacker < 1 || !IsClientInGame(attacker) || !IsClientInGame(victim) || victim == attacker)
			return Plugin_Continue;

		damageDealt[attacker] += view_as<int>(damage);
	}
	return Plugin_Continue;
}

public Action Listener_JoinTeam(int client, const char[] command, int args)
{
	if (firstConnection[client])
	{
		firstConnection[client] = false;
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

public Action Event_Audio(Event event, const char[] name, bool dontBroadcast)
{
    char strAudio[40];
    GetEventString(event, "sound", strAudio, sizeof(strAudio));
    
    if (strncmp(strAudio, "Game.Your", 9) == 0)
    {
        // Block victory and loss sounds
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
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
		{
			break;
		}
	}

	Menu menu = new Menu(Handler_Nothing);
	menu.SetTitle("%s Queue Points", MESSAGE_PREFIX_NO_COLOR);
	char display[64];

	for (int i = 0; i < j; i++)
	{
		if (gcv_debug.BoolValue)
		{
			DebugText("Player %i on queue menu is client %i", i, players[i]);
		}

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
			DebugText("All queue points reset to 0.");
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

/* Functions + Timers
==================================================================================================== */

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

public Action Timer_DisplayIntro(Handle timer, int client) 
{
	if (IsClientInGame(client)) // Required because player might disconnect before this fires
	{ 
		CPrintToChat(client, "%s {haunted}This server is running {collectors}Zombie Survival 2 {normal}v%s!", MESSAGE_PREFIX, PLUGIN_VERSION);
		CPrintToChat(client, "{haunted}If you would like to know more, type the command {normal}!zs2 {haunted}into chat.");
	}
}

public Action Timer_CalcQueuePoints(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && damageDealt[i] >= gcv_MinDamage.IntValue)
		{
			queuePoints[i] += 10;
		}
	}
}

public Action Timer_Switch(Handle timer)
{
	int player = GetClientWithMostQueuePoints(selectedAsSurvivor, false);
	if (player) ChangeClientTeam(player, TEAM_SURVIVORS);
	return Plugin_Continue;
}

public Action Timer_GiveQueuePoints(Handle timer)
{
	if (!roundStarted)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == TEAM_ZOMBIES)
			{
				queuePoints[i] += gcv_playtimePoints.IntValue;
			}
		}
	}
	return Plugin_Continue;
}

void Zombie_Setup(const int client)
{
	if (GetClientTeam(client) != TEAM_ZOMBIES)
	{
		ChangeClientTeam(client, TEAM_ZOMBIES);
	}

	TF2_RespawnPlayer(client);

	for (int i = 0; i < 6; i++)
	{
		if (i != 2)
		{
			TF2_RemoveWeaponSlot(client, i);
		}
	}

	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 2)); 
}

void Survivor_Setup(const int client)
{
	if (GetClientTeam(client) != TEAM_SURVIVORS)
	{
		ChangeClientTeam(client, TEAM_SURVIVORS);
	}

	TF2_RespawnPlayer(client);
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 0)); 
}

int GetClientWithMostQueuePoints(bool[] arrayType, bool mark=true)
{
	int chosen = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && queuePoints[i] >= queuePoints[chosen] && !arrayType[i])
		{
			chosen = i;
		}
	}

	if (chosen && mark)
	{
		arrayType[chosen] = true;
	}

	return chosen;
}

/* DebugText()
==================================================================================================== */

public void DebugText(const char[] text, any ...) {
	if (gcv_debug.BoolValue) {
		int len = strlen(text) + 255;
		char[] format = new char[len];
		VFormat(format, len, text, 2);
		CPrintToChatAll("{collectors}[ZS2 Debug] {white}%s", format);
		PrintToServer("[ZS2 Debug] %s", format);
	}
}

/* EntFire()
sm_entfire with updated syntax
==================================================================================================== */

stock bool EntFire(char[] strTargetname, char[] strInput, char strParameter[] = "", float flDelay = 0.0) {
	char strBuffer[255];
	Format(strBuffer, sizeof(strBuffer), "OnUser1 %s:%s:%s:%f:1", strTargetname, strInput, strParameter, flDelay);
	int entity = CreateEntityByName("info_target");
	if (IsValidEdict(entity)) {
		DispatchSpawn(entity);
		ActivateEntity(entity);
		SetVariantString(strBuffer);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
		CreateTimer(0.0, Timer_DeleteEdict, entity);
		return true;
	}
	return false;
}

public Action Timer_DeleteEdict(Handle timer, int entity) {
	if (IsValidEdict(entity)) {
		RemoveEdict(entity);
	}
	return Plugin_Stop;
}

/* ReadScript()
==================================================================================================== */

JSON_Object ReadScript(char[] name)
{
	char file[64];
	Format(file, sizeof(file), "scripts/zs2/%s.json", name);
	if (FileExists(file))
	{
		char output[1024];
		File json = OpenFile(file, "r");
		json.ReadString(output, sizeof(output));
		CloseHandle(json);
		return json_decode(output);
	}
	return null;
}
