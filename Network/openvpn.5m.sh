#!/usr/bin/env bash

# <xbar.title>MacOS OpenVPN client & DNS Manager</xbar.title>
# <xbar.version>v0.88008</xbar.version>
# <xbar.author>glowinthedark</xbar.author>
# <xbar.author.github>glowinthedark</xbar.author.github>
# <xbar.desc>OpenVPN GUI & DNS configuration tool</xbar.desc>
# <xbar.image>TODO</xbar.image>
# <xbar.dependencies>openvpn</xbar.dependencies>
# <xbar.abouturl></xbar.abouturl>

# Preconditions
# =============

# - INSTALL OPENVPN:

#     brew install openvpn

# NOTE: To avoid having to enter the root password allow 
# passwordless sudo for your user for: openvpn, killall and pkill:

# 1. Type in terminal: sudo visudo
# 2. Append the following line at the end of the file:

# your_username        ALL = NOPASSWD: /usr/local/sbin/openvpn, /usr/bin/killall, /usr/bin/pkill

# 3. Search and replace all __FIXME__ lines with your specific commands

# START CONFIG
OVPN_PROFILE_1=/Users/__FIXME__/VPN/openvpn1.ovpn
OVPN_PROFILE_2=/Users/__FIXME__/VPN/openvpn2.ovpn
OPENVPN_CMD=/usr/local/sbin/openvpn
# the host to ping in order to check if the tunnel is up
PING_TARGET=source.int.netcentric.biz

# TODO: replace with your VPN DNS
DNS1=10.0.0.1
DNS2=172.22.0.2
# END CONFIG

script_path="$0"

#################################
# get MacOS network service name
function get_service_name() {
  network_device=$(scutil --nwi | awk -F': ' '/Network interfaces/ {print $2;exit;}')
  network_service=$(/usr/sbin/networksetup -listnetworkserviceorder | awk -v DEV="$network_device" -F': |,' '$0~ DEV  {print $2;exit;}')
  echo "$network_service"
}

#################################
# flush DNS cache
function flush_dns_cache() {
  /usr/bin/dscacheutil -flushcache
  sudo /usr/bin/killall -HUP mDNSResponder  
}

NETWORK_SERVICE_NAME="$(get_service_name)"

#################################
## EDIT THIS SCRIPT 
if [[ "$1" = "edit_this_script" ]]; then
  # open with default editor registered for .sh extension
 open "$0";
  # open with your preferred editor
  # (via macos app name)
  # open -a 'Sublime Text' "$0"  
  # (via macos bundle name) 
  # open -b com.sublimetext.3 "$0" 
  exit

#################################
# SET INTERNAL DNS SERVERS
elif [[ "$1" = "set_dns_servers_internal" ]]; then
  /usr/sbin/networksetup -setdnsservers "$NETWORK_SERVICE_NAME" $DNS1 $DNS2
  flush_dns_cache 
  exit

#################################
# SET DNS SERVERS
elif [[ "$1" = "set_dns_servers_custom" ]]; then
  /usr/sbin/networksetup -setdnsservers "$NETWORK_SERVICE_NAME" $2
  flush_dns_cache   
  exit

#################################
# START EXPECT SESSION
elif [[ "$1" = "openvpn_start_expect_session" ]]; then
  OVPN_PROFILE="$2"
  USER="$(echo __FIXME__command_to_get_user_name)"
  PW=$(echo __FIXME__command_to_get_user_password)

  # IMPORTANT: the OVPN file name MUST contain these strings!!!
  if [[ $OVPN_PROFILE =~ "openvpn1" ]]; then
    OTP_CODE=$(echo __FIXME__command_to_get_vpn1_token)
  elif [[ $OVPN_PROFILE =~ "openvpn2" ]]; then
    OTP_CODE=$(echo __FIXME__command_to_get_vpn2_token)
  fi

  /usr/bin/expect << EOF
  set timeout -1

  # Detailed log for debugging (uncomment to enable)
  # exp_internal -f /tmp/expect_vpn.log 0

  spawn /usr/bin/sudo $OPENVPN_CMD --allow-pull-fqdn --config $OVPN_PROFILE 
  expect "Auth Username:"
  send -- "$USER\r"

  expect "Auth Password:"
  send -- "$PW\r"

  expect "Enter Authenticator Code"
  send -- "$OTP_CODE\r"

  expect "Initialization Sequence Completed"

  send_user "\n\n✅ OpenVPN Init Complete!\n\n"
  expect_background
  send_user "8️⃣ Setting DNS servers: $DNS1 $DNS2\n\n"
  exec /usr/sbin/networksetup -setdnsservers "$NETWORK_SERVICE_NAME" $DNS1 $DNS2
  exec open -g "bitbar://refreshPlugin?name=nc-vpn.*?.sh"
  exec afplay /System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/AlertTones/tweet_sent.caf
  exec "$script_path" send_process_to_background
  expect eof
