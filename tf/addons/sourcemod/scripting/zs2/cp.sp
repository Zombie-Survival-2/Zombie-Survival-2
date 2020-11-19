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
			// Prevent RED team from capturing control points
			if (StrEqual(classname, "trigger_capture_area"))
			{
				SetVariantString("2 0");
				AcceptEntityInput(ent, "SetTeamCanCap");
			}
			// Disable BLU team's intelligence
			if (StrEqual(classname, "item_teamflag"))
			{
				if (GetEntProp(ent, Prop_Send, "m_iTeamNum") == 3)
					AcceptEntityInput(ent, "Kill");
			}
		}
	}
}
