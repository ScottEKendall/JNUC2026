#!/bin/zsh
#
# Support App Extension - Show Battery Health & Charge-based Icon
#
# by: Scott Kendall (@ScottKendall on Slack)
#
# Written: 05/15/26
# Last updated: 10/08/26
#
# Retrieves battery health and current charge percentage and displays
# the results in Support App. The SF Symbol changes according to the
# current charge percentage.
#

# ------------------ Edit Variables Below This Line ------------------ #

# Must match the extension ID configured in Support App.
readonly extensionID="BatteryHealth"

# Alert when battery health is abnormal or maximum capacity is below 80%.
readonly showAlert="true"

# Display colored status indicators.
readonly colorIndicator="true"

# ------------------ Do Not Edit Below This Line ------------------ #

# Support App preference plist.
readonly supportAppPlist="/Library/Preferences/nl.root3.support.plist"

# Extension output values.
typeset retval=""
typeset symbol="battery.0"
integer maxCapacity=100
typeset healthCondition="Normal"
typeset isAlert="false"

[[ "$colorIndicator" == "true" ]] && greenCircle="🟢 " || greenCircle=""
[[ "$colorIndicator" == "true" ]] && yellowCircle="🟡 " || yellowCircle=""
[[ "$colorIndicator" == "true" ]] && redCircle="🔴 " || redCircle=""

getBatteryHealth() {
    local powerData=""
    integer currentCharge=0
    integer rawMax=0
    integer designCapacity=0
    integer permanentFailureStatus=0

    # Retrieve all required battery information with one ioreg call.
    powerData=$(/usr/sbin/ioreg -r -c AppleSmartBattery 2>/dev/null)

    # No AppleSmartBattery entry means the Mac does not have a battery.
    if [[ -z "$powerData" ]]; then
        retval="Not A Laptop"
        symbol="desktopcomputer"
        return 0
    fi

    # Current charge percentage.
    if [[ "$powerData" =~ '"CurrentCapacity" = ([0-9]+)' ]]; then
        currentCharge=${match[1]}
    fi

    # Clamp unexpected values to the valid percentage range.
    (( currentCharge < 0 ))   && currentCharge=0
    (( currentCharge > 100 )) && currentCharge=100

    # Select the charge-based SF Symbol.
    if (( currentCharge >= 75 )); then      symbol="battery.100"
    elif (( currentCharge >= 50 )); then    symbol="battery.75"
    elif (( currentCharge >= 25 )); then    symbol="battery.50"
    elif (( currentCharge > 5 )); then      symbol="battery.25"
    else                                    symbol="battery.0"
    fi

    # Check the permanent battery failure status.
    if [[ "$powerData" =~ '"PermanentFailureStatus" = ([0-9]+)' ]]; then
        permanentFailureStatus=${match[1]}
        (( permanentFailureStatus != 0 )) && healthCondition="Service Battery"
    fi

    # Calculate maximum capacity when both values are available.
    [[ "$powerData" =~ '"AppleRawMaxCapacity" = ([0-9]+)' ]] && rawMax=${match[1]}

    [[ "$powerData" =~ '"DesignCapacity" = ([0-9]+)' ]] && designCapacity=${match[1]}

    if (( rawMax > 0 && designCapacity > 0 )); then
        maxCapacity=$(( rawMax * 100 / designCapacity ))

        # Prevent unusual battery data from reporting more than 100%.
        (( maxCapacity > 100 )) && maxCapacity=100
        (( maxCapacity < 0 ))   && maxCapacity=0

        if (( maxCapacity >= 90 )); then    retval="${greenCircle}"
        elif (( maxCapacity >= 80 )); then  retval="${yellowCircle}"
        else                               retval="${redCircle}"
        fi

        retval+="${healthCondition}"
    else
        # Fallback when capacity data is unavailable.
        if [[ "$healthCondition" == "Normal" ]]; then
            retval="${greenCircle}${healthCondition}"
        else
            retval="${redCircle}${healthCondition}"
        fi
    fi
    retval+="\n(Capacity: ${maxCapacity}%)"
}

# Enable the Support App loading indicator.
/usr/bin/defaults write "$supportAppPlist" "${extensionID}_loading" -bool true
sleep .1

getBatteryHealth

# Determine alert state from the underlying health values rather than
# searching the formatted display string.
if [[ "$showAlert" == "true" && "$retval" != "Not A Laptop" ]]; then
    [[ "$healthCondition" != "Normal" ]] || (( maxCapacity < 80 )) && isAlert="true"
fi

# Write the completed extension values.
/usr/bin/defaults write "$supportAppPlist" "${extensionID}_alert" -bool "$isAlert"

/usr/bin/defaults write "$supportAppPlist" "${extensionID}" -string "$retval"

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_symbol" -string "$symbol"

/usr/bin/defaults write "$supportAppPlist" "${extensionID}_loading" -bool false

exit 0