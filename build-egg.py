"""Builds egg-schedule-i.json from install.sh. Run: python build-egg.py"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
script = open(os.path.join(HERE, "install.sh"), encoding="utf-8").read().replace("\r\n", "\n")


def var(name, desc, env, default, rules, viewable=True, editable=True):
    return {"name": name, "description": desc, "env_variable": env, "default_value": default,
            "user_viewable": viewable, "user_editable": editable, "rules": rules, "field_type": "text"}


egg = {
    "_comment": "DO NOT EDIT: FILE GENERATED AUTOMATICALLY BY PTERODACTYL PANEL - PTERODACTYL.IO",
    "meta": {"version": "PTDL_v2", "update_url": None},
    "exported_at": "2026-10-15T12:00:00+00:00",
    "name": "Schedule I (DedicatedServerMod)",
    "author": "your-email@example.com",
    "description": "Schedule I dedicated server using MelonLoader and ifBars' DedicatedServerMod (github.com/ifBars/S1DedicatedServers), running under Wine. Supports the Mono (alternate) and IL2CPP (public) branches. Requires a Steam account that owns Schedule I. Players need the matching client mod and the same game branch.",
    "features": ["steam_disk_space"],
    "docker_images": {
        "Wine Latest": "ghcr.io/ptero-eggs/yolks:wine_latest",
        "Wine Staging": "ghcr.io/ptero-eggs/yolks:wine_staging",
    },
    "file_denylist": [],
    "startup": "bash ./s1ds_start.sh",
    "config": {
        "files": "{}",
        "startup": json.dumps({"done": "DEDICATED SERVER READY"}),
        "logs": "{}",
        "stop": "shutdown",
    },
    "scripts": {"installation": {"script": script, "container": "ghcr.io/ptero-eggs/installers:debian", "entrypoint": "bash"}},
    "variables": [
        var("Server Name", "Name of the server.", "SERVER_NAME", "Schedule I Server", "required|string|max:64"),
        var("Max Players", "Maximum number of players. Vanilla is designed for 4, the mod allows more.", "MAX_PLAYERS", "4", "required|integer|between:1,32"),
        var("Server Password", "Optional join password. Empty = no password. Note: as of DedicatedServerMod v1.1.2 the password is only reported to Steam and not enforced on join.", "SERVER_PASSWORD", "", "nullable|string|max:64"),
        var("Steam Query Port", "UDP port for Steam queries (steamGameServerQueryPort). Must be added to the server as an additional allocation.", "QUERY_PORT", "27016", "required|integer|between:1024,65535"),
        var("Auth Provider", "SteamGameServer = players are verified via Steam (recommended). None = no verification (testing only).", "AUTH_PROVIDER", "SteamGameServer", "required|string|in:SteamGameServer,None"),
        var("Messaging Backend", "FishNetRpc = direct UDP connection (simplest). SteamNetworkingSockets = Steam relay/routing.", "MESSAGING_BACKEND", "FishNetRpc", "required|string|in:FishNetRpc,SteamNetworkingSockets"),
        var("Extra Arguments", "Additional DedicatedServerMod arguments, e.g. --mod-verification --block-known-risky-client-mods true", "EXTRA_ARGS", "", "nullable|string|max:512"),
        var("Game Branch", "alternate = Mono build (recommended, most stable under Wine). public = default Steam branch (IL2CPP; set Wine Packages to 'vcrun2019 dotnetdesktop6'). Reinstall the server after changing. Players must use the same branch in Steam (public = Betas: None)!", "SRCDS_BETAID", "alternate", "required|string|in:public,alternate,alternate-beta,beta"),
        var("Steam Username", "Login of a Steam account that owns Schedule I. Empty = no download; upload the game files via SFTP and set Auto Update to 0.", "STEAM_USER", "", "nullable|string|max:64"),
        var("Steam Password", "Password of the Steam account.", "STEAM_PASS", "", "nullable|string|max:128"),
        var("Steam Guard Code", "Only needed for the first login. Enter it, reinstall immediately, then clear it again.", "STEAM_AUTH", "", "nullable|string|max:10"),
        var("Auto Update", "1 = update the game via SteamCMD on every start, 0 = off.", "AUTO_UPDATE", "1", "required|boolean"),
        var("Stop Mode", "script = the start script saves and then stops the game itself (safe default). mod = send 'shutdown' to the server mod (only use with DedicatedServerMod v1.1.2 or newer).", "STOP_MODE", "script", "required|string|in:script,mod"),
        var("Wine Packages", "Winetricks packages ensured on every start. For IL2CPP (branch 'public') use 'vcrun2019 dotnetdesktop6'.", "WINETRICKS_RUN", "vcrun2019", "nullable|string|max:256"),
        var("MelonLoader Version", "MelonLoader release tag (tested with v0.7.2). Applied on reinstall.", "MELONLOADER_VERSION", "v0.7.2", "required|string|max:20"),
        var("DedicatedServerMod Version", "Release tag of ifBars/S1DedicatedServers, e.g. v1.1.2, or 'latest'. Applied on reinstall.", "S1DS_VERSION", "latest", "required|string|max:32"),
        var("App ID", "Steam app ID of Schedule I.", "SRCDS_APPID", "3164500", "required|string|in:3164500", viewable=False, editable=False),
        var("Windows Install", "SteamCMD downloads the Windows files.", "WINDOWS_INSTALL", "1", "required|string|in:1", viewable=False, editable=False),
        var("XVFB", "Virtual display for Wine.", "XVFB", "1", "required|string|in:1", viewable=False, editable=False),
    ],
}

with open(os.path.join(HERE, "egg-schedule-i.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(egg, f, indent=4, ensure_ascii=False)
    f.write("\n")
print("egg-schedule-i.json written")
