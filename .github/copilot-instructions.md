# Copilot Instructions for AntiBhopCheat Discord Plugin

## Repository Overview
This repository contains a SourcePawn plugin for SourceMod that integrates with the AntiBhopCheat plugin to send Discord webhook notifications when bunny hop cheats are detected. The plugin extends the main AntiBhopCheat functionality by providing real-time Discord notifications with detailed player information and detection statistics.

**Key Dependencies:**
- [sm-plugin-AntiBhopCheat](https://github.com/srcdslab/sm-plugin-AntiBhopCheat) (required)
- DiscordWebhookAPI for webhook functionality
- UtilsHelper for utility functions
- Optional: SourceBans++ integration, Extended Discord, SelectiveBhop

## Technical Environment
- **Language**: SourcePawn
- **Platform**: SourceMod 1.12+ (minimum supported version)
- **Build System**: SourceKnight v0.2 (`sourceknight.yaml` configuration)
- **Compiler**: Latest SourcePawn compiler via SourceKnight
- **CI/CD**: GitHub Actions with automated building and releasing

## Build & Development Process

### Building the Plugin
```bash
# Install SourceKnight if not already installed
# Build using SourceKnight (handles all dependencies automatically)
sourceknight build

# Output will be in .sourceknight/package/addons/sourcemod/plugins/
```

### Development Workflow
1. Make changes to `addons/sourcemod/scripting/AntiBhopCheat_Discord.sp`
2. Build using `sourceknight build`
3. Test on a development server with SourceMod and AntiBhopCheat installed
4. CI automatically builds and creates releases on push/PR

### Dependencies Management
All dependencies are managed through `sourceknight.yaml`:
- sourcemod (base platform)
- utilshelper (utility functions)
- discordwebapi (webhook functionality)
- sourcebans-pp (ban information integration)
- Extended-Discord (enhanced Discord logging)
- selectivebhop (selective bhop features)

## Code Style & Standards

### SourcePawn Conventions
- **Indentation**: Use tabs (4 spaces equivalent)
- **Variables**: 
  - camelCase for local variables and function parameters
  - PascalCase for function names
  - Prefix global variables with "g_" (e.g., `g_cvWebhook`)
- **Constants**: Use UPPER_CASE for defines and enum values
- **Pragmas**: Include `#pragma semicolon 1` and `#pragma newdecls required` (may be inherited from includes)
- **Includes**: Use proper include order - core includes first, then optional plugins with `#tryinclude`

### Memory Management
- Use `delete` for handle cleanup without null checks (SourceMod handles this)
- Prefer `StringMap`/`ArrayList` over arrays for dynamic data
- Use methodmaps for complex data structures
- Never use `.Clear()` on StringMap/ArrayList (creates memory leaks); use `delete` instead

### Error Handling
- Always check return values of API calls
- Use `LogError()` for error logging
- Implement retry logic for external API calls (webhooks)
- Handle library loading/unloading gracefully

## Project Structure

```
addons/sourcemod/
├── scripting/
│   └── AntiBhopCheat_Discord.sp    # Main plugin source
├── plugins/                        # Compiled plugin output (build target)
├── translations/                   # Language files (if needed)
└── configs/                       # Configuration files

.github/
├── workflows/
│   └── ci.yml                     # Automated build and release
└── dependabot.yml                 # Dependency updates

sourceknight.yaml                   # Build configuration and dependencies
README.md                          # Repository documentation
```

### Key Files
- **Main Plugin**: `addons/sourcemod/scripting/AntiBhopCheat_Discord.sp`
- **Build Config**: `sourceknight.yaml` (defines dependencies and build targets)
- **CI/CD**: `.github/workflows/ci.yml` (automated building via SourceKnight)

### Plugin Architecture
- **OnPluginStart()**: Initialize ConVars and register library
- **OnAllPluginsLoaded()**: Check for optional plugin dependencies
- **OnLibraryAdded/Removed()**: Handle dynamic plugin loading
- **AntiBhopCheat_OnClientDetected()**: Main hook for cheat detection
- **SendWebHook()**: Handle Discord webhook delivery with retry logic

## Configuration Variables
Key ConVars that can be modified:
- `sm_antibhopcheat_discord_webhook`: Discord webhook URL
- `sm_antibhopcheat_discord_webhook_retry`: Retry attempts for failed webhooks
- `sm_antibhopcheat_discord_channel_type`: Channel type (0=text, 1=thread)
- `sm_antibhopcheat_discord_avatar`: Avatar URL for webhook
- `sm_antibhopcheat_count_bots`: Whether to count bots in player count

## Best Practices

### Performance Considerations
- Minimize string operations in frequently called functions
- Cache expensive operations (player counts, etc.)
- Use asynchronous operations for external API calls
- Avoid unnecessary loops in event handlers

### Security Practices
- Always escape user input for Discord messages
- Use FCVAR_PROTECTED for sensitive ConVars (webhook URLs)
- Sanitize player names to prevent Discord markdown injection
- Validate webhook responses properly

### Integration Patterns
- Use conditional compilation (`#if defined`) for optional dependencies
- Check feature availability before using native functions
- Implement graceful degradation when optional plugins are unavailable
- Use library existence checks before calling native functions

## Discord Webhook Implementation

### Message Formatting
- Escape special Discord markdown characters in player names
- Split long messages if they exceed Discord's 2000 character limit
- Format messages with code blocks for better readability
- Include relevant player statistics and ban information

### Thread Support
- Support both regular channels and forum threads
- Handle thread creation and existing thread messaging
- Proper error handling for different channel types

### Retry Logic
- Implement configurable retry attempts for failed webhooks
- Use proper HTTP status code checking
- Log failures appropriately (with Extended Discord if available)

## Testing & Validation

### Manual Testing
1. Install on a test server with SourceMod 1.12+
2. Install AntiBhopCheat main plugin
3. Configure Discord webhook URL
4. Trigger cheat detection and verify Discord messages
5. Test with various player names (special characters)
6. Test thread vs channel functionality

### Code Validation
- Ensure all SQL operations are asynchronous (if any)
- Verify proper memory management (no handle leaks)
- Check for string buffer overflows
- Validate ConVar bounds and types

## Common Modification Patterns

### Adding New ConVars
```sourcepawn
// In OnPluginStart()
g_cvNewSetting = CreateConVar("sm_antibhopcheat_new_setting", "default", "Description", FCVAR_NOTIFY);
AutoExecConfig(true); // Ensure this is called after all ConVars
```

### Adding Optional Plugin Integration
```sourcepawn
// Check library existence
bool g_Plugin_NewIntegration = false;

public void OnAllPluginsLoaded() {
    g_Plugin_NewIntegration = LibraryExists("new_plugin_library");
}

// Use conditional compilation for native calls
#if defined _newplugin_included
if (g_Plugin_NewIntegration) {
    // Call native function
}
#endif
```

### Modifying Discord Message Format
- Always escape user input for Discord markdown
- Consider message length limits (2000 characters)
- Test with various player names and special characters
- Maintain code block formatting for readability

## Troubleshooting

### Common Issues
1. **Build Failures**: Check SourceKnight dependencies in YAML file
2. **Webhook Failures**: Verify URL format and Discord permissions
3. **Missing Dependencies**: Ensure all required plugins are installed
4. **Character Encoding**: Check for special characters in player names

### Debug Information
- Enable ConVar debugging for webhook issues
- Check SourceMod error logs for compilation issues
- Use Extended Discord logging if available
- Monitor HTTP response codes for webhook debugging