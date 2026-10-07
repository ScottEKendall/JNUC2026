#!/bin/zsh
#
# Support App Extension - NetworkInfo
#
# by: Scott Kendall (@ScottKendall on Slack)
#
# Written:      05/15/26
# Last Updated: 10/07/26
#
# Displays the current IPv4 address using this priority:
#   1. Cisco VPN
#   2. Active Ethernet
#   3. Active Wi‑Fi
#   4. No active adapter found
#

# ------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------

readonly supportAppPlist="/Library/Preferences/nl.root3.support.plist"
readonly extensionID="NetworkInfo"
readonly colorIndicator=true

# ------------------------------------------------------------------------
# UI Indicators
# ------------------------------------------------------------------------

if [[ "$colorIndicator" == true ]]; then
    readonly greenCircle="🟢"
    readonly yellowCircle="🟡"
    readonly redCircle="🔴"
else
    readonly greenCircle=""
    readonly yellowCircle=""
    readonly redCircle=""
fi

# ------------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------------

typeset networkStatus="No active adapter found"
typeset networkSymbol="network.slash"
typeset showAlert=false

# ------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------

function getCiscoVPNAddress() {
    local vpnBinary
    local vpnAddress

    for vpnBinary in "/opt/cisco/secureclient/bin/vpn" "/opt/cisco/anyconnect/bin/vpn"
    do
        [[ -x "$vpnBinary" ]] || continue

        vpnAddress=$("$vpnBinary" stats 2>/dev/null | /usr/bin/awk -F': ' '/Client Address \(IPv4\)/ {
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
                    print $2
                    exit}'
)

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

    print -r -- "$hardwarePortInformation" |/usr/bin/awk '/^Hardware Port: (Wi-Fi|AirPort)$/ {
            getline
            if ($1 == "Device:")
                print $2}'
}

function getEthernetInterfaces() {
    local hardwarePortInformation="$1"

    print -r -- "$hardwarePortInformation" | /usr/bin/awk '/^Hardware Port:/ {
            hardwarePort = substr($0, index($0, ":") + 2)

            if (hardwarePort ~ /(Ethernet|LAN)/) {
                getline

                if ($1 == "Device:")
                    print $2
            }
        }'
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

# ------------------------------------------------------------------------
# Start Loading Indicator
# ------------------------------------------------------------------------

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_loading" -bool true

# ------------------------------------------------------------------------
# Get Network Status
# ------------------------------------------------------------------------

getNetworkStatus

# ------------------------------------------------------------------------
# Status Formatting
# ------------------------------------------------------------------------

displayStatus="${greenCircle:+${greenCircle} }${networkStatus}"

if [[ "$networkStatus" == "No active adapter found" ]]; then

    showAlert=true
    displayStatus="${redCircle:+${redCircle} }${networkStatus}"

elif [[ "${networkStatus%%\\n*}" == 169.254.* ]]; then

    showAlert=true
    displayStatus="${yellowCircle:+${yellowCircle} }${networkStatus}"

fi

# ------------------------------------------------------------------------
# Write Support App Values
# ------------------------------------------------------------------------

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_alert" -bool "$showAlert"

/usr/bin/defaults write "$supportAppPlist" "$extensionID" -string "$displayStatus"

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_symbol" -string "$networkSymbol"

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_loading" -bool false

exit 0