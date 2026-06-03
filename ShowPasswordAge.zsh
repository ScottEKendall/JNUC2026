#!/bin/zsh

# Support App Extension - Show Password Age
#
# Support App Extension to show the age of the current user's password and how many days are left until it expires.
# Tbis script works in tandem with my script that retrieves the password age and last changed date from our Entra Server and writes it to the local users com.GiantEagleEntra.plist.
# Script can be found here: https://github.com/ScottEKendall/JAMF-Pro-System-Scripts/blob/main/Maintenance%20-%20InTune%20-%20Passwords.sh
# 
# Retrieve the currently logged in user and retrieve their home directory
#
# NOTE: you cannot use the $HOME variable in a support.app extension script because the extension runs as root 
# and $HOME will resolve to /var/root which is not what we want. 
LOGGED_IN_USER=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
USER_DIR=$( dscl . -read /Users/${LOGGED_IN_USER} NFSHomeDirectory | awk '{ print $2 }' )

# Location of the com.GiantEagleEntra.plist for the current user
localXMLFile="$USER_DIR/Library/Application Support/com.GiantEagleEntra.plist"

# Location of the Support App preference plist where we will write the password age and days left until expiration
supportAppDir="/Library/Preferences/nl.root3.support.plist"

# support.app Extension ID...this MUST match the extension ID you set in the button
extensionID="GetPasswordAge"

# Set the password age limit in days...this should match the password expiration policy you have set in your Entra Server
passwordLimit=365

# Notification Limit in days...this is the number of days before password expiration that you want to trigger a warning notification for the user
notificationLimit=14

# Set the loading key to true to trigger the loading animation in the Support App while we retrieve
# the password age and calculate days left until expiration
defaults write "$supportAppDir" "${extensionID}_loading" -bool true
sleep .5

# Get password age and calculate days left until password expires
#
# This file is created from the script that retrieves the password age and last changed date from our Entra Server 
# and writes it to the local users com.GiantEagleEntra.plist. 
# If this file doesn't exist or the values can't be read for some reason, we will default to showing (passwordLimit) 
# days left until expiration so that we at least get some output
if [[ -e $localXMLFile ]]; then
    PasswordAge=$(defaults read "$localXMLFile" "PasswordAge")
    LastPasswordChange=$(defaults read "$localXMLFile" "PasswordLastChanged")
else
    PasswordAge=0
    LastPasswordChange=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
fi
dayleft=$((passwordLimit - PasswordAge))

# Reformat the last password change date to something more human readable
LastPasswordChangeDate=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" $LastPasswordChange +"%x")

# Write the text output to Support App preference plist
defaults write "$supportAppDir" "${extensionID}" -string "Changed: ${LastPasswordChangeDate}\n${dayleft} Days Left"

# Trigger an orange warning notification for the user if their password is set to expire within the notification limit
showAlert=false
if [[ $dayleft -le $notificationLimit ]]; then
    showAlert=true
fi
defaults write "$supportAppDir" "${extensionID}_alert" -bool $showAlert

# turn off loading animation
defaults write "$supportAppDir" "${extensionID}_loading" -bool false
