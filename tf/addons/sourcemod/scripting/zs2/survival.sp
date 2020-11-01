public void Survival_RoundStart()
{
	char map[64];
	GetCurrentMap(map, sizeof(map));
	JSON_Object serverdata = ReadScript(map);
	if (serverdata != null)
	{
		char strval[64];
		serverdata.GetString("st_intro", strval, sizeof(strval));
		// Play this sound instead if the player count has not grown
		/* serverdata.GetString("st_sting", strval, sizeof(strval)); */
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
				EmitSoundToClient(i, strval, i);
		}
	}

	BlockCapture();
}

void BlockCapture()
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
