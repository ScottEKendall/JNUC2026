#!/bin/zsh

# Support App Extension - NetworkInfo
#
# Support App Extension to show the current IP address of the active network adapter and change the icon based on whether the user is connected via Ethernet, Wi-Fi, or VPN.
# The script checks for an active VPN connection first, then checks for Ethernet (prioritizing wired connections), and finally checks for Wi-Fi. If no active network adapter is found
# it will display a message indicating that and show a generic network icon. The script also supports optional color indicators (green for good, red for alert) based on whether an active adapter is found.
# set -x

# Location of the Support App preference plist where we will write the network status. Make sure this matches the path used by your Support App to read the extension data. 
supportAppDir="/Library/Preferences/nl.root3.support.plist"

# The extensionID variable will be used as a suffix for the keys we write to this plist, so they should be unique for each extension you create.
extensionID="NetworkInfo"

# Set to true to enable color indicators (red/green circles) for good/bad network status
colorIndicator="true"

# Setup UI indicators
if [[ "$colorIndicator" == "true" ]]; then
    greenCircle="🟢"
    yellowCircle="🟡 "
    redCircle="🔴"
else
    greenCircle=""
    yellowCircle=""
    redCircle=""
fi

# Default status and alert level
typeset -g ShowAlert=false

# Initialize global variables for symbol and return value. These will be updated by the getNetworkStatus function based on the current network status. 
# The symbol variable will be used to set the appropriate SF Symbol icon in the Support App, and the retval variable will contain the text output (IP address and connection type or an error message).
typeset -g retval="No active adapter found"
typeset -g symbol="network.slash"

function getNetworkStatus()
{
    local ip vpn_bin
    
    # 1. Check VPN (Highest Priority)
    # Use -e (exists) and find the first match quickly
    # Change this logic if you use a different VPN client or have a custom setup. This example checks for Cisco AnyConnect and Secure Client.
    for bin in "/opt/cisco/secureclient/bin/vpn" "/opt/cisco/anyconnect/bin/vpn"; do
        if [[ -e "$bin" ]]; then
            vpn_bin="$bin"
            break
        fi
    done

    # If we found a VPN client, check if we're connected and get the IP address
    # If a connection is found, retrieve the IP address and set the symbol to a lock to indicate VPN.
    # This logic may need to be adjusted based on the specific output of your VPN client's status command. The example shown is for Cisco AnyConnect/Secure Client.
    if [[ -n "$vpn_bin" ]]; then
        ip=$($vpn_bin stats 2>/dev/null | awk -F': ' '/Client Address \(IPv4\)/ {print $2}' | xargs)
        if [[ -n "$ip" && "$ip" != "Not Available" ]]; then
            retval="${ip}\n(VPN)"
            symbol="lock.icloud"
            return
        fi
    fi

    # 2. Check Ethernet (Prioritize wired)
    # Find active services and filter for Ethernet-like names
    # If found, retrieve the IP address and set the symbol to a desktop computer to indicate wired connection.
    local eth_dev=$(networksetup -listnetworkserviceorder | awk -F'Device: ' '/Ethernet|LAN/ {print $2}' | tr -d ')')
    for dev in ${(f)eth_dev}; do
        ip=$(ipconfig getifaddr "$dev" 2>/dev/null)
        if [[ -n "$ip" ]]; then
            retval="${ip}\n(Ethernet)"
            symbol="network"
            return
        fi
    done

    # 3. Check Wi-Fi
    # Check for active Wi-Fi connection and retrieve the IP address. Set the symbol to a Wi-Fi icon if connected.
    local wifi_dev=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')
    ip=$(ipconfig getifaddr "$wifi_dev" 2>/dev/null)
    if [[ -n "$ip" ]]; then
        retval="${ip}\n(Wi-Fi)"
        symbol="wifi"
        return
    fi
}



# Set the loading key to true to trigger the loading animation in the Support App while we retrieve the battery information
defaults write "$supportAppDir" "${extensionID}_loading" -bool true
sleep 0.5

# Fetch info (modifies globals)
getNetworkStatus


# If the retval contains "No active", we consider that an alert state and set the text color to red. Otherwise, we set it to green.
# The symbol is set based on the type of connection found (VPN, Ethernet, Wi-Fi, or no connection)
if [[ "$retval" == "No active"* ]]; then
    ShowAlert=true
    nicStatu="${redCircle} ${retval}"
elif [[ "$retval" == *"169.254"* ]]; then
    # If the NIC shows a self assigned address, then show an alert and change the icon to yellow
    ShowAlert=true
    nicStatu="${yellowCircle} ${retval}"
else
    nicStatu="${greenCircle} ${retval}"
fi

# Write output to Support App preference plist
defaults write "$supportAppDir" "${extensionID}_alert" -bool "$ShowAlert"

# Write the text output to Support App preference plist
defaults write "$supportAppDir" "${extensionID}" -string "${nicStatu}"

# Show network icon based on connection type
defaults write "$supportAppDir" "${extensionID}_symbol" -string "${symbol}"

# turn off loading animation
defaults write "$supportAppDir" "${extensionID}_loading" -bool false
