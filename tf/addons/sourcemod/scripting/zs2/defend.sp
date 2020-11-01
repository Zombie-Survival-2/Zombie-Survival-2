public void Defend_RoundStart()
{
	CP_IntroMusic();
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
		// Handle plugin-specific music
		if (strval[0] == "-")
		{
			strval = CP_DefaultIntroMusic(strval);
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

char[] CP_DefaultIntroMusic(char[] strval)
{
	if (strval == "-bloodharvest")
		strval = "zs2/intro_cp/bloodharvest.mp3";
	else if (strval == "-crashcourse")
		strval = "zs2/intro_cp/crashcourse.mp3";
	else if (strval == "-deadair")
		strval = "zs2/intro_cp/deadair.mp3";
	else if (strval == "-deathtoll")
		strval = "zs2/intro_cp/deathtoll.mp3";
	else if (strval == "-nomercy")
		strval = "zs2/intro_cp/nomercy.mp3";
	return strval;
}
