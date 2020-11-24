// CFG-controlled variables

ArrayList g_aWeapons;

enum struct WeaponConfig
{
	int defIndex;
	int replaceIndex;
	char sAttrib[256];
}

stock void Weapons_Initialise()
{
	char sPath[128], section[16];
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
		int iIndex = -1;

		if (StringToIntEx(section, iIndex) == 0)
		{
			LogError("Invalid index \"%s\" at Weapons config section", section);
		}
		else
		{
			WeaponConfig weapon;
			weapon.defIndex = iIndex;
			weapon.replaceIndex = kv.GetNum("replace", -1);
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

	int team = GetClientTeam(client);
	if (team == TEAM_ZOMBIES)
	{		
		OnlyMelee(client);
		RemoveWearable(client);
	}
	
	for (int iSlot = 0; iSlot < 6; iSlot++)
	{
		int iEntity = GetPlayerWeaponSlot(client, iSlot);
		if (iEntity > MaxClients)
		{
			int iIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
			
			for (int i = 0; i < g_aWeapons.Length; i++)
			{
				WeaponConfig wep;
				g_aWeapons.GetArray(i, wep, sizeof(wep));
				
				if (wep.defIndex == iIndex)
				{
					if (wep.replaceIndex > -1)
					{
						TF2_RemoveWeaponSlot(client, iSlot);
						iEntity = TF2Items_GiveWeapon2(client, wep.replaceIndex);
					}

					char sAttribs[32][32];
					int iCount = ExplodeString(wep.sAttrib, " ; ", sAttribs, sizeof(sAttribs), sizeof(sAttribs));
					if (iCount > 1)
						for (int j = 0; j < iCount; j+= 2)
							TF2Attrib_SetByDefIndex(iEntity, StringToInt(sAttribs[j]), StringToFloat(sAttribs[j+1]));
					
					break;
				}
			}
			
			TF2Attrib_ClearCache(iEntity); // This will refresh health max calculation and other attributes
		}
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

	return Plugin_Continue;
}

stock int TF2Items_GiveWeapon2(const int client, const int iItemDefinitionIndex)
{
	TFClassType iClass = TF2_GetPlayerClass(client);
	char sClassname[256];
	TF2Econ_GetItemClassName(iItemDefinitionIndex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), iClass);
	
	/*int iSubType;
	if ((StrEqual(sClassname, "tf_weapon_builder") || StrEqual(sClassname, "tf_weapon_sapper")) && iClass == TFClass_Spy)
	{
		iSubType = view_as<int>(TFObject_Sapper);
		sClassname = "tf_weapon_builder";
	}*/
	
	int iWeapon = CreateEntityByName(sClassname);
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iItemDefinitionIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", true);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 0);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
			
		/*if (iSubType)
		{
			SetEntProp(iWeapon, Prop_Send, "m_iObjectType", iSubType);
			SetEntProp(iWeapon, Prop_Data, "m_iSubType", iSubType);
		}*/
	}
	
	if (IsValidEntity(iWeapon))
	{
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true); // Make weapon visible
		EquipPlayerWeapon(client, iWeapon);
	}
	
	return iWeapon;
}
