public void Defend_RoundStart()
{
	TEAM_SURVIVORS = 2;
	TEAM_ZOMBIES = 3;

	CP_IntroMusic();
	CP_SetupObjectives();
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
