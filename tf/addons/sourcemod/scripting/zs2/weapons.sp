// CFG-controlled variables

ArrayList g_aWeapons;

enum struct WeaponConfig
{
	int defIndex;
	int replaceIndex;
	char sAttrib[256];
	Handle hWeapon;
}

stock void Weapons_Initialise()
{
	char sPath[128], section[512];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/zs2_weapons.cfg");
	if (!FileExists(sPath))
	{
		LogError("%s Could not find file %s.", MESSAGE_PREFIX_NO_COLOR, sPath);
		return;
	}

	g_aWeapons = new ArrayList(sizeof(WeaponConfig));
	KeyValues kv = new KeyValues("TF2_ZS2_WEAPONS");

	kv.ImportFromFile(sPath);
	kv.GotoFirstSubKey();
	do 
	{
		kv.GetSectionName(section, sizeof(section));

		char strings[32][16];
		int count;
		if (StringToIntEx(section, count) != strlen(section))		// string is not a number
		{
			count = ExplodeString(section, " ; ", strings, sizeof(strings), sizeof(strings[]));
		}
		else 
		{
			count = 1;
			strcopy(strings[0], sizeof(strings[]), section);
		}

		for(int i = 0; i < count; i++)
		{
			int iIndex = StringToInt(strings[i]);
			WeaponConfig weapon;
			weapon.defIndex = iIndex;
			weapon.replaceIndex = kv.GetNum("replace", -1);
			kv.GetString("attributes", weapon.sAttrib, sizeof(weapon.sAttrib), "");
			if(weapon.replaceIndex != -1)
				iIndex = weapon.replaceIndex;

			weapon.hWeapon = TF2Items_CreateItem(OVERRIDE_ALL);
			char sClassname[256];
			TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
			TF2Items_SetClassname(weapon.hWeapon, sClassname);
			TF2Items_SetItemIndex(weapon.hWeapon, iIndex);
			TF2Items_SetQuality(weapon.hWeapon, 0);

			if(weapon.sAttrib[0])
			{
				char sAttribs[32][32];
				int iCount = ExplodeString(weapon.sAttrib, " ; ", sAttribs, sizeof(sAttribs), sizeof(sAttribs));
				int i2 = 0;
				if (iCount > 1)
				{
					for (int j = 0; j < iCount; j+= 2)
					{
						TF2Items_SetAttribute(weapon.hWeapon, i2, StringToInt(sAttribs[j]), StringToFloat(sAttribs[j+1]));
						i2++;
					}
				}
				TF2Items_SetNumAttributes(weapon.hWeapon, iCount / 2);	
			}
			else
			{
				ArrayList attributes = TF2Econ_GetItemStaticAttributes(iIndex);
				for (int j = 0; j < attributes.BlockSize; j++)
				{
					TF2Items_SetAttribute(weapon.hWeapon, j, attributes.Get(j, 0), attributes.Get(j, 1));
				}
				DebugText("%i num attribs %i", iIndex, attributes.BlockSize);
				TF2Items_SetNumAttributes(weapon.hWeapon, attributes.BlockSize);	
				delete attributes;
			}

			if(StrEqual(sClassname, "tf_weapon_flamethrower"))		// prevents weapon bug
			{
				TF2Items_SetFlags(weapon.hWeapon, OVERRIDE_ALL | PRESERVE_ATTRIBUTES);
			}

			g_aWeapons.PushArray(weapon);
		}
	}

	while (kv.GotoNextKey());
	kv.Rewind();
	delete kv;
}

stock void WeaponCheck(int client)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client))
		return;

	if (GetClientTeam(client) == TEAM_ZOMBIES)
	{		
		OnlyMelee(client);
		RemoveWearable(client);
	}

	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 2));
}

stock void OnlyMelee(const int client)
{
	TF2_RemoveWeaponSlot(client, 0);
	TF2_RemoveWeaponSlot(client, 1);
}

stock void RemoveWearable(const int client)
{
	int i = -1;
	while ((i = FindEntityByClassname(i, "tf_wearable_demoshield")) != -1)
	{
		if (client != GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity")) 
			continue;
		AcceptEntityInput(i, "Kill");
	}
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle &hItem)
{
	switch (iItemDefinitionIndex)
	{
		case 735, 736, 810, 831, 933, 1080, 1102:	// Sappers
		{
			return Plugin_Handled;
		}
	}

	for (int i = 0; i < g_aWeapons.Length; i++)
	{
		WeaponConfig wep;
		g_aWeapons.GetArray(i, wep, sizeof(wep));

		if (wep.defIndex == iItemDefinitionIndex)
		{
			hItem = wep.hWeapon;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}