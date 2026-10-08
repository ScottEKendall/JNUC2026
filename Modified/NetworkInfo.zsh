#!/bin/zsh
#
# Support App Extension - NetworkInfo
#
# by: Scott Kendall (@ScottKendall on Slack)
#
# Written: 05/15/26
# Last updated: 10/07/26
#
# Support App Extension to show the current IP address of the active network adapter and change the icon based on whether the user is connected via Ethernet, Wi-Fi, or VPN.
# The script checks for an active VPN connection first, then checks for Ethernet (prioritizing wired connections), and finally checks for Wi-Fi. If no active network adapter is found
# it will display a message indicating that and show a generic network icon. The script also supports optional color indicators (green for good, red for alert) based on whether an active adapter is found.
# set -x
#
# Displays the current IPv4 address using this priority:
#   1. Cisco VPN
#   2. Active Ethernet
#   3. Active Wi‑Fi
#   4. No active adapter found
#
# ------------------ Edit Variables Below This Line ------------------ #

# The extensionID variable will be used as a suffix for the keys we write to this plist, so they should be unique for each extension you create.
extensionID="NetworkInfo"

# Set to true to enable color indicators (red/green circles) for good/bad network status
colorIndicator="true"

# ------------------ Do Not Edit Below This Line ------------------ #

# Location of the Support App preference plist where we will write the network status. Make sure this matches the path used by your Support App to read the extension data. 
readonly supportAppDir="/Library/Preferences/nl.root3.support.plist"

# Status indicators
[[ "$colorIndicator" == "true" ]] && greenCircle="🟢 " || greenCircle=""
[[ "$colorIndicator" == "true" ]] && yellowCircle="🟡 " || yellowCircle=""
[[ "$colorIndicator" == "true" ]] && redCircle="🔴 " || redCircle=""

# Defaults

typeset networkStatus="No active adapter found"
typeset networkSymbol="network.slash"
typeset showAlert=false

# Functions

function getCiscoVPNAddress() {
    local vpnBinary
    local vpnAddress

    for vpnBinary in "/opt/cisco/secureclient/bin/vpn" "/opt/cisco/anyconnect/bin/vpn"
    do
        [[ -x "$vpnBinary" ]] || continue

        vpnAddress=$("$vpnBinary" stats 2>/dev/null | /usr/bin/awk -F': ' '/Client Address \(IPv4\)/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}')

        if [[ -n "$vpnAddress" && "$vpnAddress" != "Not Available" ]]; then
            print -r -- "$vpnAddress"
            return 0
        fi
    done

    return 1
}

function getHardwarePortInformation() {
    /usr/sbin/networksetup -listallhardwareports 2>/dev/null
}

function getWiFiInterface() {
    local hardwarePortInformation="$1"
    print -r -- "$hardwarePortInformation" |/usr/bin/awk '/^Hardware Port: (Wi-Fi|AirPort)$/ {getline; if ($1 == "Device:");print $2}'
}

function getEthernetInterfaces() {
    local hardwarePortInformation="$1"
    print -r -- "$hardwarePortInformation" | /usr/bin/awk '/^Hardware Port:/ {hardwarePort = substr($0, index($0, ":") + 2); if (hardwarePort ~ /(Ethernet|LAN)/) {getline;if ($1 == "Device:");print $2}}'
}

function interfaceIsActive() {
    local interfaceName="$1"
    local interfaceInformation

    [[ -n "$interfaceName" ]] || return 1

    interfaceInformation=$(/sbin/ifconfig "$interfaceName" 2>/dev/null) || return 1

    [[ "$interfaceInformation" == *"status: active"* ]]
}

function getInterfaceIPv4Address() {
    local interfaceName="$1"
    local ipAddress

    [[ -n "$interfaceName" ]] || return 1

    ipAddress=$(/usr/sbin/ipconfig getifaddr "$interfaceName" 2>/dev/null)

    [[ -n "$ipAddress" ]] || return 1

    print -r -- "$ipAddress"
    return 0
}

function getNetworkStatus() {

    local vpnAddress
    local hardwarePortInformation
    local wifiInterface
    local ethernetInterface
    local ipAddress

    #
    # VPN Priority
    #

    if vpnAddress=$(getCiscoVPNAddress); then
        networkStatus="${vpnAddress}\n(VPN)"
        networkSymbol="lock.icloud"
        return
    fi

    #
    # Read Hardware Ports Once
    #

    hardwarePortInformation=$(getHardwarePortInformation)

    #
    # Ethernet Priority
    #

    for ethernetInterface in ${(f)"$(getEthernetInterfaces "$hardwarePortInformation")"}; do

        [[ -n "$ethernetInterface" ]] || continue

        interfaceIsActive "$ethernetInterface" || continue

        if ipAddress=$(getInterfaceIPv4Address "$ethernetInterface"); then
            networkStatus="${ipAddress}\n(Ethernet)"
            networkSymbol="network"
            return
        fi

    done

    #
    # Wi‑Fi Fallback
    #

    wifiInterface=$(getWiFiInterface "$hardwarePortInformation")

    if [[ -n "$wifiInterface" ]]; then

        if ipAddress=$(getInterfaceIPv4Address "$wifiInterface"); then
            networkStatus="${ipAddress}\n(Wi‑Fi)"
            networkSymbol="wifi"
            return
        fi

    fi
}

# Start Loading Indicator

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_loading" -bool true

# Get Network Status

getNetworkStatus

# Status Formatting

displayStatus="${greenCircle:+${greenCircle} }${networkStatus}"

if [[ "$networkStatus" == "No active adapter found" ]]; then

    showAlert=true
    displayStatus="${redCircle:+${redCircle} }${networkStatus}"

elif [[ "${networkStatus%%\\n*}" == 169.254.* ]]; then

    showAlert=true
    displayStatus="${yellowCircle:+${yellowCircle} }${networkStatus}"

fi

# Write Support App Values

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_alert" -bool "$showAlert"

/usr/bin/defaults write "$supportAppPlist" "$extensionID" -string "$displayStatus"

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_symbol" -string "$networkSymbol"

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_loading" -bool false

exit 0