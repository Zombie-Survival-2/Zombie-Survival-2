public void Defend_RoundStart()
{
	CP_IntroMusic();
	CP_EnableObjectives();
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
	if (!StrEqual(introCP, ""))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
				EmitSoundToClient(i, introCP, i);
		}
	}
}

void CP_EnableObjectives()
{
	int ent = -1;
	
	for (int i = 0; i < sizeof(objectiveEntities); i++)
	{
		char classname[32];
		while ((ent = FindEntityByClassname(ent, objectiveEntities[i])) != -1)
		{
			AcceptEntityInput(ent, "Enable");
			GetEdictClassname(ent, classname, sizeof(classname));
			// Prevent RED team from capturing control points
			if (StrEqual(classname, "trigger_capture_area"))
			{
				SetVariantString("2 0");
				AcceptEntityInput(ent, "SetTeamCanCap");
			}
			// Disable BLU-owned intelligence
			if (StrEqual(classname, "item_teamflag"))
			{
				if (GetEntProp(ent, Prop_Send, "m_iTeamNum") == 3)
					AcceptEntityInput(ent, "Kill");
			}
		}
	}
}
