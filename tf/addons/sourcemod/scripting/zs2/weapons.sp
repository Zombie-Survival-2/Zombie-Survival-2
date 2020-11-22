// CFG-controlled variables
ArrayList wIndexes,
	wReplace,
	wAttributes;

public void Weapons_Initialise()
{
	char sPath[128], section[16], attributes[128];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/zs2_weapons.cfg");
	if (!FileExists(sPath))
	{
		LogError("%s Could not find file %s.", MESSAGE_PREFIX_NO_COLOR, sPath);
		return;
	}
	wIndexes = new ArrayList();
	wReplace = new ArrayList();
	wAttributes = new ArrayList(ByteCountToCells(128));
	KeyValues kv = new KeyValues("TF2_ZS2_WEAPONS");
	kv.ImportFromFile(sPath);
	kv.GotoFirstSubKey();
	do
	{
		kv.GetSectionName(section, sizeof(section));
		int index = StringToInt(section);
		int replace = kv.GetNum("replace", -1);
		kv.GetString("attributes", attributes, sizeof(attributes), "");

		wIndexes.Push(index);
		wReplace.Push(replace);
		wAttributes.PushString(attributes);
	} while (kv.GotoNextKey());
	kv.Rewind();
	delete kv;
}

void OnlyMelee(const int client)
{
	TF2_RemoveWeaponSlot(client, 0);
	TF2_RemoveWeaponSlot(client, 1);
}

void RemoveWearable(int client)
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

	int slot = TF2Econ_GetItemDefaultLoadoutSlot(iItemDefinitionIndex);
	Action toReturn = Plugin_Continue;

	if(GetClientTeam(client) == TEAM_ZOMBIES && (slot == 0 || slot == 1)) 
	{ // TF2Items_OnGiveNamedItem is called before we force OnlyMelee, using this statement to prevent uneeded block weapon chat message
		return toReturn;
	}
	
	int arrayIndex = wIndexes.FindValue(iItemDefinitionIndex);

	if (arrayIndex != -1)
	{
		int replacingDefIndex = wReplace.Get(arrayIndex);
		char att[128], itemName[32];
		wAttributes.GetString(arrayIndex, att, sizeof(att));

		if (replacingDefIndex > 0)
		{
			hItem = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
			TF2Items_SetItemIndex(hItem, replacingDefIndex);
			char newClassname[64];
			TF2Econ_GetItemClassName(replacingDefIndex, newClassname, sizeof(newClassname));
			TF2Items_SetClassname(hItem, newClassname);
			TF2Items_SetLevel(hItem, 30);
			TF2Items_SetQuality(hItem, 6);

			if (StrEqual(att, "")) // If we only change weapon, NOT attributes
			{
				DebugText("ONLY changing weapon to %N", client);
				ArrayList attributes = TF2Econ_GetItemStaticAttributes(replacingDefIndex);
				TF2Items_SetNumAttributes(hItem, attributes.Length);
				for(int i = 0; i < attributes.Length; i++)
				{
					TF2Items_SetAttribute(hItem, i, attributes.Get(i, 0), attributes.Get(i, 1));
				}
			}

			toReturn = Plugin_Changed;

			TF2Econ_GetItemName(iItemDefinitionIndex, itemName, sizeof(itemName));
			CPrintToChat(client, "%s Blocked {haunted}'%s'.", MESSAGE_PREFIX, itemName);
		}

		if (!StrEqual(att, ""))
		{
			if(toReturn == Plugin_Continue) // We only change attributes, NOT weapon
			{
				DebugText("ONLY changing attributes to %N", client);
				hItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES | PRESERVE_ATTRIBUTES);
			}

			char atts[32][32];
			int count = ExplodeString(att, " ; ", atts, 32, 32);
			int i2 = 0;
			if (count > 1)
			{
				TF2Items_SetNumAttributes(hItem, count / 2);
				for (int j = 0; j < count; j += 2)
				{
					TF2Items_SetAttribute(hItem, i2, StringToInt(atts[j]), StringToFloat(atts[j + 1]));
					i2++;
				}

				toReturn = Plugin_Changed;
			}
		}
	}

	return toReturn;
}