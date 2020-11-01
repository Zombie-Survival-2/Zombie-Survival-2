public void Survival_RoundStart()
{
	ST_IntroMusic();
	ST_DisableObjectives();
	ST_DisableLockers();
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
	char captures[5][32] = { "team_control_point_master", "team_control_point", "trigger_capture_area", "item_teamflag", "func_capturezone" };
	int ent = -1;
	
	for (int i = 0; i < 5; i++)
	{
		while ((ent = FindEntityByClassname(ent, captures[i])) != -1)
		{
			AcceptEntityInput(ent, "Disable");
		}
	}
}

void ST_DisableLockers()
{
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_regenerate")) != -1)
	{
		AcceptEntityInput(ent, "Disable");
	}
}
