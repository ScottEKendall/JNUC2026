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

declare -g retval=""
declare -g symbol=""
declare -g maxCapacity=100

function getBatteryHealth() {
    # 1. Read the I/O Kit power registry once into memory (Instantaneous)
    # Extracts MaxCapacity, DesignCapacity, and Condition efficiently
    local powerData
    powerData=$(ioreg -n AppleSmartBattery -r 2>/dev/null)

    # 2. Check if it's a laptop by checking if battery registry data exists
    if [[ -z "$powerData" ]]; then
        retval="Not A Laptop"
        symbol="desktopcomputer"
        return
    fi

    # 3. Fast extraction of current charge using pmset
    currentCharge=$(pmset -g batt | awk -F'[\t%]' '/InternalBattery/ {print $2}')
    currentCharge=${currentCharge:-100} # Zsh native fallback default

    # 4. Map charge to SF Symbols (Your optimized range logic)
    symbol="battery.0"
    if (( currentCharge > 79 )); then
        symbol="battery.100"
    elif (( currentCharge > 49 )); then
        symbol="battery.75"
    elif (( currentCharge > 24 )); then
        symbol="battery.50"
    elif (( currentCharge >= 0 )); then
        symbol="battery.25"
    fi

    # 5. Extract Health Condition using Zsh native regex (No grep/awk/xargs needed)
    HealthCondition="Normal"
    if [[ "$powerData" =~ '"PermanentFailureStatus" = ([0-9]+)' && "${match[1]}" != "0" ]]; then
        HealthCondition="Service Battery"
    fi

    # 6. Check architecture natively using Zsh parameters
    local arch_type
    arch_type=$(sysctl -n hw.optional.arm64 2>/dev/null)

    if [[ "$arch_type" == "1" ]]; then
        # Apple Silicon: Calculate Maximum Capacity (State of Health)
        # Formula: (AppleRawMaxCapacity / DesignCapacity) * 100
        
        [[ "$powerData" =~ '"AppleRawMaxCapacity" = ([0-9]+)' ]] && rawMax=${match[1]}
        [[ "$powerData" =~ '"DesignCapacity" = ([0-9]+)' ]] && designCap=${match[1]}

        if [[ -n "$rawMax" && -n "$designCap" ]]; then
            (( maxCapacity = (rawMax * 100) / designCap ))
        else
            maxCapacity=100
        fi

        # Determine color circle based on maximum capacity calculations
        if (( maxCapacity > 89 )); then
            retval=$greenCircle
        elif (( maxCapacity > 79 )); then
            retval=$yellowCircle
        else
            retval=$redCircle
        fi
        retval+="${HealthCondition}\n(Capacity: ${maxCapacity}%)"
    else
        # Intel Mac default fallback
        retval="${greenCircle}${HealthCondition}\n"
    fi
}


# Set the loading key to true to trigger the loading animation in the Support App while we retrieve the battery information
defaults write "$supportAppDir" "${extensionID}_loading" -bool true
sleep .5

getBatteryHealth

# Set the alert key to true if battery health is not normal or if maximum capacity is below 80%
if [[ $showAlert == "true" ]]; then
    if [[ "$retval" != *"Normal"* ]] || (( $maxCapacity < 80 )); then
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
