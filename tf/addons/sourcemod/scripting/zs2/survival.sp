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
}
