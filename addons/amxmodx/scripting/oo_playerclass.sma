#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <json>
#include <oo>

#pragma ctrlchar '\'

new g_oPlayerClass[MAX_PLAYERS + 1] = {@null, ...};
new g_fwChangePlayerClass, g_fwChangePlayerClassPost, g_fwRet;

// ---------- [OO Functions] ----------

public oo_init()
{
	oo_class("PlayerClassInfo")
	{
		new const cl[] = "PlayerClassInfo";
		oo_var(cl, "name", 32);
		oo_var(cl, "desc", 64);
		oo_var(cl, "player_models", 1);
		oo_var(cl, "v_models", 1);
		oo_var(cl, "p_models", 1);
		oo_var(cl, "override_sounds", 1);
		oo_var(cl, "cvars", 1);

		oo_ctor(cl, "Ctor", @str{name}, @str{desc});
		oo_dtor(cl, "Dtor");

		oo_mthd(cl, "CreateCvar", @str{prefix}, @str{name}, @str{value}, @int{flags});
		oo_mthd(cl, "LoadJson", @str{filename});
		oo_mthd(cl, "GetCvar", @str{key});
	}

	oo_class("PlayerClass");
	{
		new const cl[] = "PlayerClass";
		oo_var(cl, "player", 1);

		oo_ctor(cl, "Ctor", @int{player});
		oo_dtor(cl, "Dtor");

		oo_mthd(cl, "SetProps");
		oo_mthd(cl, "OnSetProps");
		oo_mthd(cl, "GetClassInfo");
		oo_mthd(cl, "ChangeWeaponModel", @int{ent});
		oo_mthd(cl, "ChangeSound", @int{channel}, @str{sample}, @fl{vol}, @fl{attn}, @int{flags}, @int{pitch});
		oo_mthd(cl, "ChangeMaxSpeed");
	}
}

// --------- [AMXX Forwards] ----------

public plugin_init()
{
	register_plugin("[OO] Player Class", "0.1", "holla");

	register_forward(FM_EmitSound, "OnEmitSound");
	RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "OnPlayerResetMaxspeed_Post", 1);
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", 1)

	static weaponname[32];
	for (new i = CSW_P228; i <= CSW_P90; i++)
	{
		get_weaponname(i, weaponname, charsmax(weaponname));
		if (weaponname[0])
			RegisterHam(Ham_Item_Deploy, weaponname, "OnItemDeploy_Post", 1);
	}

	g_fwChangePlayerClass = CreateMultiForward("oo_on_playerclass_change", ET_CONTINUE, FP_CELL, FP_STRING, FP_CELL);
	g_fwChangePlayerClassPost = CreateMultiForward("oo_on_playerclass_change_post", ET_IGNORE, FP_CELL, FP_STRING, FP_CELL);
}

public OnPlayerSpawn_Post(id)
{
	if (!is_user_alive(id))
		return;
	
	new class_o = g_oPlayerClass[id];
	if (class_o != @null)
		oo_call(class_o, "SetProps");
}

public OnPlayerResetMaxspeed_Post(id)
{
	new class_o = g_oPlayerClass[id];
	if (class_o != @null)
		return oo_call(class_o, "ChangeMaxSpeed") ? HAM_HANDLED : HAM_IGNORED;

	return HAM_IGNORED;
}

public OnItemDeploy_Post(ent)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED;
	
	new id = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
	if (!is_user_alive(id))
		return FMRES_IGNORED;

	new class_o = g_oPlayerClass[id];
	if (class_o != @null)
		return oo_call(class_o, "ChangeWeaponModel", ent) ? FMRES_HANDLED : FMRES_IGNORED;

	return FMRES_IGNORED;
}

public OnEmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if (!is_user_alive(id))
		return FMRES_IGNORED;

	new class_o = g_oPlayerClass[id];
	if (class_o != @null)
		return oo_call(class_o, "ChangeSound", channel, sample, volume, attn, flags, pitch) ? FMRES_SUPERCEDE : FMRES_IGNORED;

	return FMRES_IGNORED;
}

public client_putinserver(id)
{
	g_oPlayerClass[id] = @null;
}

public client_disconnected(id)
{
	if (g_oPlayerClass[id] != @null)
	{
		oo_delete(g_oPlayerClass[id]);
		g_oPlayerClass[id] = @null;
	}
}

// ---------- [AMXX Natives] ----------

public plugin_natives()
{
	register_library("oo_playerclass");

	register_native("oo_playerclass_change", "native_playerclass_change");
	register_native("oo_playerclass_get", "native_playerclass_get");
	register_native("oo_playerclass_is", "native_playerclass_is");
}

