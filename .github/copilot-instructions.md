# Copilot Instructions: BoostAlert Discord Plugin

## Repository Overview

This repository contains a **SourcePawn plugin for SourceMod** that integrates Discord webhook notifications with the BoostAlert system. The plugin sends formatted Discord messages when boost events occur in Source engine games (CS:GO, CS2, etc.).

### Key Purpose
- Sends Discord webhook notifications for knife/boost damage events
- Integrates with multiple SourceMod plugins (BoostAlert, AutoRecorder, ExtendedDiscord)
- Supports both regular channels and Discord threads
- Provides detailed player information including Steam IDs and damage values

## Architecture & Dependencies

### Core Dependencies (Required)
- **SourceMod 1.12+**: Base modding platform
- **BoostAlert Plugin**: Provides the boost event forwards this plugin listens to
- **DiscordWebhookAPI**: Handles Discord webhook communication

### Optional Dependencies
- **AutoRecorder**: Adds demo recording information to messages
- **ExtendedDiscord**: Enhanced Discord logging capabilities  
- **ZombieReloaded**: Changes "killed" terminology to "infected"

### Plugin Integration Pattern
```sourcepawn
// Uses library existence checking pattern
g_Plugin_ZR = LibraryExists("zombiereloaded");
g_Plugin_AutoRecorder = LibraryExists("AutoRecorder");

// Conditional compilation with tryinclude
#undef REQUIRE_PLUGIN
#tryinclude <AutoRecorder>
#tryinclude <ExtendedDiscord>
#define REQUIRE_PLUGIN
```

## Build System: SourceKnight

This project uses **SourceKnight** for dependency management and compilation, NOT traditional SourceMod compilation.

### Build Configuration (`sourceknight.yaml`)
- **Project Name**: BoostAlert_Discord
- **Output Directory**: `/addons/sourcemod/plugins`
- **Target**: BoostAlert_Discord (compiles BoostAlert_Discord.sp)

### Dependencies Auto-Downloaded
```yaml
dependencies:
  - sourcemod (base platform)
  - discordwebapi (from GitHub)
  - BoostAlert (from GitHub) 
  - AutoRecorder (from GitHub)
  - ExtendedDiscord (from GitHub)
```

### Build Commands (if SourceKnight available)
```bash
# Install SourceKnight first (done in CI via action-sourceknight)
sourceknight build              # Compile plugin
sourceknight clean              # Clean build artifacts
```

### CI/CD Pipeline
- **Build**: Uses `maxime1907/action-sourceknight@v1`
- **Outputs**: Compiled .smx files to `/tmp/package`
- **Release**: Auto-creates releases on tags and main branch pushes

## Code Style & Patterns

### SourcePawn Conventions (Strictly Followed)
```sourcepawn
#pragma semicolon 1
#pragma newdecls required

// Global variables with g_ prefix
ConVar g_cvWebhook, g_cvWebhookRetry;
char g_sMap[PLATFORM_MAX_PATH];
bool g_Plugin_ZR = false;

// PascalCase for functions
public void OnPluginStart()
public void BoostAlert_OnBoost(int attacker, int victim, int damage, const char[] sWeapon)

// camelCase for local variables
char sMessage[1300];
int iKnife = StrContains(sWeapon, "knife", false);
```

### Memory Management Pattern
```sourcepawn
// Always use delete, never check null first
Webhook webhook = new Webhook(sMessage);
// ... use webhook
delete webhook;  // Direct deletion

DataPack pack = new DataPack();
// ... use pack  
delete pack;     // No null checking needed
```

### Configuration Management
```sourcepawn
// All cvars created in OnPluginStart()
g_cvWebhook = CreateConVar("sm_boostalert_webhook", "", "Description", FCVAR_PROTECTED);
AutoExecConfig(true);  // Auto-generate config file
```

## Key Functions & Patterns

### Event Handling
```sourcepawn
// Main boost event handler
public void BoostAlert_OnBoost(int attacker, int victim, int damage, const char[] sWeapon)

// Assisted kill event handler  
public void BoostAlert_OnBoostedKill(int attacker, int victim, int iInitialAttacker, int damage, char[] sWeapon)
```

### Discord Message Flow
1. **Event Received** → Format player info + damage
2. **Escape Discord Markdown** → Prevent formatting issues
3. **Add Context** → Map, scores, time, optional demo info
4. **Send Webhook** → With retry logic and thread support
5. **Handle Response** → Retry on failure, reset counter on success

### Steam ID Handling Pattern
```sourcepawn
AuthIdType authType = view_as<AuthIdType>(GetConVarInt(g_cvAuthID));
GetClientAuthId(client, authType, sAuth, sizeof(sAuth), false);

// Clean Steam3 format if needed
if (authType == AuthId_Steam3) {
    ReplaceString(sAuth, sizeof(sAuth), "[", "");
    ReplaceString(sAuth, sizeof(sAuth), "]", "");
}
```

## Common Development Tasks

### Adding New ConVars
1. Declare global ConVar in header section
2. Create in `OnPluginStart()` with `CreateConVar()`
3. Add to `AutoExecConfig(true)` call
4. Use throughout code with `.GetString()`, `.IntValue`, `.BoolValue`

