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
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/zs2_g_aWeapons.cfg");
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
		WeaponConfig weapon;
		kv.GetSectionName(section, sizeof(section));
		weapon.defIndex = StringToInt(section);
		weapon.replaceIndex = kv.GetNum("replace", -1);
		kv.GetString("attributes", weapon.sAttrib, sizeof(weapon.sAttrib), "");

		g_aWeapons.PushArray(weapon);
	} 
	while (kv.GotoNextKey());
	kv.Rewind();
	delete kv;
}

stock void WeaponCheck(int client)
{
	for(int slot = 0; slot < 6; slot++)
	{
		int iEntity = GetPlayerWeaponSlot(client, slot);
		if (iEntity <= MaxClients)
		{
			continue;
		}

		int iItemDefinitionIndex = GetEntProp(iEntity, Prop_Send, "m_iItemDefinitionIndex");
		for (int i = 0; i < g_aWeapons.Length; i++)
		{
			WeaponConfig weapon;
			g_aWeapons.GetArray(i, weapon, sizeof(weapon));
			if (weapon.defIndex == iItemDefinitionIndex)
			{
				if (weapon.replaceIndex != -1)
				{
					char itemName[32];
					TF2Econ_GetItemName(weapon.defIndex, itemName, sizeof(itemName));
					TF2_RemoveWeaponSlot(client, slot);
					iEntity = TF2Items_GiveWeapon2(client, weapon.replaceIndex);
					CPrintToChat(client, "%s Blocked {haunted}'%s'.", MESSAGE_PREFIX, itemName);
				}

				if (!StrEqual(weapon.sAttrib, ""))
				{
					char atts[32][32];
					int count = ExplodeString(weapon.sAttrib, " ; ", atts, sizeof(atts), sizeof(atts[]));
					if (count > 1)
					{
						for (int j = 0; j < count; j += 2)
						{
							TF2Attrib_SetByDefIndex(iEntity, StringToInt(atts[j]), StringToFloat(atts[j + 1]));
						}
					}
				}

				break;
			}
		}
	}
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
		ArrayList attributes = TF2Econ_GetItemStaticAttributes(iItemDefinitionIndex);
		for (int i = 0; i < attributes.Length; i++)
		{
			TF2Attrib_SetByDefIndex(iWeapon, attributes.Get(i, 0), attributes.Get(i, 1));
		}
		
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true); // Make weapon visible
		EquipPlayerWeapon(client, iWeapon);
	}
	
	return iWeapon;
}
