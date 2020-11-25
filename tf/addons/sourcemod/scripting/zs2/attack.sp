public void Attack_RoundStart()
{
	if (attackTeamSwap)
	{
		TEAM_SURVIVORS = TEAM_BLUE;
		TEAM_ZOMBIES = TEAM_RED;
	}
	else
	{
		TEAM_SURVIVORS = TEAM_RED;
		TEAM_ZOMBIES = TEAM_BLUE;
	}

	CP_IntroMusic();
	CP_SetupObjectives();
}

public void Attack_RoundStartPost()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (GetClientTeam(i) == TEAM_SURVIVORS)
				CPrintToChat(i, "%s {normal}Attack: {haunted}You must capture the objective to win. The time limit is no longer on your side! ", MESSAGE_PREFIX);
			else
				CPrintToChat(i, "%s {normal}Attack: {haunted}The survivors are trying to capture the objective. Push them back as much as possible!", MESSAGE_PREFIX);
		}
	}
}
