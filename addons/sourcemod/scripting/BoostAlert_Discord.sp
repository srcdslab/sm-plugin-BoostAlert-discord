#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <discordWebhookAPI>
#include <BoostAlert>

#undef REQUIRE_PLUGIN
#tryinclude <AutoRecorder>
#tryinclude <ExtendedDiscord>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME "BoostAlert Discord"

ConVar g_cvWebhook, g_cvWebhookRetry, g_cvAvatar;
ConVar g_cvChannelType, g_cvThreadName, g_cvThreadID;

char g_sMap[PLATFORM_MAX_PATH];
bool g_Plugin_ZR = false;
bool g_Plugin_AutoRecorder = false;
bool g_Plugin_ExtDiscord = false;

public Plugin myinfo =
{
	name         = PLUGIN_NAME,
	author       = ".Rushaway",
	description  = "Discord support based on BoostAlert forwards",
	version      = "1.0.0",
	url          = "https://github.com/srcdslab/sm-plugin-BoostAlert-discord"
};

public void OnPluginStart()
{
	g_cvWebhook 		 = CreateConVar("sm_boostalert_webhook", "", "The webhook URL of your Discord channel.", FCVAR_PROTECTED);
	g_cvWebhookRetry 	 = CreateConVar("sm_boostalert_webhook_retry", "3", "Number of retries if webhook fails.", FCVAR_PROTECTED);
	g_cvAvatar 			 = CreateConVar("sm_boostalert_discord_avatar", "https://avatars.githubusercontent.com/u/110772618?s=200&v=4", "URL to Avatar image.");
	g_cvChannelType 	 = CreateConVar("sm_boostalert_discord_channel_type", "0", "Type of your channel: (1 = Thread, 0 = Classic Text channel");

	/* Thread config */
	g_cvThreadName = CreateConVar("sm_boostalert_threadname", "Knife Alert", "The Thread Name of your Discord forums. (If not empty, will create a new thread)", FCVAR_PROTECTED);
	g_cvThreadID = CreateConVar("sm_boostalert_threadid", "0", "If thread_id is provided, the message will send in that thread.", FCVAR_PROTECTED);

	AutoExecConfig(true);
}

public void OnAllPluginsLoaded()
{
	g_Plugin_ZR = LibraryExists("zombiereloaded");
	g_Plugin_AutoRecorder = LibraryExists("AutoRecorder");
	g_Plugin_ExtDiscord = LibraryExists("ExtendedDiscord");
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "zombiereloaded", false) == 0)
		g_Plugin_ZR = true;
	if (strcmp(sName, "AutoRecorder", false) == 0)
		g_Plugin_AutoRecorder = true;
	if (strcmp(sName, "ExtendedDiscord", false) == 0)
		g_Plugin_ExtDiscord = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "zombiereloaded", false) == 0)
		g_Plugin_ZR = false;
	if (strcmp(sName, "AutoRecorder", false) == 0)
		g_Plugin_AutoRecorder = false;
	if (strcmp(sName, "ExtendedDiscord", false) == 0)
		g_Plugin_ExtDiscord = false;
}

public void OnMapStart()
{
	GetCurrentMap(g_sMap, sizeof(g_sMap));
	ReplaceString(g_sMap, sizeof(g_sMap), "/", "-", false);
	ReplaceString(g_sMap, sizeof(g_sMap), ".", "_", false);
}

public void BoostAlert_OnAlert(int attacker, int victim, int damage, char[] sWeapon)
{
	char sMessage[1300];
	int iKnife = StrContains(sWeapon, "knife", false);

	if (iKnife != -1)
		FormatEx(sMessage, sizeof(sMessage), "%L knifed %L (-%d HP)", attacker, victim, damage);
	else
		FormatEx(sMessage, sizeof(sMessage), "%L boosted %L with %s (-%d HP)", attacker, victim, sWeapon, damage);

	PrepareDiscord_Message(sMessage);
}

public void BoostAlert_OnKill(int attacker, char[] Auth_attacker, int victim, char[] Auth_victim, int pOldKnifer, char[] Auth_OldKnifer, int damage, char[] sWeapon)
{
	char sType[32], sMessage[1300];
	int iKnife = StrContains(sWeapon, "knife", false);
	sType = g_Plugin_ZR ? "infected" : "killed";

	if (iKnife != -1)
		FormatEx(sMessage, sizeof(sMessage), "%L knifed (-%d HP) %L (Recently knifed by %L)", attacker, victim, damage, pOldKnifer);
	else
		FormatEx(sMessage, sizeof(sMessage), "%L %s %L with %s (-%d HP) (Recently boosted by %L)", attacker, sType, victim, sWeapon, pOldKnifer);

	PrepareDiscord_Message(sMessage);
}

public void BoostAlert_OnKillDisconnect(int attacker, char[] Auth_attacker, int victim, char[] Auth_victim, char[] Auth_OldKnifer, int damage, char[] sWeapon)
{
	int iKnife = StrContains(sWeapon, "knife", false);
	char sType[32], sMessage[1300];
	sType = g_Plugin_ZR ? "infected" : "killed";

	if (iKnife != -1)
		FormatEx(sMessage, sizeof(sMessage), "%L %s %L (Recently knifed by a disconnected player [%s])", attacker, sType, victim, Auth_OldKnifer);
	else
		FormatEx(sMessage, sizeof(sMessage), "%L %s %L with %s (Recently boosted by a disconnected player [%s])", attacker, sType, victim, sWeapon, Auth_OldKnifer);

	PrepareDiscord_Message(sMessage);
}

