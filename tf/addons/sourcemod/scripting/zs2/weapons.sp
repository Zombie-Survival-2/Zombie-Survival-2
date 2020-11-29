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
			count = 1;
			strcopy(strings[0], sizeof(strings[]), section);
		}

		for (int i = 0; i < count; i++)
		{
			int iIndex = StringToInt(strings[i]);
			WeaponConfig weapon;
			weapon.defIndex = StringToInt(strings[i]);
			weapon.replaceIndex = kv.GetNum("replace", -1);
			kv.GetString("attributes", weapon.sAttrib, sizeof(weapon.sAttrib), "");
			if (weapon.replaceIndex != -1)
				iIndex = weapon.replaceIndex;

			int flags = OVERRIDE_ATTRIBUTES | OVERRIDE_CLASSNAME | OVERRIDE_ITEM_DEF;
			weapon.hWeapon = TF2Items_CreateItem(flags);
			char sClassname[256];
			TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
			TF2Items_SetClassname(weapon.hWeapon, sClassname);
			TF2Items_SetItemIndex(weapon.hWeapon, iIndex);

			int i2 = 0;
			if (weapon.sAttrib[0] != '\0')
			{
				if (weapon.defIndex != 998)
					flags |= PRESERVE_ATTRIBUTES;

				char sAttribs[32][32];
				int iCount = ExplodeString(weapon.sAttrib, " ; ", sAttribs, sizeof(sAttribs), sizeof(sAttribs));
				if (iCount > 1)
				{
					TF2Items_SetNumAttributes(weapon.hWeapon, iCount / 2);

					for (int j = 0; j < iCount; j+= 2)
					{
						TF2Items_SetAttribute(weapon.hWeapon, i2, StringToInt(sAttribs[j]), StringToFloat(sAttribs[j+1]));
						i2++;
					}
				}
			}

			if (iIndex == weapon.replaceIndex)
			{
				DebugText("%i num attribs before we started", i2);
				int attribId[16];
				float attribVal[16];
				int iCount = TF2Attrib_GetStaticAttribs(iIndex, attribId, attribVal);
				iCount /= 2;

				for (int j = 0; j < iCount; j++)
				{
					TF2Items_SetAttribute(weapon.hWeapon, i2, attribId[j], attribVal[j]);
					i2++;
				}

				DebugText("%i num attribs after", i2);
				TF2Items_SetNumAttributes(weapon.hWeapon, i2);	
			}

			TF2Items_SetFlags(weapon.hWeapon, flags);
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

	int team = GetClientTeam(client);
	if (team == TEAM_ZOMBIES)
	{		
		OnlyMelee(client);
		RemoveWearable(client);
	}

	if (team == TEAM_SURVIVORS)
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 0));
	else
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
			Handle hItemOverride = PrepareItemHandle(iItemDefinitionIndex, wep.replaceIndex, wep.sAttrib);

			if (hItemOverride != null) // if it's null then :(
			{
				hItem = hItemOverride;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

stock Handle PrepareItemHandle(int defIndex, int replaceIndex, const char[] sAttrib)
{
	static Handle hWeapon = null;
	int flags = OVERRIDE_ATTRIBUTES, count = 0;
	int attribId[16];
	float attribVal[16];
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
		TF2Items_SetClassname(hWeapon, classname);

		count = TF2Attrib_GetStaticAttribs(replaceIndex, attribId, attribVal);
		count /= 2;
	}
	else if (defIndex != 998) // we are not preserving attributes for vaccinator
	{
		flags |= PRESERVE_ATTRIBUTES;
	}

	if (attribCount > 1)
	{
		for (int i = count, i2 = 0; i < 16 && i2 < attribCount; i++, i2+=2)
		{
			attribId[i] = StringToInt(weaponAttribsArray[i2]);
			attribVal[i] = StringToFloat(weaponAttribsArray[i2 + 1]);
			count++;
		}
	}

	TF2Items_SetNumAttributes(hWeapon, count);
	for (int i = 0; i < count; i++)
	{
		TF2Items_SetAttribute(hWeapon, i, attribId[i], attribVal[i]);
	}

	TF2Items_SetFlags(hWeapon, flags);
	return hWeapon;
}
