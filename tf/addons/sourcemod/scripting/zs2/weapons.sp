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

public void Weapons_AlterPlayerWeapons(int client)
{
	if (wIndexes == null || !wIndexes.Length)
		return;

	for (int i = 0; i < 6; i++)
	{
		int weapon = GetPlayerWeaponSlot(client, i);
		if (weapon == -1)
			continue;

		int weaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		int arrayIndex = wIndexes.FindValue(weaponIndex);

		if (arrayIndex != -1)
		{
			int replacingIndex = wReplace.Get(arrayIndex);
			char att[128], name[32];
			wAttributes.GetString(arrayIndex, att, sizeof(att));

			if (replacingIndex > 0) // redundant check (?)
			{
				SpawnWeapon(client, replacingIndex, att);
				TF2Econ_GetItemName(weaponIndex, name, sizeof(name));
				CPrintToChat(client, "%s Blocked {haunted}'%s'.", MESSAGE_PREFIX, name);
			}
			else if (!StrEqual(att, ""))
			{
				DebugText("Settings attributes on %i", weaponIndex);
				char atts[32][32], attr[64];
				int count = ExplodeString(att, " ; ", atts, 32, 32);
				if (count > 1)
				{
					for (int j = 0; j < count; j += 2)
					{
						TF2Econ_GetAttributeName(StringToInt(atts[j]), attr, sizeof(attr));
						TF2Attrib_SetByName(weapon, attr, StringToFloat(atts[j + 1]));
						DebugText("Attr %s, val %f", attr, StringToFloat(atts[j + 1]));
					}
				}
			}
		}
	}
}

void SpawnWeapon(int client, int defIndex, const char[] att)
{
	int ent = TF2Items_GiveWeapon(client, defIndex);

	char atts[32][32], attr[64];
	int count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 1)
	{
		for (int j = 0; j < count; j += 2)
		{
			TF2Econ_GetAttributeName(StringToInt(atts[j]), attr, sizeof(attr));
			TF2Attrib_SetByName(ent, attr, StringToFloat(atts[j + 1]));
			DebugText("Attr %s, val %f", attr, StringToFloat(atts[j + 1]));
		}
	}
}
