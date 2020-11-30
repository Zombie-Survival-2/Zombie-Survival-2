// CFG-controlled variables

ArrayList g_aWeapons;

enum struct WeaponConfig
{
	int defIndex;
	int replaceIndex;
	char sAttrib[256];
	bool deleteAttrib;
}

stock void Weapons_Initialise()
{
	g_aWeapons = new ArrayList(sizeof(WeaponConfig));
}

stock void Weapons_Refresh()
{
	char sPath[128], section[512];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/zs2_weapons.cfg");
	if (!FileExists(sPath))
	{
		LogError("%s Could not find file %s.", MESSAGE_PREFIX_NO_COLOR, sPath);
		return;
	}

	g_aWeapons.Clear();

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
			WeaponConfig weapon;
			weapon.defIndex = StringToInt(strings[i]);
			weapon.replaceIndex = kv.GetNum("replace", -1);
			weapon.deleteAttrib = view_as<bool>(kv.GetNum("deleteAttribs", 0));
			kv.GetString("attributes", weapon.sAttrib, sizeof(weapon.sAttrib), "");
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

stock void OnlyMelee(int client)
{
	TF2_RemoveWeaponSlot(client, 0);
	TF2_RemoveWeaponSlot(client, 1);
}

stock void RemoveWearable(int client)
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
			Handle hItemOverride = PrepareItemHandle(client, iItemDefinitionIndex, wep.replaceIndex, wep.sAttrib, wep.deleteAttrib);

			if (hItemOverride != null) // if it's null then :(
			{
				hItem = hItemOverride;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

stock Handle PrepareItemHandle(int client, int defIndex, int replaceIndex, const char[] sAttrib, bool deleteAttrib)
{
	static Handle hWeapon = null;
	int flags = OVERRIDE_ATTRIBUTES;
	char weaponAttribsArray[32][32];
	int attribCount = ExplodeString(sAttrib, " ; ", weaponAttribsArray, 32, 32);

	if (hWeapon == null)
		hWeapon = TF2Items_CreateItem(flags);
	else 
		TF2Items_SetFlags(hWeapon, flags);

	if (replaceIndex != -1)
	{
		flags |= OVERRIDE_ITEM_DEF;
		TF2Items_SetItemIndex(hWeapon, replaceIndex);

		flags |= OVERRIDE_CLASSNAME;
		char classname[128];
		TF2Econ_GetItemClassName(replaceIndex, classname, sizeof(classname));
		TF2Econ_TranslateWeaponEntForClass(classname, sizeof(classname), TF2_GetPlayerClass(client));
		TF2Items_SetClassname(hWeapon, classname);
	}
	else if(!deleteAttrib) // if we are not changing weapon and we save attributes
	{
		flags |= PRESERVE_ATTRIBUTES;
	}

	if(1 < attribCount < 32)
	{
		TF2Items_SetNumAttributes(hWeapon, attribCount / 2);
		int count;

		for (int i2 = 0; i2 < attribCount; i2 += 2)
		{
			TF2Items_SetAttribute(hWeapon, count++, StringToInt(weaponAttribsArray[i2]), StringToFloat(weaponAttribsArray[i2 + 1]));
		}
	}
	else 
	{
		TF2Items_SetNumAttributes(hWeapon, 0);
	}

	TF2Items_SetFlags(hWeapon, flags);
	return hWeapon;
}
