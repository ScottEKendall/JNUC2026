#!/bin/zsh

# Support App Extension - Show Battery Health & Charge-based Icon

# This Support App Extension retrieves the battery health and current charge percentage of a MacBook and displays it in the Support App. 
# It also changes the icon based on the current charge percentage and will trigger an alert if the battery health is not normal or if the maximum capacity is below 80%.

# Location of the Support App preference plist where we will write the password age and days left until expiration
supportAppDir="/Library/Preferences/nl.root3.support.plist"

# support.app Extension ID...this MUST match the extension ID you set in the button
extensionID="BatteryHealth"

# Show an alert if battery health is not normal or if maximum capacity is below 80%
showAlert=true

# Set to true to enable color indicators (red/green circles) for good/bad battery health
colorIndicator="true"

# Set the color circle emojis based on the colorIndicator variable. If color indicators are enabled, we will use green and red circles to indicate good or bad battery health. 
# If disabled, we will just use text with no emojis.
if [[ "$colorIndicator" == "true" ]]; then
    greenCircle="🟢 "
    yellowCircle="🟡 "
    redCircle="🔴 "
else
    greenCircle=""
    yellowCircle=""
    redCircle=""
fi

typeset -g retval=""
typeset -g symbol=""

function getBatteryHealth() 
{
    # Check to see if this is a laptop or desktop. If it's a desktop, we can exit early since there is no battery to check
    if [[ ! "$(system_profiler SPHardwareDataType | grep "Model Name:" | cut -d ' ' -f 9)" =~ "Book" ]]; then
        retval="Not A Laptop"
        symbol="desktopcomputer"
        return
    fi

    # Get the current battery charge percentage
    currentCharge=$(pmset -g batt | awk -F'[\t%]' '/InternalBattery/ {print $2}')

    # If we can't get the current charge for some reason, default to 100% so we at least get a battery icon instead of nothing
    if [[ -z "$currentCharge" ]]; then
        currentCharge=100
    fi

    # Map charge to SF Symbols
    if (( currentCharge > 79 )); then
        symbol="battery.100"
    elif (( currentCharge > 49 )); then
        symbol="battery.75"
    elif (( currentCharge > 24 )); then
        symbol="battery.50"
    elif (( currentCharge >=0 )); then
        symbol="battery.25"
    else
        symbol="battery.0"
    fi

    # Retrieve the current architecture (Apple Silicon or Intel) since the battery information we can retrieve differs between the two
    arch=$(arch)
    HealthCondition=$(system_profiler SPPowerDataType | awk -F': ' '/Condition/ {print $2}' | xargs)
    maxCapacity="100"

    # Get the battery health condition and maximum capacity (if on Apple Silicon)
    if [[ "$arch" == "arm64" ]]; then
        maxCapacity=$(system_profiler SPPowerDataType | awk -F': ' '/Maximum Capacity/ {print $2}' | tr -d '% ' )

        # Determine the status indicator color based on health and capacity
        # Set the retval variable to include the appropriate color indicator and text based on the health condition and maximum capacity. 
        # If the capacity is above 90%, we consider that good health and set it to green. If it's between 80% and 90%, we set it to yellow as a warning. 
        # If it's below 80%, we set it to red to indicate poor health.
        if (( maxCapacity > 89 )); then
            retval=$greenCircle
        elif (( maxCapacity > 79 )); then
            retval=$yellowCircle
        else
            retval=$redCircle
        fi
        retval+=$HealthCondition"\n(Capacity: ${maxCapacity}%)"
    else
        retval=$greenCircle$HealthCondition"\n"
    fi
}

# Set the loading key to true to trigger the loading animation in the Support App while we retrieve the battery information
defaults write "$supportAppDir" "${extensionID}_loading" -bool true
sleep .5

getBatteryHealth

# Set the alert key to true if battery health is not normal or if maximum capacity is below 80%
if [[ $showAlert == "true" ]]; then
    if [[ "$HealthCondition" != "Normal" || $maxCapacity -lt 80 ]]; then
        defaults write "$supportAppDir" "${extensionID}_alert" -bool true
    else
        defaults write "$supportAppDir" "${extensionID}_alert" -bool false
    fi
fi

# Write the text output to Support App preference plist
defaults write "$supportAppDir" "${extensionID}" -string "${indicator}${retval}"

# Show battery icon based on current charge percentage
defaults write "$supportAppDir" "${extensionID}_symbol" -string "${symbol}"

# turn off loading animation
defaults write "$supportAppDir" "${extensionID}_loading" -bool false
clea