public native_playerclass_change()
{
	new id = get_param(1);
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Player (%d) is not connected", id);
		return @null;
	}

	static class[32];
	get_string(2, class, charsmax(class));

	if (class[0] == '\0')
	{
		if (g_oPlayerClass[id] != @null)
		{
			oo_delete(g_oPlayerClass[id]);
			g_oPlayerClass[id] = @null;
		}

		return g_oPlayerClass[id];
	}

	if (!oo_class_exists(class))
	{
		log_error(AMX_ERR_NATIVE, "Class (%s) does not exists", class);
		return @null;
	}

	if (!oo_subclass_of(class, "PlayerClass"))
	{
		log_error(AMX_ERR_NATIVE, "Class (%s) is not the subclass of (PlayerClass)", class);
		return @null;
	}

	return ChangePlayerClass(id, class, bool:get_param(3));
}

public native_playerclass_get()
{
	new id = get_param(1);
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Player (%d) is not connected", id);
		return @null;
	}

	return g_oPlayerClass[id];
}

public native_playerclass_is()
{
	new id = get_param(1);
	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Player (%d) is not connected", id);
		return @null;
	}

	static class[32];
	get_string(2, class, charsmax(class));

	if (g_oPlayerClass[id] == @null)
		return (class[0] == '\0') ? true : false;

	return oo_isa(g_oPlayerClass[id], class, bool:get_param(3));
}


// ---------- [OO PlayerClassInfo] ----------

public PlayerClassInfo@Ctor(const name[], const desc[])
{
	new this = oo_this();

	oo_set_str(this, "name", name);
	oo_set_str(this, "desc", desc);

	oo_set(this, "player_models", ArrayCreate(32));
	oo_set(this, "v_models", TrieCreate());
	oo_set(this, "p_models", TrieCreate());
	oo_set(this, "override_sounds", TrieCreate());
	oo_set(this, "cvars", TrieCreate());
}

public PlayerClassInfo@Dtor()
{
}

public PlayerClassInfo@CreateCvar(const prefix[], const name[], const value[], flags)
{
	new this = oo_this();

	static cvar_name[64];
	formatex(cvar_name, charsmax(cvar_name), "%s_%s", prefix, name);

	new pcvar = create_cvar(cvar_name, value, flags);
	new Trie:cvars_t = Trie:oo_get(this, "cvars");

	TrieSetCell(cvars_t, name, pcvar);
	return pcvar;
}

public PlayerClassInfo@LoadJson(const filename[])
{
	new this = oo_this();

	static filepath[96];
	get_configsdir(filepath, charsmax(filepath));
	format(filepath, charsmax(filepath), "%s/playerclass/%s.json", filepath, filename);

	new JSON:json = json_parse(filepath, true, true);
	if (json == Invalid_JSON)
		return false;
	
	static key[128], value[128];

	// player models
	new JSON:playermodels_j = json_object_get_value(json, "player_models");
	if (playermodels_j != Invalid_JSON)
	{
		new Array:models_a = Array:oo_get(this, "player_models");
		for (new i = json_array_get_count(playermodels_j) - 1; i >= 0; i--)
		{
			json_array_get_string(playermodels_j, i, value, charsmax(value));
			if (PrecachePlayerModel(value))
			{
				ArrayPushString(models_a, value);
			}
		}
		json_free(playermodels_j);
	}

	new JSON:vmodels_j = json_object_get_value(json, "v_models");
	if (vmodels_j != Invalid_JSON)
	{
		new JSON:value_j = Invalid_JSON;
		new Trie:models_t = Trie:oo_get(this, "v_models");
		for (new i = json_object_get_count(vmodels_j) - 1; i >= 0; i--)
		{
			json_object_get_name(vmodels_j, i, key, charsmax(key));
			value_j = json_object_get_value_at(vmodels_j, i);
			json_get_string(value_j, value, charsmax(value));
			json_free(value_j);
			if (file_exists(value)) // safe check
			{
				precache_model(value);
				TrieSetString(models_t, key, value);
			}
		}
		json_free(vmodels_j);
	}

	new JSON:pmodels_j = json_object_get_value(json, "p_models");
	if (pmodels_j != Invalid_JSON)
	{
		new JSON:value_j = Invalid_JSON;
		new Trie:models_t = Trie:oo_get(this, "p_models");
		for (new i = json_object_get_count(pmodels_j) - 1; i >= 0; i--)
		{
			json_object_get_name(pmodels_j, i, key, charsmax(key));
			value_j = json_object_get_value_at(pmodels_j, i);
			json_get_string(value_j, value, charsmax(value));
			json_free(value_j);
			if (file_exists(value)) // safe check
			{
				precache_model(value);
				TrieSetString(models_t, key, value);
			}
		}
		json_free(vmodels_j);
	}

	new JSON:sound_j = json_object_get_value(json, "override_sounds");
	if (sound_j != Invalid_JSON)
	{
		new Array:sounds_a = Invalid_Array;
		new JSON:value_j = Invalid_JSON;
		new Trie:sounds_t = Trie:oo_get(this, "override_sounds");
		for (new i = json_object_get_count(sound_j) - 1; i >= 0; i--)
		{
			json_object_get_name(sound_j, i, key, charsmax(key));
			value_j = json_object_get_value_at(sound_j, i);
			if (TrieGetCell(sounds_t, key, sounds_a))
			{
				ArrayDestroy(sounds_a);
				TrieDeleteKey(sounds_t, key);
			}
			sounds_a = ArrayCreate(64);
			for (new i = json_array_get_count(value_j) - 1; i >= 0; i--)
			{
				json_array_get_string(value_j, i, value, charsmax(value));
				if (file_exists(value))
				{
					precache_sound(value);
					ArrayPushString(sounds_a, value);
				}
			}
			json_free(value_j);
			if (ArraySize(sounds_a) > 0)
				TrieSetCell(sounds_t, key, sounds_a);
			else
				ArrayDestroy(sounds_a);
		}
		json_free(sound_j);
	}

	json_free(json);
	return true;
}

