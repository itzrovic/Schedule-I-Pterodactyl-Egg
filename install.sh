#!/bin/bash
# Schedule I Dedicated Server (S1DedicatedServers + MelonLoader) - Pterodactyl install script
# Runs in the installer container as root; server files live in /mnt/server.

apt-get update -y
apt-get install -y --no-install-recommends curl unzip ca-certificates lib32gcc-s1 || true

SERVER_DIR=/mnt/server
APPID=3164500
mkdir -p "${SERVER_DIR}/steamcmd" "${SERVER_DIR}/.s1ds" "${SERVER_DIR}/Mods" "${SERVER_DIR}/UserLibs" "${SERVER_DIR}/Plugins"
cd /tmp || exit 1

## ---------- SteamCMD ----------
echo "==> Installing SteamCMD"
curl -sSL -o steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
tar -xzf steamcmd.tar.gz -C "${SERVER_DIR}/steamcmd"
mkdir -p "${SERVER_DIR}/steamapps"
# Steam stores the login/sentry under $HOME -> keep it in the server directory so auto-update
# on later starts works without a new Steam Guard code
export HOME="${SERVER_DIR}"
cd "${SERVER_DIR}/steamcmd" || exit 1

## ---------- Game download ----------
if [ -n "${STEAM_USER}" ] && [ "${STEAM_USER}" != "anonymous" ]; then
    echo "==> Downloading Schedule I (app ${APPID}), branch: ${SRCDS_BETAID:-public}"
    ./steamcmd.sh +@sSteamCmdForcePlatformType windows \
        +force_install_dir "${SERVER_DIR}" \
        +login "${STEAM_USER}" "${STEAM_PASS}" ${STEAM_AUTH} \
        +app_update ${APPID} $( [ -n "${SRCDS_BETAID}" ] && printf %s "-beta ${SRCDS_BETAID}" ) validate \
        +quit
else
    echo "!!! STEAM_USER is not set: the game will NOT be downloaded."
    echo "!!! Upload the Windows game files of Schedule I to /home/container via SFTP"
    echo "!!! and set AUTO_UPDATE to 0."
fi

## ---------- Steamworks redist (steamclient64.dll etc. for SteamGameServer) ----------
echo "==> Installing Steamworks SDK Redist (app 1007)"
./steamcmd.sh +@sSteamCmdForcePlatformType windows \
    +force_install_dir "${SERVER_DIR}" \
    +login anonymous \
    +app_update 1007 validate \
    +quit

# Linux steamclient for SteamCMD (used by the auto-update in the runtime container)
mkdir -p "${SERVER_DIR}/.steam/sdk32" "${SERVER_DIR}/.steam/sdk64"
cp -f linux32/steamclient.so "${SERVER_DIR}/.steam/sdk32/steamclient.so" 2>/dev/null || true
cp -f linux64/steamclient.so "${SERVER_DIR}/.steam/sdk64/steamclient.so" 2>/dev/null || true

cd /tmp || exit 1

## ---------- MelonLoader ----------
ML_VERSION="${MELONLOADER_VERSION:-v0.7.2}"
echo "==> Installing MelonLoader ${ML_VERSION}"
curl -sSL -o MelonLoader.x64.zip "https://github.com/LavaGang/MelonLoader/releases/download/${ML_VERSION}/MelonLoader.x64.zip"
unzip -o -q MelonLoader.x64.zip -d "${SERVER_DIR}"

## ---------- DedicatedServerMod ----------
if [ -z "${S1DS_VERSION}" ] || [ "${S1DS_VERSION}" == "latest" ]; then
    S1DS_BASE="https://github.com/ifBars/S1DedicatedServers/releases/latest/download"
else
    S1DS_BASE="https://github.com/ifBars/S1DedicatedServers/releases/download/${S1DS_VERSION}"
fi
echo "==> Downloading DedicatedServerMod (${S1DS_VERSION:-latest})"
curl -sSL -o Mono-Server.zip "${S1DS_BASE}/Mono-Server.zip"
curl -sSL -o Il2cpp_Server.zip "${S1DS_BASE}/Il2cpp_Server.zip"
# Keep both variants; the start script picks the one matching the installed game branch
unzip -o -q -j Mono-Server.zip 'Mods/*' -d "${SERVER_DIR}/.s1ds"
unzip -o -q -j Il2cpp_Server.zip 'Mods/*' -d "${SERVER_DIR}/.s1ds"
ls -la "${SERVER_DIR}/.s1ds"

echo "${APPID}" > "${SERVER_DIR}/steam_appid.txt"

## ---------- Start script ----------
cat > "${SERVER_DIR}/s1ds_start.sh" << 'EOF'
#!/bin/bash
# Called by the Pterodactyl startup command (Wine yolk). Overwritten on every reinstall.
cd /home/container || exit 1

