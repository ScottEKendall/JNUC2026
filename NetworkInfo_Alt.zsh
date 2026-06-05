#!/bin/zsh

# Support App Extension - NetworkInfo
#
# Support App Extension to show the current IP address of the active network adapter and change the icon based on whether the user is connected via Ethernet, Wi-Fi, or VPN.
# The script checks for an active VPN connection first, then checks for Ethernet (prioritizing wired connections), and finally checks for Wi-Fi. If no active network adapter is found
# it will display a message indicating that and show a generic network icon. The script also supports optional color indicators (green for good, red for alert) based on whether an active adapter is found.
#set -x

# Location of the Support App preference plist where we will write the network status. Make sure this matches the path used by your Support App to read the extension data. 
supportAppDir="/Library/Preferences/nl.root3.support.plist"

# The extensionID variable will be used as a suffix for the keys we write to this plist, so they should be unique for each extension you create.
extensionID="NetworkInfo"

# Set to true to enable color indicators (red/green circles) for good/bad network status
colorIndicator="true"

# Setup UI indicators
if [[ "$colorIndicator" == "true" ]]; then
    local greenCircle="🟢" yellowCircle="🟡 " redCircle="🔴"
else
    local greenCircle="" yellowCircle="" redCircle=""
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
        vpn_stats=$($vpn_bin stats 2>/dev/null)
        if [[ "$vpn_stats" =~ 'Client Address \(IPv4\):[[:space:]]*([0-9.]+)' ]]; then
            ip=${match[1]}
            if [[ -n "$ip" && "$ip" != "Not Available" ]]; then
                retval="${ip}\n(VPN)"
                symbol="lock.icloud"
                return
            fi
        fi
    fi

    # 2. Extract the true Active Network Device from the kernel routing states (Instantaneous)
    # The first interface name appearing after "interface:" is the absolute active primary route.
    route_data=$(route -n get default 2>/dev/null)
    
    if [[ "$route_data" =~ 'interface:[[:space:]]*([a-zA-Z0-9]+)' ]]; then
        primary_dev=${match[1]}
    else
        return # No active gateway, falls back to "No active adapter found"
    fi

    # 3. Retrieve the IP using the optimized hardware adapter ID
    ip=$(ipconfig getifaddr "$primary_dev" 2>/dev/null)
    [[ -z "$ip" ]] && return

    # 4. Map the BSD device ID (en0, en1) to its matching type without networksetup
    if [[ "$primary_dev" == utun* ]]; then
        type_label="VPN"
        symbol="lock.icloud"
    elif [[ "$primary_dev" == en0 ]]; then
        # MacBooks always use en0 for Wi-Fi. Desktops vary, but en0 remains the primary wireless layout.
        type_label="Wi-Fi"
        symbol="wifi"
    else
        # Any other en* interface (Thunderbolt, USB Ethernet, or PCIe) is a wired asset.
        type_label="Ethernet"
        symbol="network"
    fi

    retval="${ip}\n(${type_label})"
}

# Set the loading key to true to trigger the loading animation in the Support App while we retrieve the battery information
defaults write "$supportAppDir" "${extensionID}_loading" -bool true
sleep 0.25

# Fetch network (modifies globals)
getNetworkStatus

# If the retval contains "No active", we consider that an alert state and set the text color to red. Otherwise, we set it to green.
# The symbol is set based on the type of connection found (VPN, Ethernet, Wi-Fi, or no connection)

if [[ "$retval" == "No active"* ]]; then
    ShowAlert=true
    nicStatus="${redCircle} ${retval}"
elif [[ "$retval" == *"169.254"* ]]; then
    ShowAlert=true
    nicStatus="${yellowCircle} ${retval}"
else
    nicStatus="${greenCircle} ${retval}"
fi
# Write output to Support App preference plist
defaults write "$supportAppDir" "${extensionID}_alert" -bool "$ShowAlert"

# Write the text output to Support App preference plist
defaults write "$supportAppDir" "${extensionID}" -string "${nicStatus}"

# Show network icon based on connection type
defaults write "$supportAppDir" "${extensionID}_symbol" -string "${symbol}"

# turn off loading animation
defaults write "$supportAppDir" "${extensionID}_loading" -bool false
