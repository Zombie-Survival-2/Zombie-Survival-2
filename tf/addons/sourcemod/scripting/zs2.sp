/* Definitions
==================================================================================================== */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <tf2>
#include <tf2_stocks>
#include <advanced_motd>

#pragma newdecls required

// Defines
#define MESSAGE_PREFIX "{collectors}[ZS2]"
#define MESSAGE_PREFIX_NO_COLOR "[ZS2]"
#define PLUGIN_VERSION "0.1"
#define MOTD_VERSION "0.1"

enum
{
	INVALID = 0,
	TEAM_SPEC = 1,
	SURVIVE_TEAM = 2,
	ZOMBIE_TEAM = 3
};

ConVar gcv_fRatio, gcv_MinDamage;
bool firstConnection[MAXPLAYERS+1] = {true, ...},
	selectedAsZombie[MAXPLAYERS+1];

bool roundStarted;

int queuePoints[MAXPLAYERS+1], damageDealt[MAXPLAYERS+1];

public Plugin myinfo = {
	name = "Zombie Survival 2",
	author = "Hagvan, Jack5, poonit & SirGreenman",
	description = "A zombie game mode featuring all-class action with multiple modes, inspired by the Left 4 Dead series.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Zombie-Survival-2"
};

/* Events
==================================================================================================== */

public void OnPluginStart() 
{
	// Events
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("player_death", Event_OnDeath);

	// Convars
	gcv_fRatio = CreateConVar("sm_zs2_ratio", "0.334", "Ratio for zombies against survivors (blue / red = 0.334)", _, true, 0.0, true, 1.0);
	gcv_MinDamage = CreateConVar("sm_zs2_mindamage", "200", "Minimum damage to earn queue points.", _, true, 0.0);

	// Commands
	RegConsoleCmd("sm_zs", Command_ZS2);
	RegConsoleCmd("sm_zs2", Command_ZS2);

	// Commands Listeners
	AddCommandListener(Listener_JoinTeam, "jointeam");
	AddCommandListener(Listener_JoinClass, "joinclass");

	// Translations
	LoadTranslations("common.phrases");
}

public void OnConfigsExecuted() 
{
	InsertServerTag("zs2");
}

public void OnClientPutInServer(int client) 
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	CreateTimer(3.0, Timer_DisplayIntro, client);
}

public void OnClientDisconnect(int client)
{
	queuePoints[client] = 0;
	selectedAsZombie[client] = false;
	firstConnection[client] = true;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(GetClientCount() <= RoundToNearest(1 / gcv_fRatio.FloatValue))
	{
		return;
	}

	int required = GetClientCount() / RoundToNearest(1 / gcv_fRatio.FloatValue + 1);

	for(int i = 0; i < required; i++)
	{
		int player = GetClientWithLeastQueuePoints();
		PrintToChatAll("%N", player);

		if(!player)
			break;

		Zombie_Setup(player);
		PrintCenterText(player, "You have been selected to become a ZOMBIE!");
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == ZOMBIE_TEAM && !selectedAsZombie[i])
		{
			Survivor_Setup(i);
		}
	}

	roundStarted = true;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(3.0, Timer_CalcQueuePoints, _, TIMER_FLAG_NO_MAPCHANGE);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			selectedAsZombie[i] = false;
			damageDealt[i] = 0;
		}
	}

	roundStarted = false;
}

public Action Event_OnDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));

	if(roundStarted && GetClientTeam(victim) == SURVIVE_TEAM)
	{
		RequestFrame(SurvivorToZombie, GetClientUserId(victim));
	}
}

void SurvivorToZombie(any userid)
{
	Zombie_Setup(GetClientOfUserId(userid));
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(victim < 1 || attacker < 1 || !IsClientInGame(attacker) || !IsClientInGame(victim) || victim == attacker)
		return Plugin_Continue;

	damageDealt[attacker] += view_as<int>(damage);
	return Plugin_Continue;
}

public Action Listener_JoinTeam(int client, const char[] command, int args)
{
	if(firstConnection[client])
	{
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

public Action Listener_JoinClass(int client, const char[] command, int args)
{
	if(firstConnection[client])
	{
		firstConnection[client] = false;
		return Plugin_Continue;
	}

	if(GetClientTeam(client) != SURVIVE_TEAM)
		return Plugin_Handled;

	return Plugin_Continue;
}

/* Commands
==================================================================================================== */

public Action Command_ZS2(int client, int args)
{
	if (client == 0) 
	{
		PrintToServer("%s Because this command uses the MOTD, it cannot be executed from the server console.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}
	char url[200];
	FormatEx(url, sizeof(url), "https://zombie-survival-2.github.io/%s", MOTD_VERSION);
	AdvMOTD_ShowMOTDPanel(client, "", url, MOTDPANEL_TYPE_URL, true, true, true, INVALID_FUNCTION);
	CPrintToChat(client, "%s {haunted}Opening Zombie Survival 2 manual... If nothing happens, open your developer console and {normal}set cl_disablehtmlmotd to 0{haunted}, then try again.", MESSAGE_PREFIX);
	return Plugin_Handled;
}

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
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && damageDealt[i] >= gcv_MinDamage.IntValue)
		{
			queuePoints[i] += 10;
		}
	}
}

void Zombie_Setup(const int client)
{
	if(GetClientTeam(client) != ZOMBIE_TEAM)
	{
		ChangeClientTeam(client, ZOMBIE_TEAM);
	}

	TF2_RespawnPlayer(client);
	TF2_SetPlayerClass(client, TFClass_Medic, true, false);
	TF2_RegeneratePlayer(client);

	for(int i = 0; i < 6; i++)
	{
		if(i == 2)
			continue;

		TF2_RemoveWeaponSlot(client, i);
	}

	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 2)); 
}

void Survivor_Setup(const int client)
{
	ChangeClientTeam(client, SURVIVE_TEAM);
	TF2_RespawnPlayer(client);
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 2)); 
}

int GetClientWithLeastQueuePoints()
{
	int chosen = 0;
	queuePoints[0] = 9999;

	for(int i = 1; i <= MaxClients; i++) // Prefer to take from blue
	{
		if(IsClientInGame(i) && queuePoints[i] <= queuePoints[chosen] && GetClientTeam(i) == ZOMBIE_TEAM && !selectedAsZombie[i])
		{
			chosen = i;
		}
	}

	if(!chosen)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && queuePoints[i] <= queuePoints[chosen] && !selectedAsZombie[i])
			{
				chosen = i;
			}
		}
	}

	if(chosen)
	{
		selectedAsZombie[chosen] = true;
	}

	return chosen;
}