APPID=3164500
GAME_EXE="Schedule I.exe"

if [ ! -f "${GAME_EXE}" ]; then
    echo "ERROR: '${GAME_EXE}' not found. Check the Steam login and reinstall the server (or upload the game files via SFTP)."
    exit 1
fi

# Detect the runtime from the game files: IL2CPP builds ship GameAssembly.dll
if [ -f "GameAssembly.dll" ]; then
    RUNTIME=il2cpp; MOD_DLL=DedicatedServerMod_Il2cpp_Server.dll
else
    RUNTIME=mono; MOD_DLL=DedicatedServerMod_Mono_Server.dll
fi
echo "==> Detected runtime: ${RUNTIME}"

mkdir -p Mods
rm -f Mods/DedicatedServerMod_Mono_Server.dll Mods/DedicatedServerMod_Il2cpp_Server.dll
if [ -f ".s1ds/${MOD_DLL}" ]; then
    cp -f ".s1ds/${MOD_DLL}" "Mods/${MOD_DLL}"
else
    echo "WARNING: .s1ds/${MOD_DLL} is missing - reinstall the server."
fi

# Only clear the Cpp2IL cache after game updates (otherwise every IL2CPP start would be slow)
if [ "${RUNTIME}" == "il2cpp" ]; then
    HASH=$(md5sum GameAssembly.dll | cut -d' ' -f1)
    if [ "$(cat .s1ds/gameassembly.md5 2>/dev/null)" != "${HASH}" ]; then
        echo "==> Game version changed: clearing Cpp2IL cache"
        rm -rf MelonLoader/Dependencies/Il2CppAssemblyGenerator/Cpp2IL/cpp2il_out
        echo "${HASH}" > .s1ds/gameassembly.md5
    fi
fi

# Write the Pterodactyl allocation ports into the config (it only exists after the first start)
CFG=$(find UserData -maxdepth 3 -name server_config.toml 2>/dev/null | head -n 1)
if [ -n "${CFG}" ]; then
    sed -i -E "s/^([[:space:]]*serverPort[[:space:]]*=[[:space:]]*).*/\1${SERVER_PORT}/" "${CFG}"
    if [ -n "${QUERY_PORT}" ]; then
        sed -i -E "s/^([[:space:]]*steamGameServerQueryPort[[:space:]]*=[[:space:]]*).*/\1${QUERY_PORT}/" "${CFG}"
    fi
    echo "==> Ports set in ${CFG}: serverPort=${SERVER_PORT}, steamGameServerQueryPort=${QUERY_PORT}"
else
    echo "==> First start: server_config.toml will be generated (default port 38465)."
    if [ "${SERVER_PORT}" != "38465" ]; then
        echo "    Your allocation is ${SERVER_PORT} - restart once after the first start so the port is applied."
    fi
fi

# UTF-8 locale, otherwise Wine cannot create files with non-ASCII names (e.g. NPC "Javier Pérez")
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

echo "${APPID}" > steam_appid.txt
export SteamAppId=${APPID}
export SteamGameId=${APPID}
# version.dll = MelonLoader proxy; load the Steam DLLs natively
# winedbg.exe=d: a crash on exit would otherwise start the Wine debugger, which keeps the process alive
export WINEDLLOVERRIDES="version=n,b;steam_api64=n,b;steamclient64=n,b;tier0_s64=n,b;vstdlib_s64=n,b;winedbg.exe=d"

ARGS=(-batchmode -nographics -logFile "Z:\home\container\UnityPlayer.log"
      --dedicated-server
      --server-name "${SERVER_NAME:-Schedule I Server}"
      --max-players "${MAX_PLAYERS:-4}"
      --messaging-backend "${MESSAGING_BACKEND:-FishNetRpc}")

if [ -n "${SERVER_PASSWORD}" ]; then
    ARGS+=(--server-password "${SERVER_PASSWORD}")
fi

if [ "${AUTH_PROVIDER}" == "None" ]; then
    ARGS+=(--disable-auth)
else
    ARGS+=(--require-auth --auth-provider SteamGameServer --steam-gs-anonymous)
fi

# Console: Wine does not reliably pass stdin to the game. So a TCP console runs on 127.0.0.1
# inside the container only, and this script forwards panel input to it.
CONSOLE_PORT=${CONSOLE_PORT:-4050}
CONSOLE_PASS=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
ARGS+=(--no-stdio-console --tcp-console --tcp-console-bind 127.0.0.1
       --tcp-console-port "${CONSOLE_PORT}" --tcp-console-password "${CONSOLE_PASS}")

