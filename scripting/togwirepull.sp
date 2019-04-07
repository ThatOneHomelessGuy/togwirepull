/*
	
*/

#pragma semicolon 1
//#pragma dynamic 131072 //increase stack space to from 4 kB to 131072 cells (or 512KB, a cell is 4 bytes)
#define PLUGIN_VERSION "1.0.0"
#include <sourcemod>
#include <autoexecconfig>	//https://github.com/Impact123/AutoExecConfig or https://forums.alliedmods.net/showthread.php?p=1862459
//#include <sdkhooks>
#include <sdktools>
#include <emitsoundany>

#pragma newdecls required

ConVar g_cSoundPathSuccess = null;
char g_sSoundPathSuccess[PLATFORM_MAX_PATH];
ConVar g_cSoundPathFail = null;
char g_sSoundPathFail[PLATFORM_MAX_PATH];

ArrayList g_asPullSelection;
int g_iSelectionIndex = -1;

public Plugin myinfo =
{
	name = "TOG Wire Pull",
	author = "That One Guy",
	description = "Wire pull plugin with editable pull selection and sounds.",
	version = PLUGIN_VERSION,
	url = "http://www.togcoding.com"
}

public void OnPluginStart()
{
	AutoExecConfig_SetFile("togwirepull");
	AutoExecConfig_CreateConVar("twp_version", PLUGIN_VERSION, "TOG Wire Pull: Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_cSoundPathSuccess = AutoExecConfig_CreateConVar("twp_sound_success", "bot/all_clear_here.wav", "Sound to be played upon successful wire pull.");
	g_cSoundPathSuccess.GetString(g_sSoundPathSuccess, sizeof(g_sSoundPathSuccess));
	g_cSoundPathSuccess.AddChangeHook(OnCVarChange);
	
	g_cSoundPathFail = AutoExecConfig_CreateConVar("twp_sound_fail", "bot/aww_man.wav", "Sound to be played upon failed wire pull.");
	g_cSoundPathFail.GetString(g_sSoundPathFail, sizeof(g_sSoundPathFail));
	g_cSoundPathFail.AddChangeHook(OnCVarChange);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	HookEvent("bomb_begindefuse", Event_Defuse, EventHookMode_Post);
	HookEvent("bomb_beginplant", Event_Plant, EventHookMode_Post);
	HookEvent("bomb_planted", Event_Planted, EventHookMode_PostNoCopy);
	
	HookEvent("bomb_abortdefuse", Event_Abort, EventHookMode_Post);
	HookEvent("bomb_abortplant", Event_Abort, EventHookMode_Post);
	
	g_asPullSelection = new ArrayList(64);
	
	OnMapStart();
}

public void OnCVarChange(ConVar hCVar, const char[] sOldValue, const char[] sNewValue)
{
	if(hCVar == g_cSoundPathSuccess)
	{
		g_cSoundPathSuccess.GetString(g_sSoundPathSuccess, sizeof(g_sSoundPathSuccess));
		PrecacheAndDownloadSounds();
	}
	else if(hCVar == g_cSoundPathFail)
	{
		g_cSoundPathFail.GetString(g_sSoundPathFail, sizeof(g_sSoundPathFail));
		PrecacheAndDownloadSounds();
	}
}

public void OnMapStart()
{
	g_asPullSelection.Clear();
	char sBuffer[150], sFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "configs/togwirepull_selection.cfg");
	File oFile = OpenFile(sFilePath, "r");
	if(oFile != null)
	{
		while(oFile.ReadLine(sBuffer, sizeof(sBuffer)))
		{
			TrimString(sBuffer);	
			if(!StrEqual(sBuffer, ""))
			{
				g_asPullSelection.PushString(sBuffer);
			}
		}
	}
	else
	{
		SetFailState("File does not exist: \"%s\"", sFilePath);
	}
	delete oFile;
	
	PrecacheAndDownloadSounds();
}

void PrecacheAndDownloadSounds()
{
	char sShortPath[PLATFORM_MAX_PATH], sFullPath[PLATFORM_MAX_PATH];
	if(!StrEqual(g_sSoundPathSuccess, "", false))
	{
		if(StrContains(g_sSoundPathSuccess, "sound/", false) == 0)
		{
			Format(sShortPath, sizeof(sShortPath), "%s", g_sSoundPathSuccess[6]);
			strcopy(g_sSoundPathSuccess, sizeof(g_sSoundPathSuccess), sShortPath);	//make sure the global variable holds the short path
		}
		else
		{
			strcopy(sShortPath, sizeof(sShortPath), g_sSoundPathSuccess);
		}
		Format(sFullPath, sizeof(sFullPath), "sound/%s", sShortPath);
		if(FileExists(sFullPath))
		{
			AddFileToDownloadsTable(sFullPath);
		}
		PrecacheSoundAny(sShortPath);
	}

	if(!StrEqual(g_sSoundPathFail, "", false))
	{
		if(StrContains(g_sSoundPathFail, "sound/", false) == 0)
		{
			Format(sShortPath, sizeof(sShortPath), "%s", g_sSoundPathFail[6]);
			strcopy(g_sSoundPathFail, sizeof(g_sSoundPathFail), sShortPath);	//make sure the global variable holds the short path
		}
		else
		{
			strcopy(sShortPath, sizeof(sShortPath), g_sSoundPathFail);
		}
		Format(sFullPath, sizeof(sFullPath), "sound/%s", sShortPath);
		if(FileExists(sFullPath))
		{
			AddFileToDownloadsTable(sFullPath);
		}
		PrecacheSoundAny(sShortPath);
	}
}

