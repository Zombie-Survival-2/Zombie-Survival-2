public void Survival_RoundStart()
{
	ST_IntroMusic();
	ST_DisableObjectives();
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
	if (!StrEqual(introST, ""))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
				EmitSoundToClient(i, introST, i);
		}
	}
}

void ST_DisableObjectives()
{
	int ent = -1;
	
	for (int i = 0; i < sizeof(objectiveEntities); i++)
	{
		while ((ent = FindEntityByClassname(ent, objectiveEntities[i])) != -1)
			AcceptEntityInput(ent, "Disable");
	}
}