echo "==> Starting: wine \"${GAME_EXE}\" (arguments without passwords) ${SERVER_NAME:+--server-name \"${SERVER_NAME}\"} ${EXTRA_ARGS}"
# Hide Wine debug output (fixme)
export WINEDEBUG=-all
# Unity/MelonLoader do not write to stdout under Wine -> mirror the MelonLoader log to the panel
# (this is also how the panel detects "DEDICATED SERVER READY")
tail -n 0 -F MelonLoader/Latest.log 2>/dev/null &
TAIL_PID=$!
# Errors from the game itself only show up in the Unity log -> mirror error lines to the panel too
: > UnityPlayer.log
tail -n 0 -F UnityPlayer.log 2>/dev/null | grep --line-buffered -iE "exception|error" | grep --line-buffered -viE "ALSA|fixme|shader|graphics buffer|GPU readback" | grep --line-buffered -vE '^[[:space:]]*[A-Za-z0-9_.+]+:[A-Za-z0-9_<>.]+ ?\(.*\)[[:space:]]*$' | sed -u 's/^/[Unity] /' &

# EXTRA_ARGS intentionally unquoted so multiple arguments work
wine "${GAME_EXE}" "${ARGS[@]}" ${EXTRA_ARGS} < /dev/null &
GAME_PID=$!

send_cmd() {
    local cmd="$1"
    if ! exec 3<>"/dev/tcp/127.0.0.1/${CONSOLE_PORT}" 2>/dev/null; then
        echo "[Console] Server not ready yet - command '${cmd}' was not sent."
        return 1
    fi
    printf '%s\n%s\nexit\n' "${CONSOLE_PASS}" "${cmd}" >&3
    # Only print the command's reply (hide banner/login/goodbye)
    timeout 15 cat <&3 | tr -d '\r' | awk '
        { sub(/^.*Password: /, ""); while (sub(/^> /, "")) {} }
        /^Authenticated\./ {on=1; next}
        /^Goodbye\./ {exit}
        on && length($0) { print "[Console] " $0 }'
    exec 3<&- 3>&-
}

STOPPING=0
graceful_stop() {
    [ "${STOPPING}" == "1" ] && return
    STOPPING=1
    if [ "${STOP_MODE}" == "mod" ]; then
        # Since DedicatedServerMod v1.1.2, "shutdown" waits for the final save itself
        echo "==> Shutting down via the mod (shutdown)..."
        send_cmd "shutdown"
        for i in $(seq 1 90); do
            kill -0 "${GAME_PID}" 2>/dev/null || return
            sleep 1
        done
        echo "==> WARNING: server still running after 90 s (save failed or game hung). Killing it."
        kill -9 "${GAME_PID}" 2>/dev/null
        wineserver -k 2>/dev/null
        return
    fi
    # Mode "script" (default): do NOT send "shutdown" to the mod. Up to v1.1.1 its shutdown save
    # blocked the main thread and quit while the save was still running, wiping business data
    # (ifBars/S1DedicatedServers#71). Instead: save normally, wait for "Save complete" in the
    # Unity log, then kill the process.
    echo "==> Saving..."
    local before now i
    before=$(grep -c "Save complete" UnityPlayer.log 2>/dev/null)
    send_cmd "save"
    for i in $(seq 1 60); do
        now=$(grep -c "Save complete" UnityPlayer.log 2>/dev/null)
        [ "${now:-0}" -gt "${before:-0}" ] && break
        sleep 1
    done
    if [ "${now:-0}" -gt "${before:-0}" ]; then
        echo "==> Saved. Stopping server."
    else
        echo "==> WARNING: save was not confirmed within 60 s. Stopping server anyway."
    fi
    sleep 2
    kill -9 "${GAME_PID}" 2>/dev/null
    wineserver -k 2>/dev/null
}
trap graceful_stop SIGTERM SIGINT

# Read panel input and forward it while the game is running
while kill -0 "${GAME_PID}" 2>/dev/null; do
    if read -r -t 1 LINE; then
        LINE="${LINE%$'\r'}"
        [ -z "${LINE}" ] && continue
        case "${LINE}" in
            shutdown|stop|quit|exit) graceful_stop ;;
            *) send_cmd "${LINE}" ;;
        esac
    elif [ $? -le 128 ]; then
        # stdin closed (no panel terminal) -> just wait
        sleep 1
    fi
done

wait "${GAME_PID}" 2>/dev/null
sleep 2
kill "${TAIL_PID}" 2>/dev/null
pkill -f "tail -n 0 -F UnityPlayer.log" 2>/dev/null
echo "==> Server stopped."
wineserver -k 2>/dev/null
exit 0
EOF
chmod +x "${SERVER_DIR}/s1ds_start.sh"

if [ ! -f "${SERVER_DIR}/Schedule I.exe" ] && [ -n "${STEAM_USER}" ]; then
    echo "!!! 'Schedule I.exe' is missing after the download. Common causes:"
    echo "!!!  - wrong password / Steam Guard code missing or expired"
    echo "!!!  - the Steam account does not own Schedule I"
fi

echo "==> Installation complete"