### Discord Message Formatting
- **Always escape markdown**: Use `PrepareDiscord_Message()` pattern
- **Prevent exploits**: Replace @, /, quotes to prevent pings/embeds
- **Format consistently**: Use code blocks (```) for actual game messages
- **Include context**: Map, team scores, timestamp, optional demo info

### Adding Plugin Integration
```sourcepawn
// 1. Add library check in OnAllPluginsLoaded()
g_Plugin_NewPlugin = LibraryExists("newplugin");

// 2. Handle library events
public void OnLibraryAdded(const char[] sName) {
    if (strcmp(sName, "newplugin", false) == 0)
        g_Plugin_NewPlugin = true;
}

// 3. Conditional compilation
#undef REQUIRE_PLUGIN
#tryinclude <newplugin>
#define REQUIRE_PLUGIN

// 4. Use with preprocessor checks
#if defined _newplugin_included
if (g_Plugin_NewPlugin) {
    // Call plugin functions
}
#endif
```

### Error Handling Pattern
```sourcepawn
// Always check critical resources
char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
g_cvWebhook.GetString(sWebhookURL, sizeof sWebhookURL);
if(!sWebhookURL[0]) {
    LogError("[%s] No webhook found or specified.", PLUGIN_NAME);
    return;
}

// Use retry logic for network operations  
if (retries < g_cvWebhookRetry.IntValue) {
    // Retry logic
} else {
    // Final error logging
}
```

## Testing & Validation

### Manual Testing Approach (No Automated Tests)
1. **Setup Test Environment**: SourceMod server with dependencies
2. **Install Plugin**: Copy .smx to plugins folder
3. **Configure**: Set webhook URL and other cvars
4. **Trigger Events**: Use BoostAlert events or commands
5. **Verify Discord**: Check webhook messages in Discord channel
6. **Test Edge Cases**: Disconnected players, threads, retries

### Testing Checklist
- [ ] Basic boost event → Discord message
- [ ] Knife damage vs regular damage formatting
- [ ] Player disconnect handling (shows "disconnected player")
- [ ] Thread vs regular channel posting
- [ ] Retry logic on webhook failures
- [ ] Steam ID format handling (Steam3 bracket removal)
- [ ] Special character escaping in Discord
- [ ] AutoRecorder integration (if available)
- [ ] Multi-language character handling

### Common Issues to Test
- **Webhook URL**: Missing/invalid webhook causes errors
- **Thread Configuration**: Wrong thread ID/name causes failures
- **Character Encoding**: Special characters in player names
- **Network Failures**: Webhook service unavailable
- **Plugin Dependencies**: Missing BoostAlert breaks functionality

## Configuration Files

### Auto-Generated Config (`cfg/sourcemod/BoostAlert_Discord.cfg`)
```
// Core webhook settings
sm_boostalert_webhook ""                    // Discord webhook URL (PROTECTED)
sm_boostalert_webhook_retry "3"             // Retry attempts on failure
sm_boostalert_discord_avatar "https://..."  // Webhook avatar URL

// Channel/Thread settings  
sm_boostalert_discord_channel_type "0"      // 0=channel, 1=thread
sm_boostalert_threadname "Knife Alert"      // Thread name for creation
sm_boostalert_threadid "0"                  // Existing thread ID

// Inherited from BoostAlert
sm_boostalert_authid "X"                    // Steam ID format (found automatically)
```

## Security Considerations

### Protected Information
- **Webhook URLs**: Marked as FCVAR_PROTECTED (hidden from players)
- **Thread Names**: FCVAR_PROTECTED to prevent exposure
- **Steam IDs**: Configurable format, respects BoostAlert settings

### Input Sanitization
```sourcepawn
// Discord markdown escaping prevents formatting injection
ReplaceString(sEscapedMessage, sizeof(sEscapedMessage), "`", "\\`");
ReplaceString(sEscapedMessage, sizeof(sEscapedMessage), "*", "\\*");
ReplaceString(sEscapedMessage, sizeof(sEscapedMessage), "~", "\\~");

// Prevent Discord pings/embeds
ReplaceString(sEscapedMessage, sizeof(sEscapedMessage), "@", "ⓐ");
ReplaceString(sEscapedMessage, sizeof(sEscapedMessage), "/", "୵");
```

## Troubleshooting Guide

### Common Errors
1. **"No webhook found"**: Check `sm_boostalert_webhook` cvar
2. **"Thread Name or ThreadID not found"**: Set thread config when using channel_type 1
3. **Webhook send failures**: Check Discord webhook URL validity and server connectivity
4. **Missing boost events**: Verify BoostAlert plugin is loaded and working

### Debugging Steps
1. Check `sm plugins list` for all required plugins loaded
2. Verify `sm_boostalert_webhook` has valid URL
3. Test webhook manually with curl/Postman
4. Check SourceMod error logs for specific issues
5. Validate BoostAlert is generating events with other plugins

### Performance Notes
- Plugin uses minimal resources (event-driven)
- Network operations are asynchronous (doesn't block game)
- Retry logic prevents spam on temporary failures
- Memory management follows SourcePawn best practices

## Development Environment Setup

Since this repository uses SourceKnight rather than traditional SourceMod development:

1. **For Code Changes**: Edit `.sp` files directly, SourceKnight handles compilation
2. **For Testing**: Use the GitHub Actions CI or set up SourceKnight locally
3. **For Dependencies**: They're auto-downloaded by SourceKnight from GitHub
4. **For Releases**: Tags automatically trigger builds and releases

This plugin is well-architected and follows SourcePawn best practices. Focus on maintaining the existing patterns when making modifications.