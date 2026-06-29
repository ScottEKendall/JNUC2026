#!/bin/zsh
#
# Support App Extension - Registration Info
#
# by: Scott Kendall (@ScottKendall on Slack)
#
# Written: 05/15/26
# Last updated: 06/29/26
# Support App Extension to show the registration status (pSSO) of the current user

# Extension ID added for Support app 3.0 config
extension_id="registration"

# Use color indicators for compliance status
color_indicators="true"  # Set to "true" to use the color circle emojis, "false" or anything else for no emojis
if [[ "$color_indicators" == "true" ]]; then
    green_circle="🟢 "
    yellow_circle="🟡 "
    red_circle="🔴 "
else
    green_circle=""
    yellow_circle=""
    red_circle=""
fi

# Support App preference plist
preference_file_location="/Library/Preferences/nl.root3.support.plist"

# Start spinning indicator
defaults write "${preference_file_location}" "${extension_id}_loading" -bool true

# Replace value with placeholder while loading
defaults write "${preference_file_location}" "${extension_id}" -string "Checking status"

# Keep loading effect active specified time
sleep 0.25

# Initialize compliance indicator
complianceIndicator=""

# DETERMINE CURRENT REGISTRATION STATUS
checkUserRegistration() {
    loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
    jamfCA="/Library/Application Support/JAMF/Jamf.app/Contents/MacOS/Jamf Conditional Access.app/Contents/MacOS/JAMF Conditional Access"

    # More efficient user home directory retrieval in zsh
    userHome=$(dscl . -read "/Users/$loggedInUser" NFSHomeDirectory | cut -d' ' -f2)

    # Apple Platform SSO registration check with zsh-optimized parsing
    platformStatus=$(su "$loggedInUser" -c "app-sso platform -s" 2>/dev/null | awk '/registration/ {gsub(/,/, ""); print $3}')

    # Zsh-specific parameter expansion and conditional checks
    if [[ "$platformStatus" == "true" ]]; then
        # Simplified check for jamfAAD registration
        if [[ -f "$userHome/Library/Preferences/com.jamf.management.jamfAAD.plist" ]] && 
            defaults read "$userHome/Library/Preferences/com.jamf.management.jamfAAD.plist" have_an_Azure_id &>/dev/null; then
            registrationStatus="${green_circle}Platform SSO"
            return 0
        fi
        registrationStatus="${yellow_circle}Platform SSO, Error"
        return 0
    else
        # If the apple platform SSO command doesn't show as registered, then test the JAMF CA command
        jamfpSSOStatus=$("${jamfCA}" getPSSOStatus | head -n 1)
        case $jamfpSSOStatus in
            1 )
                return 0
                ;;
            2 )
                registrationStatus="${green_circle}Platform SSO"

                return 0
                ;;
        esac
    fi

    # WPJ key check with zsh parameter expansion
    if security dump "$userHome/Library/Keychains/login.keychain-db" | grep -q MS-ORGANIZATION-ACCESS; then
        plist="$userHome/Library/Preferences/com.jamf.management.jamfAAD.plist"
        
        # Zsh file test and plist check
        if [[ ! -f "$plist" ]]; then
            registrationStatus="${yellow_circle}Registered, Error"
            return 0
        fi

        # Check AAD ID acquisition
        if defaults read "$plist" have_an_Azure_id &>/dev/null; then
            registrationStatus="${green_circle}Registered"
            return 0
        fi

        registrationStatus="${yellow_circle}Registered, Error"
        return 0
    fi

    registrationStatus="${yellow_circle}Not Registered"
}

checkUserRegistration

# Write output to Support App preference plist
defaults write "${preference_file_location}" "${extension_id}" -string "${registrationStatus}"

# Stop spinning indicator
defaults write "${preference_file_location}" "${extension_id}_loading" -bool false

exit