public PlayerClassInfo@GetCvar(const key[])
{
	new this = oo_this();

	new pcvar;
	new Trie:cvar_t = Trie:oo_get(this, "cvars");

	if (TrieGetCell(cvar_t, "key", pcvar))
		return pcvar;
	
	return 0;
}

// ---------- [OO PlayerClass] ----------

public PlayerClass@Ctor(player)
{
	new this = oo_this();
	oo_set(this, "player", player);
}

public PlayerClass@Dtor()
{
}

public PlayerClass@GetClassInfo()
{
	return @null;
}

public PlayerClass@ChangeWeaponModel(ent)
{
	new this = oo_this();

	new classinfo_o = oo_call(this, "GetClassInfo");
	if (classinfo_o == @null)
		return false;
	
	static classname[32];
	pev(ent, pev_classname, classname, charsmax(classname));

	new player = oo_get(this, "player");
	if (!is_user_alive(player))
		return false;

	new has_changed = false;
	static model[96], Trie:models_t;

	models_t = Trie:oo_get(classinfo_o, "v_models");
	if (TrieGetString(models_t, classname, model, charsmax(model)))
	{
		set_pev(player, pev_viewmodel2, model);
		has_changed = true;
	}

	models_t = Trie:oo_get(classinfo_o, "p_models");
	if (TrieGetString(models_t, classname, model, charsmax(model)))
	{
		set_pev(player, pev_weaponmodel2, model);
		has_changed = true;
	}

	return has_changed;
}

public PlayerClass@ChangeMaxSpeed()
{
	new this = oo_this();

	new classinfo_o = oo_call(this, "GetClassInfo");
	if (classinfo_o == @null)
		return false;

	new pcvar = oo_call(this, "GetCvar", "speed");
	if (!pcvar)
		return false;

	new player = oo_get(this, "player");
	if (!is_user_alive(player))
		return false;

	new Float:speed_value = get_pcvar_float(pcvar);

	new Float:current_speed;
	pev(player, pev_maxspeed, current_speed);
	set_pev(player, pev_maxspeed, (speed_value <= 5.0) ? current_speed * speed_value : speed_value);
	return true;
}

public PlayerClass@ChangeSound(channel, sample[], Float:vol, Float:attn, flags, pitch)
{
	new this = oo_this();

	new classinfo_o = oo_call(this, "GetClassInfo");
	if (classinfo_o == @null)
		return false;
	
	new Array:sounds_a = Invalid_Array;
	new Trie:sounds_t = Trie:oo_get(classinfo_o, "override_sounds")
	if (!TrieGetCell(sounds_t, sample, sounds_a))
		return false;

	new player = oo_get(this, "player");
	if (!is_user_alive(player))
		return false;
	
	static sound[96];
	ArrayGetString(sounds_a, random(ArraySize(sounds_a)), sound, charsmax(sound));
	emit_sound(player, channel, sound, vol, attn, flags, pitch);

	return true;
}

// --------- [Custom Functions] ----------

ChangePlayerClass(id, const class[], bool:set_props)
{
	ExecuteForward(g_fwChangePlayerClass, g_fwRet, id, class, set_props);

	if (g_fwRet >= PLUGIN_HANDLED)
		return @null;

	if (g_oPlayerClass[id] != @null)
	{
		oo_delete(g_oPlayerClass[id]);
		g_oPlayerClass[id] = @null;
	}

	g_oPlayerClass[id] = oo_new(class, id);

	if (g_oPlayerClass[id] == @null)
		return @null;

	if (set_props)
		oo_call(g_oPlayerClass[id], "SetProps");

	ExecuteForward(g_fwChangePlayerClassPost, g_fwRet, id, class, set_props);
	return g_oPlayerClass[id];
}

stock bool:PrecachePlayerModel(const model[])
{
	static path[128];
	formatex(path, charsmax(path), "models/player/%s/%s.mdl", model, model);
	if (!file_exists(path))
		return false;

	precache_model(path);

	// Support modelT.mdl files
	formatex(path, charsmax(path), "models/player/%s/%sT.mdl", model, model);
	if (file_exists(path))
		precache_model(path);

	return true;
}