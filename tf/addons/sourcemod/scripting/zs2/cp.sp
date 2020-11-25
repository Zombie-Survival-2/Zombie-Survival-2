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

void CP_SetupObjectives()
{
	int ent = -1;
	for (int i = 0; i < sizeof(objectiveEntities); i++)
	{
		char classname[32];
		while ((ent = FindEntityByClassname(ent, objectiveEntities[i])) != -1)
		{
			GetEdictClassname(ent, classname, sizeof(classname));
			// Prevent defending team from capturing control points
			if (StrEqual(classname, "trigger_capture_area"))
			{
				if (roundType == Game_Attack && !attackTeamSwap)
					SetVariantString("3 0");
				else
					SetVariantString("2 0");
				AcceptEntityInput(ent, "SetTeamCanCap");
			}
			// Disable attacking team's intelligence
			if (StrEqual(classname, "item_teamflag"))
			{
				if (roundType == Game_Attack && !attackTeamSwap)
				{
					if (GetEntProp(ent, Prop_Send, "m_iTeamNum") == TEAM_RED)
						AcceptEntityInput(ent, "Kill");
				}
				else
				{
					if (GetEntProp(ent, Prop_Send, "m_iTeamNum") == TEAM_BLUE)
						AcceptEntityInput(ent, "Kill");
				}
			}
		}
	}
}
