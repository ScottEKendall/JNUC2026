#!/bin/zsh
#
# Support App Extension - Show Password Age
#
# Displays:
#   - Last password change date
#   - Days remaining until expiration
#
# Reads data from:
# ~/Library/Application Support/com.GiantEagleEntra.plist
#
# Compatible with macOS BSD utilities
#

readonly supportAppPlist="/Library/Preferences/nl.root3.support.plist"
readonly extensionID="GetPasswordAge"

readonly passwordLimit=365
readonly notificationLimit=14
readonly colorIndicators=true

# Get Logged In User

loggedInUser=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && $3 != "loginwindow" { print $3 }')
userHome=$(/usr/bin/dscl . -read "/Users/$loggedInUser" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')
localPlist="$userHome/Library/Application Support/com.GiantEagleEntra.plist"

# UI Indicators

if [[ "$colorIndicators" == true ]]; then
    readonly greenCircle="🟢 "
    readonly yellowCircle="🟡 "
    readonly redCircle="🔴 "
else
    readonly greenCircle=""
    readonly yellowCircle=""
    readonly redCircle=""
fi

# Enable Loading Indicator
/usr/bin/defaults write "$supportAppPlist" "${extensionID}_loading" -bool true
sleep .1

# Retrieve Password Information
PasswordAge=0
LastPasswordChange=$(/bin/date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ -r "$localPlist" ]]; then

    tmpPasswordAge=$(/usr/bin/defaults read "$localPlist" PasswordAge 2>/dev/null)

    tmpLastPasswordChange=$(/usr/bin/defaults read "$localPlist" PasswordLastChanged 2>/dev/null)

    [[ "$tmpPasswordAge" =~ ^[0-9]+$ ]] && PasswordAge="$tmpPasswordAge"

    [[ -n "$tmpLastPasswordChange" ]] && LastPasswordChange="$tmpLastPasswordChange"
fi

# Calculate Remaining Days
daysLeft=$(( passwordLimit - PasswordAge ))

# Prevent negative values
(( daysLeft < 0 )) && daysLeft=0

# Determine Color Status
if (( daysLeft > notificationLimit )); then statusIndicator="$greenCircle"
elif (( daysLeft > 7 )); then               statusIndicator="$yellowCircle"
else                                        statusIndicator="$redCircle"
fi

# Format Date
LastPasswordChangeDate=$(/bin/date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LastPasswordChange" "+%x" 2>/dev/null)

[[ -n "$LastPasswordChangeDate" ]] || LastPasswordChangeDate="Unknown"

# Alert Logic
showAlert=false
(( daysLeft <= notificationLimit )) && showAlert=true

# Build Output
displayText="Changed: ${LastPasswordChangeDate}\n${statusIndicator}${daysLeft} Days Left"

# Write Support App Values
/usr/bin/defaults write "$supportAppPlist" "$extensionID" -string "$displayText"

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_alert" -bool "$showAlert"

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_loading" -bool false

exit 0