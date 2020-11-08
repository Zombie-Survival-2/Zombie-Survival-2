public void Survival_RoundStart()
{
	ST_IntroMusic();
	ST_DisableObjectives();
	gameMod = Game_Survival;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (GetClientTeam(i) == TEAM_SURVIVORS)
				CPrintToChat(i, "%s {normal}Survival: {haunted}Don't die!", MESSAGE_PREFIX);
			else
				CPrintToChat(i, "%s {normal}Survival: {haunted}Kill them all!", MESSAGE_PREFIX);
		}
	}
}

void ST_IntroMusic()
{
	char map[64];
	GetCurrentMap(map, sizeof(map));
	JSON_Object serverdata = ReadScript(map);
	if (serverdata != null)
	{
		char strval[64];
		serverdata.GetString("st_intro", strval, sizeof(strval));
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
				EmitSoundToClient(i, strval, i);
		}
	}
}

void ST_DisableObjectives()
{
	int ent = -1;
	
	for (int i = 0; i < 5; i++)
	{
		while ((ent = FindEntityByClassname(ent, captures[i])) != -1)
		{
			AcceptEntityInput(ent, "Disable");
		}
	}
}
