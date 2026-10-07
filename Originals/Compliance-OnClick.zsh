#!/bin/zsh

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Author: Jacob Edwards, Mac Admins Slack: @jacobaedwards
#
# Purpose: This is the Click script for a Support.app Compliance custom extension. It retrieves the compliance status determined by
# the the OnAppear script. 
# Ultimately you will need to carefully outline your compliance requirements, determine the best way to verify each. Our requirements
# consist of a minimum macOS version and FileVault (or an exception). You may need to adjust these or add other items. A smart group 
# was created for each compliance component. Then a configuration profile scoped to that smart group distributes a key value. After 
# retrieiving those key values, I show the user their status in a Swift Dialog prompt
#
# This script should be deployed to the Mac to your preferred location. The Support.app configuration profile will reference this 
# location. 
#
# NOTE: For my environment, if a user is not registered, I did not check compliance status any further and instead displayed
# "Not Registered" in the compliance extension. 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
set -x
# Extension IDs added for Support app 3.0 config
extension_id="compliance"

# Support App preference plist
preference_file_location="/Library/Preferences/nl.root3.support.plist"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#   VARIABLES TO SET
# 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# NOT REGISTERED
## pSSO Profile present: retrigger the Company Portal registration notification
#### NAME OR PARTIAL NAME OF YOUR PLATFORM SSO CONFIGURATION PROFILE
psso_profile="Platform SSO"
## No pSSO Profile present: open the Self Service registration policy. Alternatively, you could encourage the user to opt-in for pSSO 
#### Jamf Policy ID of Self Service traditional registration policy
policy_id="9"                    # Jamf Pro policy ID number
policy_action="view"			    # "view" or "execute"
# path to and name of plist storing the compliance status and component key values.
compliancePlistPath="/Library/Managed Preferences/com.gianteagle.compliance.plist"
# path to Icons directory for icons used on the swift dialog compliance report. 
iconPath="/System/Application"
# overlay icon for the Swift Dialog compliance report.
passIcon="success"
failIcon="fail"
overlay_icon="SF=person.text.rectangle,weight=heavy"

# See if there is a "defaults" file...if so, read in the contents
DEFAULTS_DIR="/Library/Managed Preferences/com.gianteaglescript.defaults.plist"
echo "Setting Default values"
SUPPORT_DIR=$(defaults read "$DEFAULTS_DIR" SupportFiles 2>/dev/null) || SUPPORT_DIR="/Library/Application Support/GiantEagle"
SD_BANNER_IMAGE=$(defaults read "$DEFAULTS_DIR" BannerImage 2>/dev/null) || SD_BANNER_IMAGE="GE_SD_BannerImage.png"
BANNER_TEXT_PADDING=$(defaults read "$DEFAULTS_DIR" BannerPadding 2>/dev/null) || BANNER_TEXT_PADDING=10
BANNER_SUBTITLE=$(defaults read "$DEFAULTS_DIR" BannerSubtitle 2>/dev/null) || BANNER_SUBTITLE=""
BANNER_TEXT_COLOR=$(defaults read "$DEFAULTS_DIR" TitleFontColor 2>/dev/null) || BANNER_TEXT_COLOR="white"

[[ -e $SUPPORT_DIR/$SD_BANNER_IMAGE ]] && SD_BANNER_IMAGE="$SUPPORT_DIR/$SD_BANNER_IMAGE"

SD_WINDOW_TITLE="Compliance Report"
# text on dialogs
not_compliant_infobox_message="This Mac **does not meet** compliance requirements.\n\nThis status may not reflect recent changes. If you are having problems with device compliance, please contact the TSD."
compliant_infobox_message="This Mac **meets** compliance requirements.\n\nThis status may not reflect recent changes. If you are having problems with device compliance, please contact the TSD."
not_registered_message="This Mac is **not registered**. Please register the Mac to generate a compliance report."
# # # # END VARIABLES TO SET # # # #

dialog_json="/tmp/dialogjson.json"

# Start spinning indicator
defaults write "${preference_file_location}" "${extension_id}_loading" -bool true

# Get the compliance and registration status
complianceStatus=$(defaults read "${preference_file_location}" "$extension_id" 2> /dev/null)
registrationStatus=$(defaults read "${preference_file_location}" "registration" 2> /dev/null)
# Wait for compliance and registration tiles before proceeding
until [[ "$complianceStatus" != "Checking status" ]] && [[ "$complianceStatus" != "" ]]; do
    sleep 0.1
    complianceStatus=$(defaults read "${preference_file_location}" "$extension_id" 2> /dev/null)
   registrationStatus=$(defaults read "${preference_file_location}" "registration" 2> /dev/null)
done


