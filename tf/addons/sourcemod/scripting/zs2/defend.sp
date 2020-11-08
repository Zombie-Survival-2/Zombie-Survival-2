public void Defend_RoundStart()
{
	CP_IntroMusic();
	ST_EnableObjectives();
	gameMod = Game_Defend;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (GetClientTeam(i) == TEAM_SURVIVORS)
				CPrintToChat(i, "%s {normal}Defend: {haunted}The zombies are able to capture the objective. Don't let them win behind your backs!", MESSAGE_PREFIX);
			else
				CPrintToChat(i, "%s {normal}Defend: {haunted}You are able to capture the objective. Split up between capping and killing to win!", MESSAGE_PREFIX);
		}
	}
}

void CP_IntroMusic()
{
	char map[64];
	GetCurrentMap(map, sizeof(map));
	JSON_Object serverdata = ReadScript(map);
	if (serverdata != null)
	{
		char strval[64];
		serverdata.GetString("cp_intro", strval, sizeof(strval));
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
				EmitSoundToClient(i, strval, i);
		}
	}
}

void ST_EnableObjectives()
{
	int ent = -1;
	
	for (int i = 0; i < 5; i++)
	{
		while ((ent = FindEntityByClassname(ent, captures[i])) != -1)
		{
			AcceptEntityInput(ent, "Enable");
		}
	}
}
