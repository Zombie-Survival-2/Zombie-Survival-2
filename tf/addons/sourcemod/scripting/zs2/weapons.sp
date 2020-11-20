// https://github.com/War3Evo/TF2-Super-Smash-Bros/

// CFG-controlled variables
wIndex = CreateArray(1);
wOldWeapon = CreateArray(ByteCountToCells(64));
wNewWeapon = CreateArray(ByteCountToCells(64));
wWeaponIndex = CreateArray(1);
wWeaponLevel = CreateArray(1);
wWeaponQuality = CreateArray(1);
wWeaponAttribute = CreateArray(ByteCountToCells(64));
wBlockList = CreateArray(ByteCountToCells(64));

public void Weapons_Initialise()
{
	Handle kv = Weapons_ReadFile();
	if (kv != null)
	{
		// Initialise variables and file
		Weapons_ClearArrays();
		KvRewind(kv);
		bool needToSwapWeapon = false;
		char sSectionBuffer[32];
		char sSubKeyBuffer[32];
		char old_weapon[64];
		char new_weapon[64];
		int WeaponIndex = 0;
		int WeaponLevel = 0;
		int WeaponQuality = 0;
		char WeaponAttribute[64];
		// Read through file
		do
		{
			if (KvGotoFirstSubKey(kv, false))
			{
				do
				{
					// Check for weapons that need to be swapped
					if (KvGetSectionName(kv, sSectionBuffer, sizeof(sSectionBuffer)))
					{
						if (!needToSwapWeapon && StrContains(sSubKeyBuffer,"switch") == 0)
						{
							if (KvGetNum(kv, NULL_STRING) == 1)
							{
								needToSwapWeapon = true;
							}
						}
					}
					// Push swap information to arrays
					if (needToSwapWeapon)
					{
						if (StrContains(sSubKeyBuffer,"old weapon") == 0)
							KvGetString(kv, NULL_STRING, STRING(old_weapon), "");
						if (StrContains(sSubKeyBuffer,"new weapon") == 0)
							KvGetString(kv, NULL_STRING, STRING(new_weapon), "");
						if (StrContains(sSubKeyBuffer,"index") == 0)
							WeaponIndex = KvGetNum(kv, NULL_STRING, 0);
						if (StrContains(sSubKeyBuffer,"level") == 0)
							WeaponLevel = KvGetNum(kv, NULL_STRING, 1);
						if (StrContains(sSubKeyBuffer,"quality") == 0)
							WeaponQuality = KvGetNum(kv, NULL_STRING, 0);
						if (StrContains(sSubKeyBuffer,"attribute") == 0)
							KvGetString(kv, NULL_STRING, STRING(WeaponAttribute), "");
						PushArrayCell(wIndex, 0);
						PushArrayString(wOldWeapon, old_weapon);
						PushArrayString(wNewWeapon, new_weapon);
						PushArrayCell(wWeaponIndex, WeaponIndex);
						PushArrayCell(wWeaponLevel, WeaponLevel);
						PushArrayCell(wWeaponQuality, WeaponQuality);
						PushArrayString(wWeaponAttribute, WeaponAttribute);
						needToSwapWeapon = false;
						strcopy(old_weapon, sizeof(old_weapon), "");
						strcopy(new_weapon, sizeof(new_weapon), "");
						strcopy(WeaponAttribute, sizeof(WeaponAttribute), "");
						WeaponIndex = 0;
						WeaponLevel = 0;
						WeaponQuality = 0;
					}
				} while (KvGotoNextKey(kv, false));
				KvGoBack(kv);
			}
			needToSwapWeapon = false;
		} while (KvGotoNextKey(kv, false));
	}
	CloseHandle(kv);
}

public void Weapons_AlterPlayerWeapons(int client)
{
	Handle kv = Weapons_ReadFile();
	if (kv != null)
	{
		int weapon_index = 0;
		int weapon_entity = 0;
		for (int i = 0; i < 6; i++)
		{
			weapon_entity = GetPlayerWeaponSlot(client, i);
			if (weapon_entity > MaxClients)
			{
				weapon_index = GetEntProp(GetPlayerWeaponSlot(client, i), Prop_Send, "m_iItemDefinitionIndex");
				if (weapon_index > -1)
				{
					Weapons_AlterWeapon(kv, client, weapon_index, weapon_entity, false);
					char weapon_name[64];
					GetEntityClassname(weapon_entity, weapon_name, sizeof(weapon_name));
					int MainIndex = Weapons_CheckForSwap(wOldWeapon, weapon_name, weapon_index);
					if (MainIndex > -1)
					{
						Handle pack;
						if (CreateDataTimer(1.0, Weapons_Timer_ReplaceWeapon, pack) != null)
						{
							WritePackCell(pack, client);
							WritePackCell(pack, MainIndex);
						}
					}
				}
			}
		}
	}
	CloseHandle(kv);
}

int Weapons_CheckForSwap(Handle hString, char[] WeaponString, int iItemDefinitionIndex)
{
	int MainIndex = FindStringInArray(hString, WeaponString);
	if (MainIndex == -1)
	{
		char tmpWeaponString[64];
		IntToString(iItemDefinitionIndex, STRING(tmpWeaponString));
		MainIndex = FindStringInArray(hString, tmpWeaponString);
	}
	return MainIndex;
}

Action Weapons_Timer_ReplaceWeapon(Handle timer, Handle datapack)
{
	ResetPack(datapack);
	int client = ReadPackCell(datapack);
	int MainIndex = ReadPackCell(datapack);
	if (!IsValidClient(client))
		return Plugin_Continue;
	char new_weapon[64];
	GetArrayString(h_New_Weapon_String, MainIndex, STRING(new_weapon));
	if (StrEqual("", new_weapon))
		return Plugin_Continue;
	int WeaponIndex = GetArrayCell(h_WeaponIndex, MainIndex);
	int WeaponLevel = GetArrayCell(h_WeaponLevel, MainIndex);
	int WeaponQuality = GetArrayCell(h_WeaponQuality, MainIndex);
	char WeaponAttribute[64];
	GetArrayString(h_WeaponAttribute, MainIndex, STRING(WeaponAttribute));
	int iweapon = Weapons_ReplaceWeaponSpawn(client, new_weapon, WeaponIndex, WeaponLevel, WeaponQuality, WeaponAttribute);
	return Plugin_Continue;
}

stock Weapons_ReplaceWeaponSpawn(client, char[] name, index, level, qual, char[] att)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWeapon == INVALID_HANDLE)
		return -1;
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 1)
	{
		TF2Items_SetNumAttributes(hWeapon, count / 2);
		int i2 = 0;
		for (int i = 0; i < count; i += 2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	stock entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

Handle Weapons_ReadFile()
{
	// Attempt to read CFG file
	char path[1024] = "addons/configs/zs2_weapons.cfg";
	Handle kv = CreateKeyValues("TF2_ZS2_WEAPONS");
	if (!FileToKeyValues(kv, path))
	{
		CloseHandle(kv);
		return null;
	}
	return kv;
}

void Weapons_ClearArrays()
{
	ClearArray(wIndex);
	ClearArray(wOldWeapon);
	ClearArray(wNewWeapon);
	ClearArray(wWeaponIndex);
	ClearArray(wWeaponLevel);
	ClearArray(wWeaponQuality);
	ClearArray(wWeaponAttribute);
}
