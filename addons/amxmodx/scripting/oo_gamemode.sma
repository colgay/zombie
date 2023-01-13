#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <orpheu>
#include <oo>

#define TASK_THINK 0

new g_oCurrentMode = @null;
new g_DefaultMode[32];
new g_pGameRules;
new Float:g_RoundTime, Float:g_RoundStartTime;
new Float:g_RespawnTime[MAX_PLAYERS + 1];
new bool:g_IsKilled[MAX_PLAYERS + 1];

new CvarRoundTime;

public oo_init()
{
	oo_class("GameMode")
	{
		new cl[] = "GameMode";

		oo_var(cl, "is_started", 1);
		oo_var(cl, "is_ended", 1);
		oo_var(cl, "is_deathmatch", 1);

		oo_ctor(cl, "Ctor");
		oo_dtor(cl, "Dtor");

		oo_mthd(cl, "WinConditions");
		oo_mthd(cl, "Start");
		oo_mthd(cl, "End");
		oo_mthd(cl, "RoundTimeExpired");
		oo_mthd(cl, "Think");
		oo_mthd(cl, "RespawnPlayer", @int{id});
		oo_mthd(cl, "SetRespawnTime", @int{id}, @fl{time});
		oo_mthd(cl, "CanPlayerRespawn", @int{id});
		oo_mthd(cl, "ChooseGameMode", @stref{mode}, @int{len});
		oo_mthd(cl, "TerminateRound", @int{status}, @fl{delay});
		oo_mthd(cl, "UpdateTeamScores", @int{team});
		oo_mthd(cl, "EndRoundMessage", @str{message}, @int{event});
		oo_mthd(cl, "GetRoundStartTime");

		oo_mthd(cl, "OnNewRound");
		oo_mthd(cl, "OnRoundStart");
		oo_mthd(cl, "OnRoundEnd");
		oo_mthd(cl, "OnPlayerSpawn", @int{id});
		oo_mthd(cl, "OnPlayerKilled", @int{id}, @int{attacker}, @int{shouldgib});
	}
}

public plugin_precache()
{
	OrpheuRegisterHook(OrpheuGetFunction("InstallGameRules"), "OnInstallGameRules", OrpheuHookPost);
}

public plugin_init()
{
	register_plugin("[OO] Game Mode", "0.1", "holla");

	register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");

	register_logevent("EventRoundStart", 2, "1=Round_Start");
	register_logevent("EventRoundEnd", 2, "1=Round_End");

	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", 1);
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Post", 1);

	OrpheuRegisterHook(OrpheuGetFunction("CheckWinConditions", "CHalfLifeMultiplay"), "OnCheckWinConditions");

	CvarRoundTime = get_cvar_pointer("mp_roundtime");
}

public plugin_natives()
{
	register_library("oo_gamemode");

	register_native("oo_gamemode_get_current", "native_gamemode_get_current");
	register_native("oo_gamemode_set_default", "native_gamemode_set_default");
}

// oo_gamemode_get_current()
public native_gamemode_get_current()
{
	return g_oCurrentMode;
}

// oo_gamemode_set_default(const class[])
public native_gamemode_set_default()
{
	new name[32];
	get_string(1, name, charsmax(name));

	copy(g_DefaultMode, charsmax(g_DefaultMode), name);
}

public OnInstallGameRules()
{
	g_pGameRules = OrpheuGetReturn();
}

public EventNewRound()
{
	ChooseGameMode();

	g_RoundTime = get_pcvar_float(CvarRoundTime) * 60.0;

	if (g_oCurrentMode != @null)
		oo_call(g_oCurrentMode, "OnNewRound");
}

public EventRoundStart()
{
	g_RoundStartTime = get_gametime();

	if (g_oCurrentMode != @null)
		oo_call(g_oCurrentMode, "OnRoundStart");
}

public EventRoundEnd()
{
	if (g_oCurrentMode != @null)
		oo_call(g_oCurrentMode, "OnRoundEnd");
}

public OrpheuHookReturn:OnCheckWinConditions()
{
	if (g_oCurrentMode == @null)
		return OrpheuIgnored;

	return oo_call(g_oCurrentMode, "WinConditions") ? OrpheuSupercede : OrpheuIgnored;
}

public client_disconnected(id)
{
	g_IsKilled[id] = false;
	g_RespawnTime[id] = 0.0;
}

public OnPlayerSpawn_Post(id)
{
	if (!is_user_alive(id))
		return;

	g_IsKilled[id] = false;

	if (g_oCurrentMode != @null)
		oo_call(g_oCurrentMode, "OnPlayerSpawn", id);
}

