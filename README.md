# Schedule I – Pterodactyl Egg (DedicatedServerMod)

A [Pterodactyl](https://pterodactyl.io/) egg for running a **Schedule I dedicated server** on a Linux node.

Schedule I has no official dedicated server. This egg uses the community **[DedicatedServerMod (S1DedicatedServers)](https://github.com/ifBars/S1DedicatedServers) by [ifBars](https://github.com/ifBars)**, which runs the regular Windows game headless as an authoritative server. On Linux, the game runs under Wine using the Pterodactyl Wine yolk.

> **All credit for the dedicated server itself goes to ifBars.** This repository only contains the Pterodactyl egg (install script, start script and panel integration). For the server mod, its configuration, commands and client package, see the [S1DedicatedServers repository](https://github.com/ifBars/S1DedicatedServers) and the [documentation](https://docs.s1servers.com/).

## Features

- Installs the game via SteamCMD, plus [MelonLoader](https://github.com/LavaGang/MelonLoader) and DedicatedServerMod (latest release or a pinned version)
- Supports **Mono** (`alternate` branch) and **IL2CPP** (`public` branch). The start script detects the runtime and loads the matching server DLL
- Panel console works: commands typed in the panel (`save`, `serverinfo`, `op <SteamID>`, …) are forwarded to the mod's TCP console, which only listens on localhost inside the container
- Server log and game errors are mirrored to the panel, and the panel detects when the server is ready
- Safe stop: the save completes before the process exits (see [Stop mode](#stop-mode))
- Pterodactyl allocation ports are written into `server_config.toml` automatically
- Optional auto-update of the game on every start
- Works around common Wine issues: UTF-8 locale, Wine debugger on exit, Unity logging

## Requirements

- Pterodactyl panel and Wings
- **A Steam account that owns Schedule I.** The game cannot be downloaded anonymously. A second account is recommended but not required.
- At least **4 GB RAM** (6 GB recommended) and 2 CPU cores
- Around **15 GB** disk space

## Installation

1. In the admin area, go to **Nests → Import Egg** and upload `egg-schedule-i.json`.
2. In **Nodes → your node → Allocation**, add the ports:
   - `38465`: game port (UDP **and** TCP; TCP is used for the mod's status query)
   - `27016`: Steam query port (UDP)
3. Create a server with this egg, using `38465` as the default allocation and `27016` as an additional one. Use the **Wine Latest** image.
4. Fill in the Steam username and password and choose the game branch (see below).
5. Wait for `==> Installation complete`, then start the server. It is ready when `DEDICATED SERVER READY` appears.
6. Forward the ports above on your router/firewall if players connect from outside your network.

### Steam Guard

If Steam asks for a code on the first login:

1. Enter the code in the **Steam Guard Code** variable.
2. Reinstall the server right away. App codes expire after about 30 seconds.
3. Clear the variable again afterwards. SteamCMD caches the login.

If you'd rather not store credentials, leave the Steam fields empty, upload the Windows game files via SFTP and set **Auto Update** to `0`.

## Mono vs. IL2CPP

| Game Branch | Runtime | Notes |
|---|---|---|
| `alternate` (default) | Mono | Recommended under Wine; fast startup |
| `public` | IL2CPP | Default Steam branch. Set **Wine Packages** to `vcrun2019 dotnetdesktop6`. The first start generates the IL2CPP assemblies, which takes a few minutes |

After changing the branch, **reinstall** the server. Save data works on both.

**Players must use the same branch in Steam** (Properties → Betas: `alternate`, or *None* for `public`). They also need MelonLoader and the matching **client** package (`Mono-Client.zip` or `Il2cpp_Client.zip`) from the [S1DedicatedServers releases](https://github.com/ifBars/S1DedicatedServers/releases).

## Variables

| Variable | Default | Description |
|---|---|---|
| Server Name | `Schedule I Server` | Server name |
| Max Players | `4` | Maximum players |
| Server Password | – | See [Known limitations](#known-limitations) |
| Steam Query Port | `27016` | Must exist as an additional allocation |
| Auth Provider | `SteamGameServer` | `None` disables Steam verification (testing only) |
| Messaging Backend | `FishNetRpc` | or `SteamNetworkingSockets` |
| Extra Arguments | – | Additional [DedicatedServerMod arguments](https://docs.s1servers.com/) |
| Game Branch | `alternate` | `alternate` (Mono) or `public` (IL2CPP) |
| Steam Username / Password / Guard Code | – | Account that owns the game |
| Auto Update | `1` | Update the game via SteamCMD on every start |
| Stop Mode | `script` | See below |
| Wine Packages | `vcrun2019` | Add `dotnetdesktop6` for IL2CPP |
| MelonLoader Version | `v0.7.2` | Applied on reinstall |
| DedicatedServerMod Version | `latest` | e.g. `v1.1.2`; applied on reinstall |

## Stop mode

- **`script`** (default): on stop, the start script sends `save`, waits until the game reports `Save complete`, and then ends the process. This avoids [ifBars/S1DedicatedServers#71](https://github.com/ifBars/S1DedicatedServers/issues/71), where the shutdown save in v1.1.1 and earlier was cut off and business data got wiped.
- **`mod`**: sends `shutdown` to the mod and waits for it to exit. If it hasn't exited after 90 seconds, the script kills it. Only use this with **DedicatedServerMod v1.1.2 or newer**, which fixed the issue above.

Stopping or restarting from the panel, or typing `shutdown` in the panel console, always goes through the start script.

## Mods

Put additional MelonLoader mods into `Mods/`, `UserLibs/` or `Plugins/`, keeping the folder structure from the mod's archive. Notes:

- DLLs must sit **directly** in `Mods/`, not in a subfolder.
- Use the variant that matches the runtime (Mono or IL2CPP).
- Most gameplay mods also need to be installed on every client.

## Importing an existing save

Follow the [save path guide](https://docs.s1servers.com/docs/configuration/save-path.html) from the mod documentation:

1. Start the server once so it creates `UserData/DedicatedServerSave`.
2. Stop the server.
3. Copy the world files into that folder, but **do not overwrite `Players/Player_0`**. That player is the server's internal loopback host.

The host's own character in a normal save is `Player_0`. To keep it, rename that folder to `Player_<your SteamID64>` before copying.

## Troubleshooting

- **Logs:** `MelonLoader/Latest.log` (mod and loader) and `UnityPlayer.log` (game errors) in the server root.
- **`Shader … not supported`, `NavMesh`, `ALSA` messages:** expected on a headless server without a GPU or sound card. They are harmless.
- **Players can't see or join the server:** check that `38465` is forwarded for **both UDP and TCP**.
- **Admin rights:** type `op <SteamID64>` in the panel console.

## Known limitations

- As of DedicatedServerMod v1.1.2, the **server password is not enforced** when players join. It is only reported to Steam. Don't rely on it to keep strangers out. Use `kick`/`ban` and keep the address private.
- IL2CPP under Wine is considered beta by the mod author. Mono is the safer choice.

## Credits

- **[ifBars](https://github.com/ifBars)**: [S1DedicatedServers / DedicatedServerMod](https://github.com/ifBars/S1DedicatedServers), the dedicated server this egg is built on
- **[LavaGang](https://github.com/LavaGang)**: [MelonLoader](https://github.com/LavaGang/MelonLoader)
- **[ptero-eggs](https://github.com/ptero-eggs)**: Wine yolk and installer images
- **TVGS**: [Schedule I](https://store.steampowered.com/app/3164500/Schedule_I/)

This project is not affiliated with or endorsed by TVGS or the developers of Schedule I.