stock void PrepareDiscord_Message(const char[] message)
{
	char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	g_cvWebhook.GetString(sWebhookURL, sizeof sWebhookURL);
	if(!sWebhookURL[0])
	{
		LogError("[%s] No webhook found or specified.", PLUGIN_NAME);
		return;
	}

	char sTime[64], sMessage[1300];
	int iTime = GetTime();
	FormatTime(sTime, sizeof(sTime), "%m/%d/%Y @ %H:%M:%S", iTime);

	if (g_Plugin_AutoRecorder)
	{
		char sDate[32];
		int iCount = -1;
		int iTick = -1;
		int retValTime = -1;
		#if defined _autorecorder_included
		if (AutoRecorder_IsDemoRecording())
		{
			iCount = AutoRecorder_GetDemoRecordCount();
			iTick = AutoRecorder_GetDemoRecordingTick();
			retValTime = AutoRecorder_GetDemoRecordingTime();
		}
		if (retValTime == -1)
			sDate = "N/A";
		else
			FormatTime(sDate, sizeof(sDate), "%d.%m.%Y @ %H:%M", retValTime);
		#endif
		Format(sMessage, sizeof(sMessage), "%s *(CT: %d | T: %d) - %s* - Demo: %d @ Tick: ≈ %d *(Started %s)* ```%s```",
			g_sMap, GetTeamScore(3), GetTeamScore(2), sTime, iCount, iTick, sDate, message);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s *(CT: %d | T: %d) - %s* ```%s```", g_sMap, GetTeamScore(3), GetTeamScore(2), sTime, message);
	}

	if(StrContains(sMessage, "\"") != -1)
		ReplaceString(sMessage, sizeof(sMessage), "\"", "");

	SendWebHook(sMessage, sWebhookURL);
}

stock void SendWebHook(char sMessage[1300], char sWebhookURL[WEBHOOK_URL_MAX_SIZE])
{
	Webhook webhook = new Webhook(sMessage);

	char sThreadID[32], sThreadName[WEBHOOK_THREAD_NAME_MAX_SIZE];
	g_cvThreadID.GetString(sThreadID, sizeof sThreadID);
	g_cvThreadName.GetString(sThreadName, sizeof sThreadName);

	bool IsThread = g_cvChannelType.BoolValue;

	if (IsThread)
	{
		if (!sThreadName[0] && !sThreadID[0])
		{
			LogError("[%s] Thread Name or ThreadID not found or specified.", PLUGIN_NAME);
			delete webhook;
			return;
		}
		else
		{
			if (strlen(sThreadName) > 0)
			{
				webhook.SetThreadName(sThreadName);
				sThreadID[0] = '\0';
			}
		}
	}

	/* Webhook Avatar */
	char sAvatar[256];
	g_cvAvatar.GetString(sAvatar, sizeof(sAvatar));
	if (strlen(sAvatar) > 0)
		webhook.SetAvatarURL(sAvatar);

	DataPack pack = new DataPack();

	if (IsThread && strlen(sThreadName) <= 0 && strlen(sThreadID) > 0)
		pack.WriteCell(1);
	else
		pack.WriteCell(0);

	pack.WriteString(sMessage);
	pack.WriteString(sWebhookURL);

	webhook.Execute(sWebhookURL, OnWebHookExecuted, pack, sThreadID);
	delete webhook;
}

public void OnWebHookExecuted(HTTPResponse response, DataPack pack)
{
	static int retries = 0;
	pack.Reset();

	bool IsThreadReply = pack.ReadCell();

	char sMessage[1300], sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	pack.ReadString(sMessage, sizeof(sMessage));
	pack.ReadString(sWebhookURL, sizeof(sWebhookURL));

	delete pack;

	if (!IsThreadReply && response.Status != HTTPStatus_OK)
	{
		if (retries < g_cvWebhookRetry.IntValue)
		{
			PrintToServer("[%s] Failed to send the webhook. Resending it .. (%d/%d)", PLUGIN_NAME, retries, g_cvWebhookRetry.IntValue);
			SendWebHook(sMessage, sWebhookURL);
			retries++;
			return;
		} else {
		#if defined _extendeddiscord_included
			if (g_Plugin_ExtDiscord)
				ExtendedDiscord_LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
			else
				LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#else
			LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#endif
		}
	}

	else if (IsThreadReply && response.Status != HTTPStatus_NoContent)
	{
		if (retries < g_cvWebhookRetry.IntValue)
		{
			PrintToServer("[%s] Failed to send the webhook. Resending it .. (%d/%d)", PLUGIN_NAME, retries, g_cvWebhookRetry.IntValue);
			SendWebHook(sMessage, sWebhookURL);
			retries++;
			return;
		} else {
		#if defined _extendeddiscord_included
			if (g_Plugin_ExtDiscord)
				ExtendedDiscord_LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
			else
				LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#else
			LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#endif
		}
	}

	retries = 0;
}