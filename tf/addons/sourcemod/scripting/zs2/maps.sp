void Maps_Initialise()
{
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	char mapScriptPath[128];
	Format(mapScriptPath, sizeof(mapScriptPath), "scripts/zs2/%s.json", mapName);
	allowedRoundTypes = new ArrayList(ByteCountToCells(16));
	if (FileExists(mapScriptPath))
	{
		DebugText("JSON file found");
		char mapScriptText[1024];
		File mapScriptFile = OpenFile(mapScriptPath, "r");
		mapScriptFile.ReadString(mapScriptText, sizeof(mapScriptText));
		mapScriptFile.Close();
		JSON_Object mapScript = json_decode(mapScriptText);
		// Booleans reversed because default is false
		attackTeamSwap = !mapScript.GetBool("cp_a_donotswap");
		autoHandleDoors = !mapScript.GetBool("ent_noautodoors");
		freezeInSetup = !mapScript.GetBool("donotfreeze");
		int intval = mapScript.GetInt("t_round");
		if (intval > 0)
			roundDuration = intval;
		else
		{
			DebugText("Round time out of bounds or not found, using default");
			roundDuration = 300;
		}
		intval = mapScript.GetInt("t_setup");
		if (intval > 0)
			setupDuration = intval;
		else
		{
			DebugText("Setup time out of bounds or not found, using default");
			setupDuration = 30;
		}
		intval = mapScript.GetInt("t_cp_minus");
		if (intval >= 0)
		{
			roundDurationCP = roundDuration - intval;
			if (roundDurationCP < 0)
				roundDurationCP = 0;
		}
		else
		{
			DebugText("CP time penalty out of bounds, disabled");
			roundDurationCP = roundDuration;
		}
		intval = mapScript.GetInt("t_cp_bonus");
		if (intval >= 0)
			objectiveBonus = intval;
		else
		{
			DebugText("Objective bonus time out of bounds, disabled");
			objectiveBonus = 0;
		}
		if (!mapScript.GetString("cp_intro", introCP, sizeof(introCP)))
		{
			DebugText("No definition for CP intro music found, disabled");
			introCP = "";
		}
		if (!mapScript.GetString("st_intro", introST, sizeof(introST)))
		{
			DebugText("No definition for ST intro music found, disabled");
			introST = "";
		}
		if (mapScript.GetBool("cp_a"))
			allowedRoundTypes.PushString("Attack");
		if (mapScript.GetBool("cp_d"))
			allowedRoundTypes.PushString("Defend");
		if (mapScript.GetBool("st_s"))
		{
			allowedRoundTypes.PushString("Survival");
			roundType = Game_Survival;
		}
		else
			SetDefaultRoundType();
		json_cleanup_and_delete(mapScript);
	}
	else
	{
		DebugText("JSON file not found, using defaults");
		freezeInSetup = true;
		attackTeamSwap = true;
		roundDuration = 300;
		setupDuration = 30;
		introCP = "";
		introST = "";
		for (int i = 0; i < sizeof(roundTypeStrings); i++)
			allowedRoundTypes.PushString(roundTypeStrings[i]);
		roundType = Game_Survival;
	}
}
