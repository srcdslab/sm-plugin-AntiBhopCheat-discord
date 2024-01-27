#include <utilshelper>
#include <discordWebhookAPI>

#undef REQUIRE_PLUGIN
#tryinclude <SelectiveBhop>
#tryinclude <ExtendedDiscord>
#tryinclude <sourcebanschecker>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME "AntiBhopCheat Discord"
#define WEBHOOK_URL_MAX_SIZE			1000
#define WEBHOOK_THREAD_NAME_MAX_SIZE	100

ConVar g_cvCountBots, g_cvWebhook, g_cvWebhookRetry, g_cvChannelType;
ConVar g_cvThreadName, g_cvThreadID, g_cvAvatar;

char g_sMap[PLATFORM_MAX_PATH];
bool g_Plugin_SourceBans = false;
bool g_Plugin_ExtDiscord = false;

public Plugin myinfo =
{
	name			= PLUGIN_NAME,
	author			= ".Rushaway",
	description		= "Send webhook when a bhop cheat is detected",
	version			= "1.0.0",
	url				= "https://github.com/srcdslab/sm-plugin-AntiBhopCheat-discord"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("AntiBhopCheat_Discord");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvCountBots = CreateConVar("sm_antibhopcheat_count_bots", "1", "Should we count bots as players ?[0 = No, 1 = Yes]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvWebhook = CreateConVar("sm_antibhopcheat_discord_webhook", "", "The webhook URL of your Discord channel.", FCVAR_PROTECTED);
	g_cvWebhookRetry = CreateConVar("sm_antibhopcheat_discord_webhook_retry", "3", "Number of retries if webhook fails.", FCVAR_PROTECTED);
	g_cvAvatar = CreateConVar("sm_antibhopcheat_discord_avatar", "https://avatars.githubusercontent.com/u/110772618?s=200&v=4", "URL to Avatar image.");
	g_cvChannelType = CreateConVar("sm_antibhopcheat_discord_channel_type", "0", "Type of your channel: (1 = Thread, 0 = Classic Text channel");

	/* Thread config */
	g_cvThreadName = CreateConVar("sm_antibhopcheat_discord_threadname", "AntiBhopCheat - New detection", "The Thread Name of your Discord forums. (If not empty, will create a new thread)", FCVAR_PROTECTED);
	g_cvThreadID = CreateConVar("sm_antibhopcheat_discord_threadid", "0", "If thread_id is provided, the message will send in that thread.", FCVAR_PROTECTED);
	AutoExecConfig(true);
}

public void OnAllPluginsLoaded()
{
	g_Plugin_SourceBans = LibraryExists("sourcebans++");
	g_Plugin_ExtDiscord = LibraryExists("ExtendedDiscord");
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "sourcebans++", false) == 0)
		g_Plugin_SourceBans = true;
	if (strcmp(sName, "ExtendedDiscord", false) == 0)
		g_Plugin_ExtDiscord = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "sourcebans++", false) == 0)
		g_Plugin_SourceBans = false;
	if (strcmp(sName, "ExtendedDiscord", false) == 0)
		g_Plugin_ExtDiscord = false;
}

public void OnMapInit(const char[] mapName)
{
	FormatEx(g_sMap, sizeof(g_sMap), mapName);
}

