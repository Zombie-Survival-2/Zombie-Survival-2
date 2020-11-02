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
		DebugText("Map script located");
		char strval[64] = "";
		serverdata.GetString("cp_intro", strval, sizeof(strval));
		if (!StrEqual(strval, ""))
		{
			DebugText("CP intro music located");
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i))
					EmitSoundToClient(i, strval, i);
			}
		}
	}
}