public void Event_Plant(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!IsValidClient(client))
	{
		return;
	}
	g_iSelectionIndex = -1;
	
	Panel oPanel2 = new Panel();
	oPanel2.SetTitle("Select Wire (or ignore for random):");
	for(int i = 0; i < g_asPullSelection.Length; i++)
	{
		char sSelection2[150];
		g_asPullSelection.GetString(i, sSelection2, sizeof(sSelection2));
		oPanel2.DrawItem(sSelection2);
	}
	oPanel2.Send(client, PanelHandler_Plant, MENU_TIME_FOREVER);
	delete oPanel2;	//object is not deleted in handler
}

public int PanelHandler_Plant(Menu hMenu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		if(0 < param2 <= g_asPullSelection.Length)
		{
			g_iSelectionIndex = param2 - 1;
			char sSelection3[150];
			g_asPullSelection.GetString(g_iSelectionIndex, sSelection3, sizeof(sSelection3));
			PrintToChat(client, "\x01\x04You have selected wire: %s", sSelection3);
		}
	}
}

public void Event_Planted(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if(g_iSelectionIndex == -1)
	{
		g_iSelectionIndex = GetRandomInt(0,g_asPullSelection.Length - 1)	;
	}
}

public void Event_Defuse(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!IsValidClient(client))
	{
		return;
	}
	
	Panel oPanel = new Panel();
	oPanel.SetTitle("Select Wire to Cut:");
	for(int i = 0; i < g_asPullSelection.Length; i++)
	{
		char sSelection[150];
		g_asPullSelection.GetString(i, sSelection, sizeof(sSelection));
		oPanel.DrawItem(sSelection);
	}
	oPanel.Send(client, PanelHandler_Defuse, MENU_TIME_FOREVER);
	delete oPanel;	//object is not deleted in handler
}

public int PanelHandler_Defuse(Menu hMenu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		if(0 < param2 <= g_asPullSelection.Length)
		{
			int iC4Ent = FindEntityByClassname(-1,"planted_c4");
			int iSelection = param2 - 1;
			char sSelection[150], sCorrectSelection[150];
			g_asPullSelection.GetString(iSelection, sSelection, sizeof(sSelection));
			g_asPullSelection.GetString(g_iSelectionIndex, sCorrectSelection, sizeof(sCorrectSelection));
			if(iC4Ent != -1)
			{
				if(iSelection == g_iSelectionIndex)
				{
					SetEntPropFloat(iC4Ent, Prop_Send, "m_flDefuseCountDown", 1.0);
					PrintToChatAll("\x01\x04%N has defused the bomb by cutting the correct wire: %s", client, sCorrectSelection);
					if(!StrEqual(g_sSoundPathSuccess, "", false))
					{
						EmitSoundToAllAny(g_sSoundPathSuccess);
					}
				}
				else
				{
					SetEntPropFloat(iC4Ent, Prop_Send, "m_flC4Blow", 1.0);
					PrintToChatAll("\x01\x04%N cut the wrong wire (%s) and detonated the bomb! Correct wire: %s", client, sSelection, sCorrectSelection);
					if(!StrEqual(g_sSoundPathFail, "", false))
					{
						EmitSoundToAllAny(g_sSoundPathFail);
					}
				}
			}
		}
	}
}

public void Event_Abort(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	
	if(IsValidClient(client))
	{
		CancelClientMenu(client);
	}
}

bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || (!IsPlayerAlive(client) && !bAllowDead))
	{
		return false;
	}
	return true;
}

stock void Log(char[] sPath, const char[] sMsg, any ...)		//TOG logging function - path is relative to logs folder.
{
	char sLogFilePath[PLATFORM_MAX_PATH], sFormattedMsg[1500];
	BuildPath(Path_SM, sLogFilePath, sizeof(sLogFilePath), "logs/%s", sPath);
	VFormat(sFormattedMsg, sizeof(sFormattedMsg), sMsg, 3);
	LogToFileEx(sLogFilePath, "%s", sFormattedMsg);
}

/*
CHANGELOG:
	1.0.0
		* Initial creation.
		
*/