public void AntiBhopCheat_OnClientDetected(int client, char[] sReason, char[] sStats)
{
	char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	g_cvWebhook.GetString(sWebhookURL, sizeof sWebhookURL);
	if (!sWebhookURL[0]) {
		LogError("[%s] No webhook found or specified.", PLUGIN_NAME);
		return;
	}

	char sAuth[32];
	GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth), false);

	char sPlayer[256];
	if (g_Plugin_SourceBans) {
		int iClientBans = 0;
		int iClientComms = 0;

	#if defined _sourcebanschecker_included
		iClientBans = SBPP_CheckerGetClientsBans(client);
		iClientComms = SBPP_CheckerGetClientsComms(client);
	#endif

		FormatEx(sPlayer, sizeof(sPlayer), "%N (%d bans - %d comms) [%s] %s.", client, iClientBans, iClientComms, sAuth, sReason);
	} else {
		FormatEx(sPlayer, sizeof(sPlayer), "%N [%s] %s.", client, sAuth, sReason);		
	}

	char sTime[64];
	int iTime = GetTime();
	FormatTime(sTime, sizeof(sTime), "Date : %d/%m/%Y @ %H:%M:%S", iTime);

	char sCount[32];
	int iMaxPlayers = MaxClients;
	int iConnected = GetPlayerCount(g_cvCountBots.BoolValue);
	FormatEx(sCount, sizeof(sCount), "Players : %d/%d", iConnected, iMaxPlayers);

	char sHeader[512], sMessage[2000];
	FormatEx(sHeader, sizeof(sHeader), "%s \nCurrent map : %s \n%s \n%s", sPlayer, g_sMap, sTime, sCount);

	// Discord character limit is 2000 (discord msg + stats)
	if (strlen(sHeader) + strlen(sStats) < 1994)
	{
		FormatEx(sMessage, sizeof(sMessage), "```%s \n\n%s```", sHeader, sStats);
		ReplaceString(sMessage, sizeof(sMessage), "\\n", "\n");
		SendWebHook(sMessage, sWebhookURL);
	}
	else
	{
		// First part: Header infos
		FormatEx(sMessage, sizeof(sMessage), "```%s```", sHeader);
		ReplaceString(sMessage, sizeof(sMessage), "\\n", "\n");
		SendWebHook(sMessage, sWebhookURL);

		// Second part: Stats
		FormatEx(sMessage, sizeof(sMessage), "```%s```", sStats);
		ReplaceString(sMessage, sizeof(sMessage), "\\n", "\n");
		SendWebHook(sMessage, sWebhookURL);
	}
}

stock void SendWebHook(char sMessage[2000], char sWebhookURL[WEBHOOK_URL_MAX_SIZE])
{
	Webhook webhook = new Webhook(sMessage);

	char sThreadID[32], sThreadName[WEBHOOK_THREAD_NAME_MAX_SIZE];
	g_cvThreadID.GetString(sThreadID, sizeof sThreadID);
	g_cvThreadName.GetString(sThreadName, sizeof sThreadName);

	bool IsThread = g_cvChannelType.BoolValue;

	if (IsThread) {
		if (!sThreadName[0] && !sThreadID[0]) {
			LogError("[%s] Thread Name or ThreadID not found or specified.", PLUGIN_NAME);
			delete webhook;
			return;
		} else {
			if (strlen(sThreadName) > 0) {
				webhook.SetThreadName(sThreadName);
				sThreadID[0] = '\0';
			}
		}
	}

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

	char sMessage[2000], sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	pack.ReadString(sMessage, sizeof(sMessage));
	pack.ReadString(sWebhookURL, sizeof(sWebhookURL));

	delete pack;
	
	if ((!IsThreadReply && response.Status != HTTPStatus_OK) || (IsThreadReply && response.Status != HTTPStatus_NoContent)) {
		if (retries < g_cvWebhookRetry.IntValue) {
				PrintToServer("[%s] Failed to send the webhook. Resending it .. (%d/%d)", PLUGIN_NAME, retries, g_cvWebhookRetry.IntValue);
				SendWebHook(sMessage, sWebhookURL);
				retries++;
				return;
			}
		} else {
			if (!g_Plugin_ExtDiscord) {
				LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
				LogError("[%s] Failed message : %s", PLUGIN_NAME, sMessage);
			}
		#if defined _extendeddiscord_included
			else {
				ExtendedDiscord_LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
				ExtendedDiscord_LogError("[%s] Failed message : %s", PLUGIN_NAME, sMessage);
			}
		#endif
		}

	retries = 0;
}