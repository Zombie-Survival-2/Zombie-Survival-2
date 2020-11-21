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
	DebugText("Initialising weapon replacement and custom attributes");
	wIndexes = new ArrayList();
	wReplace = new ArrayList();
	wAttributes = new ArrayList(ByteCountToCells(128));
	KeyValues kv = new KeyValues("TF2_ZS2_WEAPONS");
	kv.ImportFromFile(sPath);
	kv.GotoFirstSubKey();
	do
	{
		kv.GetSectionName(section, sizeof(section));
		DebugText("Weapon ID %s detected", section);
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
			char att[128];
			wAttributes.GetString(arrayIndex, att, sizeof(att));
			if (replacingIndex > 0)
			{
				DebugText("Replacing player %i's weapon with index %i", client, replacingIndex);
				SpawnWeapon(client, replacingIndex, att);
			}
			else if (!StrEqual(att, ""))
			{
				DebugText("Updating player %i's weapon with new attributes", client);
				SpawnWeapon(client, weaponIndex, att);
			}
		}
	}
}

int SpawnWeapon(int client, int defIndex, const char[] att)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
	if (hWeapon == INVALID_HANDLE)
	{
		DebugText("Invalid handle");
		return -1;
	}
	TF2Items_SetItemIndex(hWeapon, defIndex);
	char name[64];
	TF2Econ_GetItemClassName(defIndex, name, sizeof(name));
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetLevel(hWeapon, 30);
	TF2Items_SetQuality(hWeapon, 6);
	char atts[32][32];
	int count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 1)
	{
		DebugText("Custom attributes listed");
		TF2Items_SetNumAttributes(hWeapon, count / 2);
		int i2 = 0;
		for (int i = 0; i < count; i += 2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i + 1]));
			i2++;
		}
	}
	else
	{
		DebugText("No attributes listed");
		TF2Items_SetNumAttributes(hWeapon, 0);
	}
	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}
