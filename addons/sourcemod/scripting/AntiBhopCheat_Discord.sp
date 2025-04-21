#include <utilshelper>
#include <discordWebhookAPI>

#undef REQUIRE_PLUGIN
#tryinclude <SelectiveBhop>
#tryinclude <ExtendedDiscord>
#tryinclude <sourcebanschecker>
#define REQUIRE_PLUGIN

ConVar g_cvCountBots, g_cvWebhook, g_cvWebhookRetry, g_cvChannelType;
ConVar g_cvThreadName, g_cvThreadID, g_cvAvatar;

char g_sMap[PLATFORM_MAX_PATH];
char g_sPluginName[256];
bool g_Plugin_SourceChecker = false;
bool g_Plugin_ExtDiscord = false;

bool g_bNative_ExtDiscord = false;
bool g_bNative_SbChecker_Bans = false;
bool g_bNative_SbChecker_Mutes = false;
bool g_bNative_SbChecker_Gags = false;

public Plugin myinfo =
{
	name			= "AntiBhopCheat Discord",
	author			= ".Rushaway",
	description		= "Send webhook when a bhop cheat is detected",
	version			= "1.2.0",
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

	GetPluginInfo(INVALID_HANDLE, PlInfo_Name, g_sPluginName, sizeof(g_sPluginName));
}

public void OnAllPluginsLoaded()
{
	g_Plugin_SourceChecker = LibraryExists("sourcechecker++");
	g_Plugin_ExtDiscord = LibraryExists("ExtendedDiscord");

	VerifyNatives();
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "sourcechecker++", false) == 0)
	{
		g_Plugin_SourceChecker = true;
		VerifyNative_SbChecker();
	}
	else if (strcmp(sName, "ExtendedDiscord", false) == 0)
	{
		g_Plugin_ExtDiscord = true;
		VerifyNative_ExtDiscord();
	}
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "sourcechecker++", false) == 0)
	{
		g_Plugin_SourceChecker = false;
		VerifyNative_SbChecker();
	}
	else if (strcmp(sName, "ExtendedDiscord", false) == 0)
	{
		g_Plugin_ExtDiscord = false;
		VerifyNative_ExtDiscord();
	}
}

stock void VerifyNatives()
{
	VerifyNative_SbChecker();
	VerifyNative_ExtDiscord();
}

stock void VerifyNative_SbChecker()
{
	g_bNative_SbChecker_Bans = g_Plugin_SourceChecker && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SBPP_CheckerGetClientsBans") == FeatureStatus_Available;
	g_bNative_SbChecker_Mutes = g_Plugin_SourceChecker && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SBPP_CheckerGetClientsMutes") == FeatureStatus_Available;
	g_bNative_SbChecker_Gags = g_Plugin_SourceChecker && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SBPP_CheckerGetClientsGags") == FeatureStatus_Available;
}

stock void VerifyNative_ExtDiscord()
{
	g_bNative_ExtDiscord = g_Plugin_ExtDiscord && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "ExtendedDiscord_LogError") == FeatureStatus_Available;
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
		LogError("[%s] No webhook found or specified.", g_sPluginName);
		return;
	}

	char sAuth[32];
	GetClientAuthId(client, AuthId_Steam3, sAuth, sizeof(sAuth), false);

	char sPlayer[256];
	
	int iClientBans = 0;
	int iClientMutes = 0;
	int iClientGags = 0;

	#if defined _sourcebanschecker_included
	if (g_bNative_SbChecker_Bans)
		iClientBans = SBPP_CheckerGetClientsBans(client);

	if (g_bNative_SbChecker_Mutes)
		iClientMutes = SBPP_CheckerGetClientsMutes(client);

	if (g_bNative_SbChecker_Gags)
		iClientGags = SBPP_CheckerGetClientsGags(client);
	#endif

	FormatEx(sPlayer, sizeof(sPlayer), "%N (%d bans - %d mutes - %d gags) %s is suspected of using %s", client, iClientBans, iClientMutes, iClientGags, sAuth, sReason);

	char sTime[64];
	int iTime = GetTime();
	FormatTime(sTime, sizeof(sTime), "%d/%m/%Y @ %H:%M:%S", iTime);

	char sCount[32];
	int iMaxPlayers = MaxClients;
	int iConnected = GetPlayerCount(g_cvCountBots.BoolValue);
	FormatEx(sCount, sizeof(sCount), "%d/%d", iConnected, iMaxPlayers);

	char sHeader[512], sMessage[WEBHOOK_MSG_MAX_SIZE];
	FormatEx(sHeader, sizeof(sHeader), "%s \nMap : %s (%s)\n%s", sPlayer, g_sMap, sCount, sTime);

	// Discord character limit is 2000 (discord msg + stats)
	if (strlen(sHeader) + strlen(sStats) < WEBHOOK_MSG_MAX_SIZE)
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

stock void SendWebHook(char sMessage[WEBHOOK_MSG_MAX_SIZE], char sWebhookURL[WEBHOOK_URL_MAX_SIZE])
{
	Webhook webhook = new Webhook(sMessage);

	char sThreadID[32], sThreadName[WEBHOOK_THREAD_NAME_MAX_SIZE];
	g_cvThreadID.GetString(sThreadID, sizeof sThreadID);
	g_cvThreadName.GetString(sThreadName, sizeof sThreadName);

	bool IsThread = g_cvChannelType.BoolValue;

	if (IsThread) {
		if (!sThreadName[0] && !sThreadID[0]) {
			LogError("[%s] Thread Name or ThreadID not found or specified.", g_sPluginName);
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

	char sMessage[WEBHOOK_MSG_MAX_SIZE], sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	pack.ReadString(sMessage, sizeof(sMessage));
	pack.ReadString(sWebhookURL, sizeof(sWebhookURL));

	delete pack;
	
	if ((!IsThreadReply && response.Status != HTTPStatus_OK) || (IsThreadReply && response.Status != HTTPStatus_NoContent)) {
		if (retries < g_cvWebhookRetry.IntValue) {
				PrintToServer("[%s] Failed to send the webhook. Resending it .. (%d/%d)", g_sPluginName, retries, g_cvWebhookRetry.IntValue);
				SendWebHook(sMessage, sWebhookURL);
				retries++;
				return;
			}
		} else {
			if (!g_bNative_ExtDiscord) {
				LogError("[%s] Failed to send the webhook after %d retries, aborting.", g_sPluginName, retries);
				LogError("[%s] Failed message : %s", g_sPluginName, sMessage);
			}
		#if defined _extendeddiscord_included
			else {
				ExtendedDiscord_LogError("[%s] Failed to send the webhook after %d retries, aborting.", g_sPluginName, retries);
				ExtendedDiscord_LogError("[%s] Failed message : %s", g_sPluginName, sMessage);
			}
		#endif
		}

	retries = 0;
}