EOF
  exit
#################################
# DISCONNECT
elif [[ "$1" = "openvpn_disconnect" ]]; then
  if [[ "$2" = "force" ]]; then
    sudo /usr/bin/pkill -9 -f "$OPENVPN_CMD"
  else 
    sudo /usr/bin/pkill -f "$OPENVPN_CMD"
  fi
  /usr/sbin/networksetup -setdnsservers "$NETWORK_SERVICE_NAME" empty
  flush_dns_cache
  exit

#################################
# SEND CONSOLE TO BACKGROUND
elif [[ "$1" = "send_process_to_background" ]]; then
  osascript << EOF
tell application "System Events"
  tell application process "Terminal"
    activate
    set frontmost to true
    keystroke "z" using {control down}
    keystroke "bg"
    keystroke return
    keystroke "disown"
    keystroke return
  end tell
end tell
EOF
  exit
#################################
# CONNECT
elif [[ "$1" = "openvpn_connect_terminal" ]]; then
  ovpn_profile="$2"
  osascript << EOF
    tell application "Terminal"
    if not (exists window 1) then reopen
    activate
    do script "$script_path openvpn_start_expect_session $ovpn_profile" in front window
    end tell
EOF
  exit
fi

#################################
# CHECK VPN (wait 5 sec max until timeout)
DUMMY=$( ping -t 5 -c 1 "$PING_TARGET" 2>&1 >/dev/null)
vpn_status=$?

#################################
# DISPLAY STATUS ICON
if [[ $vpn_status -eq 0 ]] ; then
  # Connected
  echo '⚡️'
  echo '---'

else
  # Not Connected
  echo "📛"
  echo '---'
fi

#################################
# DISPLAY DROPDOWN MENU 
if [[ $vpn_status -eq 0 ]]; then
  echo "✅ OPENVPN is UP! Disconnect! | bash='$0' color=green param1=openvpn_disconnect refresh=true terminal=false"
else
  echo "🔌 Connect VPN1! | bash='$0' color=brown param1=openvpn_connect_terminal param2=$OVPN_PROFILE_1 refresh=false terminal=false"
  echo "🔌 Connect VPN2! | bash='$0' color=brown param1=openvpn_connect_terminal param2=$OVPN_PROFILE_2 refresh=false terminal=false"

fi

echo '---'
echo "7️⃣ Set Custom DNS | bash='$0' param1=set_dns_servers_internal refresh=true terminal=false"
echo "1️⃣ Set Cloudflare DNS | bash='$0' param1=set_dns_servers_custom param2=1.1.1.1 refresh=true terminal=false"
echo "8️⃣ Set Google DNS | bash='$0' param1=set_dns_servers_custom param2=8.8.8.8 refresh=true terminal=false"
echo "↩️ Unset DNS | bash='$0' param1='set_dns_servers_custom' param2=empty refresh=true terminal=false"

echo "❌ Kill all processes and cleanup! | bash='$0' color=darkred param1=openvpn_disconnect refresh=true terminal=false"
echo "💥 FORCE Kill all | bash='$0' color=darkred param1=openvpn_disconnect param2=force refresh=true terminal=false"

echo '---'
echo "Network service: $NETWORK_SERVICE_NAME"
echo '---'
echo DNS: $(/usr/sbin/networksetup -getdnsservers "$NETWORK_SERVICE_NAME")
echo '---'
echo "✏️ Edit this file | bash='$0' param1=edit_this_script terminal=false"

echo '---'
echo "🔃 Refresh... | refresh=true"