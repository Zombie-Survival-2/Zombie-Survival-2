public void Survival_RoundStart()
{
	ST_IntroMusic();
	ST_DisableObjectives();
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
		// Handle plugin-specific music
		if (strval[0] == "-")
		{
			strval = ST_DefaultIntroMusic(strval);
			if (strval[0] != "-")
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
						EmitSoundToClient(i, strval, i);
				}
			}
		}
		// Handle map-specific music
		else if (strval != "")
		{
		
		}
	}
}

char[] ST_DefaultIntroMusic(char[] strval)
{
	if (strval == "-bloodharvest")
		strval = "zs2/intro_st/bloodharvest_m22050.wav";
	else if (strval == "-crashcourse")
		strval = "zs2/intro_st/crashcourse_m22050.wav";
	else if (strval == "-darkcarnival")
		strval = "zs2/intro_st/darkcarnival_m22050.wav";
	else if (strval == "-deathtoll")
		strval = "zs2/intro_st/deathtoll_m22050.wav";
	else if (strval == "-hardrain")
		strval = "zs2/intro_st/hardrain_m22050.wav";
	else if (strval == "-nomercy")
		strval = "zs2/intro_st/nomercy_m22050.wav";
	else if (strval == "-swampfever")
		strval = "zs2/intro_st/swampfever_m22050.wav";
	return strval;
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
