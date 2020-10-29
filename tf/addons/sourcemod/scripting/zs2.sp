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

public Plugin myinfo = {
	name = "Zombie Survival 2",
	author = "Hagvan, Jack5, poonit & SirGreenman",
	description = "A zombie game mode featuring all-class action with multiple modes, inspired by the Left 4 Dead series.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Zombie-Survival-2"
};

/* OnPluginStart()
==================================================================================================== */

public void OnPluginStart() {
	// Commands
	RegConsoleCmd("sm_zs", Command_ZS);
	RegConsoleCmd("sm_zs2", Command_ZS2);

	// Translations
	LoadTranslations("common.phrases");
}

/* OnConfigsExecuted() + InsertServerTag()
==================================================================================================== */

public void OnConfigsExecuted() {
	InsertServerTag("zs2");
}

public void InsertServerTag(const char[] insertThisTag) {
	ConVar tags = FindConVar("sv_tags");
	if (tags != null) {
		char serverTags[258];
		// Insert server tag at end
		tags.GetString(serverTags, sizeof(serverTags));
		if (StrContains(serverTags, insertThisTag, true) == -1) {
			Format(serverTags, sizeof(serverTags), "%s,%s", serverTags, insertThisTag);
			tags.SetString(serverTags);
			// If failed, insert server tag at start
			tags.GetString(serverTags, sizeof(serverTags));
			if (StrContains(serverTags, insertThisTag, true) == -1) {
				Format(serverTags, sizeof(serverTags), "%s,%s", insertThisTag, serverTags);
				tags.SetString(serverTags);
			}
		}
	}
}

/* Commands
==================================================================================================== */

public Action Command_ZS(int client, int args) {
	Command_ZS2(client, args);
}

public Action Command_ZS2(int client, int args) {
	if (client == 0) {
		PrintToServer("%s Because this command uses the MOTD, it cannot be executed from the server console.", MESSAGE_PREFIX_NO_COLOR);
		return Plugin_Handled;
	}
	char url[200];
	Format(url, sizeof(url), "https://zombie-survival-2.github.io/%s", MOTD_VERSION);
	AdvMOTD_ShowMOTDPanel(client, "", url, MOTDPANEL_TYPE_URL, true, true, true, INVALID_FUNCTION);
	CPrintToChat(client, "%s {haunted}Opening Zombie Survival 2 manual... If nothing happens, open your developer console and {normal}set cl_disablehtmlmotd to 0{haunted}, then try again.", MESSAGE_PREFIX);
	return Plugin_Handled;
}

/* Introductory Message
==================================================================================================== */

public Action Timer_DisplayIntro(Handle timer, int client) {
	if (IsClientInGame(client)) { // Required because player might disconnect before this fires
		CPrintToChat(client, "%s {haunted}This server is running {collectors}Zombie Survival 2 {normal}v%s!", MESSAGE_PREFIX, PLUGIN_VERSION);
		CPrintToChat(client, "{haunted}If you would like to know more, type the command {normal}!zs2 {haunted}into chat.");
	}
}

/* Events
==================================================================================================== */

public void OnClientPutInServer(int client) {
	CreateTimer(3.0, Timer_DisplayIntro, client);
}