public OnPlayerKilled_Post(id, attacker, shouldgib)
{
	if (is_user_alive(id))
		return;

	g_IsKilled[id] = true;

	if (g_oCurrentMode != @null)
		oo_call(g_oCurrentMode, "OnPlayerKilled", id, attacker, shouldgib);
}

public GameMode@Ctor() {}
public GameMode@Dtor() {}

public GameMode@Think()
{
	new this = oo_this();

	if (oo_get(this, "is_started"))
	{
		if (oo_get(this, "is_ended"))
		{
			remove_task(TASK_THINK);
			return;
		}

		new Float:curr_time = get_gametime();

		if (oo_get(this, "is_deathmatch"))
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (g_IsKilled[i] && curr_time >= g_RespawnTime[id])
					oo_call(this, "RespawnPlayer", i);
			}
		}

		if (curr_time >= g_RoundStartTime + g_RoundTime)
		{
			oo_call(this, "RoundTimeExpired");
		}
	}
}

public GameMode@SetRespawnTime(id)
{
	g_RespawnTime[id] = get_gametime();
}

public GameMode@CanPlayerRespawn(id)
{
	if (is_user_alive(id))
		return false;

	new this = oo_this();

	if (!oo_get(this, "is_started") || oo_get(this, "is_ended") || !oo_get(this, "is_deathmatch"))
		return false;

	if (!(1 <= get_ent_data(id, "m_iTeam") <= 2) || get_ent_data(id, "m_iMenu") == CS_Menu_ChooseAppearance)
		return false;

	return true;
}

public GameMode@RespawnPlayer(id)
{
	if (oo_call(oo_this(), "CanPlayerRespawn", id))
		ExecuteHamB(Ham_CS_RoundRespawn, id);
}

public GameMode@ChooseGameMode() {}
public GameMode@RoundTimeExpired() {}
public GameMode@WinConditions() {}

public GameMode@Start() {}

public GameMode@End()
{
	remove_task(TASK_THINK);
}

public GameMode@OnNewRound()
{
	remove_task(TASK_THINK);
	set_task(0.1, "GameModeThink", TASK_THINK, _, _, "b");
}

public GameMode@OnRoundStart() {}
public GameMode@OnRoundEnd() {}
public GameMode@OnPlayerSpawn() {}
public GameMode@OnPlayerKilled() {}

public GameModeThink()
{
	if (g_oCurrentMode == @null)
	{
		remove_task(TASK_THINK);
		return;
	}

	oo_call(g_oCurrentMode, "Think");
}

public GameMode@TerminateRound(status, Float:delay)
{
	set_gamerules_int("CHalfLifeMultiplay", "m_iRoundWinStatus", status);
	set_gamerules_int("CHalfLifeMultiplay", "m_bRoundTerminating", true);
	set_gamerules_float("CHalfLifeMultiplay", "m_fTeamCount", get_gametime() + delay);
}

public GameMode@UpdateTeamScores(team)
{
	static msgTeamScore;
	msgTeamScore || (msgTeamScore = get_user_msgid("TeamScore"));

	if (team == 1 || team == 0)
	{
		emessage_begin(MSG_BROADCAST, msgTeamScore);
		ewrite_string("TERRORIST");
		ewrite_short(get_gamerules_int("CHalfLifeMultiplay", "m_iNumTerroristWins"));
		emessage_end();
	}

	if (team == 2 || team == 0)
	{
		emessage_begin(MSG_BROADCAST, msgTeamScore);
		ewrite_string("CT");
		ewrite_short(get_gamerules_int("CHalfLifeMultiplay", "m_iNumCTWins"));
		emessage_end();
	}
}

public GameMode@EndRoundMessage(const message[], event)
{
	static OrpheuFunction:func;
	func || (func = OrpheuGetFunction("EndRoundMessage"));

	OrpheuCall(func, message, event);
}

public Float:GameMode@GetRoundStartTime()
{
	return g_RoundStartTime;
}

ChooseGameMode()
{
	if (g_oCurrentMode == @null)
		return;

	new nextmode[32];
	oo_call(g_oCurrentMode, "ChooseGameMode", nextmode, charsmax(nextmode));

	if (nextmode[0])
	{
		if (oo_subclass_of(nextmode, "GameMode"))
			return;

		oo_delete(g_oCurrentMode);
		g_oCurrentMode = oo_new(nextmode);
	}
}