function checkComplianceComponents() 
{
    computerName=$(scutil --get ComputerName)
    
    # Check for various Configuration Profile key values. These are a proxy for checking everything directly and changes may be delayed until inventory updates and the profiles install or remove
    [[ $(defaults read "${compliancePlistPath}" "JAMF_Compliant" 2> /dev/null) ]] && compliance="Yes" || compliance="No"
    [[ $(defaults read "${compliancePlistPath}" "Minimum_OS_met" 2> /dev/null) ]] && macos_minimum="Yes" || macos_minimum="No"
    [[ $(defaults read "${compliancePlistPath}" "FileVault_enabled" 2> /dev/null) ]] && filevault="Yes" || filevault="No"
    [[ $(defaults read "${compliancePlistPath}" "zScaler_enabled" 2> /dev/null) ]] && zScaler="Yes" || zScaler="No"
    [[ $(defaults read "${compliancePlistPath}" "Crowdstrike_enabled" 2> /dev/null) ]] && crowdstrike="Yes" || crowdstrike="No"
    
    # Adjust the icon and title for Swift Dialog based on the status
    if [[ "$registrationStatus" == *"Not Registered" ]]; then
        registrationIcon="$failIcon"
    elif [[ "$registrationStatus" == *"Platform SSO" ]] || [[ "$registrationStatus" == *"Registered" ]]; then
        registrationIcon="$passIcon"
    fi

    [[ "$compliance" == "Yes" ]] && complianceIcon="$passIcon" || complianceIcon="$failIcon"
    [[ "$macos_minimum" == "Yes" ]] && macosIcon="$passIcon" || macosIcon="$failIcon"
    [[ "$zScaler" == "Yes" ]] && zScalerIcon="$passIcon" || zScalerIcon="$failIcon"
    [[ "$crowdstrike" == "Yes" ]] && crowdstrikeIcon="$passIcon" || crowdstrikeIcon="$failIcon"
    [[ "$filevault" == "Yes" ]] && filevaultIcon="$passIcon" || filevaultIcon="$failIcon"
    
    filevaultTitle="FileVault"
    [[ "$filevault" == "Yes" ]] && filevaultStatus="$filevault" || filevaultStatus="No"
}

checkComplianceComponents


    jq -n \
        --arg computerName "$computerName" \
        --arg registrationStatus "$registrationStatus" \
        --arg registrationIcon "$registrationIcon" \
        --arg compliance "$compliance" \
        --arg complianceIcon "$complianceIcon" \
        --arg macosMinimum "$macos_minimum" \
        --arg macosIcon "$macosIcon" \
        --arg filevaultIcon "$filevaultIcon" \
        --arg filevaultStatus "$filevaultStatus" \
        --arg zScaler "$zScaler" \
        --arg zScalerIcon "$zScalerIcon" \
        --arg crowdstrike "$crowdstrike" \
        --arg crowdstrikeIcon "$crowdstrikeIcon" \
        '{
            listitem: [
                {title:"Mac Name",statustext:$computerName},
                {title:"Registration",statustext:$registrationStatus,status:$registrationIcon},
                {title:"Compliance Status",statustext:$compliance,status:$complianceIcon},
                {title:"macOS Minimum",statustext:$macosMinimum,status:$macosIcon},
                {title:"Disk Encrypted",statustext:$filevaultStatus,status:$filevaultIcon},
                {title:"zScaler Installed",statustext:$zScaler,status:$zScalerIcon},
                {title:"Crowdstrike Installed",statustext:$crowdstrike,status:$crowdstrikeIcon}
            ]
        }' > "$dialog_json"



message=""
infomessage="$compliant_infobox_message"
if [[ "$complianceStatus" == *"Not Compliant"* ]]; then
    message="**One or more items are not compliant.**"
    infomessage="$not_compliant_infobox_message"
fi

if [[ "$complianceStatus" != *"Not Registered" ]]; then
    /usr/local/bin/dialog --bannerimage "$SD_BANNER_IMAGE" \
        --bannertitle "$SD_WINDOW_TITLE" \
        --subtitle "$BANNER_SUBTITLE" \
        --titlefont "shadow=1,color=${BANNER_TEXT_COLOR},offset=${BANNER_TEXT_PADDING}" \
        --icon "$SD_ICON_FILE" --message "$message" --width 700 --height 500 --ontop --overlayicon "$overlay_icon" \
        --icon computer --moveable --jsonfile "$dialog_json" \
        --infobox "$infomessage"

else
        # Show a Not Registered dialog
        /usr/local/bin/dialog --message "$not_registered_message" \
        --small --ontop --overlayicon "$overlay_icon" --icon computer --title "Compliance Report" \
        --moveable --button2text "Register Now"
        
        dialogExitCode=$?

        case "$dialogExitCode" in
            0)
                # User clicked OK
            ;;
                
            2)
                # User clicked Register Now button
                # If pSSO config present, relaunch notification
                # FUTURE CONSIDERATION: If pSSO config not present, show dialog with buttons to switch to pSSO or open traditional registration policy in Self Service
                
                # check for Platform SSO profile presence
                pSSOProfileCheck=$(/usr/bin/profiles -C -v | grep attribute | awk '/name/{$1=$2=$3=""; print $0}' | sed 's/^ *//' | grep -i "${psso_profile}" &> /dev/null && echo "true" || echo "false")
                # if Platform SSO profile is present AND Mac isn't registered
                if [[ "$pSSOProfileCheck" == "true" ]]; then
                    # This should cause the Company Portal registration notification to reappear in the upper right corner or in the Notification Center tray
                    # General idea from https://github.com/ScottEKendall/Microsoft-Platform-SSO
                    pkill -9 -x "AppSSOAgent"
                    /usr/bin/app-sso -l > /dev/null 2>&1

                else

                    selfServicePolicyURL="jamfselfservice://content?entity=policy&id=${policy_id}&action=${policy_action}"

                    # Open the Self Service registration policy
                    if [[ "$policy_action" == "view" ]]; then
                        # Open Self Service to the specified policy. User can choose to execute the policy or not.
                        su "${loggedInUser}" -c "/usr/bin/open \"${selfServicePolicyURL}\""
                    elif [[ "$policy_action" == "execute" ]]; then
                        # Open Self Service in the background and execute the specified policy.
                        su "${loggedInUser}" -c "/usr/bin/open -j \"${selfServicePolicyURL}\""
                    fi
                    # Or use this as opportunity to set them up with Platform SSO
                fi
            ;;

            *)
                # Something else happened
            ;;

        esac
fi

# Stop spinning indicator
defaults write "${preference_file_location}" "${extension_id}_loading" -bool false

exit