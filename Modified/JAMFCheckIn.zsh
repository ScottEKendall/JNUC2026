#!/bin/zsh
#
# Support App Extension - JAMF Checkin
#
# by: Scott Kendall (@ScottKendall on Slack)
#
# Written: 05/15/26
# Last updated: 10/08/26

# This Support App Extension retrieves the last time the JAMF policy (checkin) was run.

# ------------------ Edit Variables Below This Line ------------------ #

# Display time in 24-hour format (true/false)
twenty_four_hour_format="false"

# Extension ID
extension_id="last_check_in"

# Enable status indicators (true/false)
color_indicators="true"

# ------------------ Do Not Edit Below This Line ------------------ #

# Support App preference plist
preference_file_location="/Library/Preferences/nl.root3.support.plist"

# Log file
jamf_log="/private/var/log/jamf.log"

# Time thresholds
readonly FOUR_HOURS=$((4 * 3600))
readonly EIGHT_HOURS=$((8 * 3600))

# Status indicators
[[ "$colorIndicator" == "true" ]] && greenCircle="🟢 " || greenCircle=""
[[ "$colorIndicator" == "true" ]] && yellowCircle="🟡 " || yellowCircle=""
[[ "$colorIndicator" == "true" ]] && redCircle="🔴 " || redCircle=""

# Start Loading Animation

defaults write "${preference_file_location}" "${extension_id}_loading" -bool true

# Small delay so spinner is visible
sleep 0.2

# Get Last Check-In Time

if [[ ! -r "${jamf_log}" ]]; then
    defaults write "${preference_file_location}" "${extension_id}" -string "${redCircle}Jamf Log Not Found"
    defaults write "${preference_file_location}" "${extension_id}_loading" -bool false
    exit 0
fi

last_check_in_time=$(awk '/Checking for policies triggered by "recurring check-in"/ {timestamp = $2 " " $3 " " $4} END {print timestamp}' "${jamf_log}")

if [[ -z "${last_check_in_time}" ]]; then
    defaults write "${preference_file_location}" "${extension_id}" -string "${redCircle}No Check-In Found"
    defaults write "${preference_file_location}" "${extension_id}_loading" -bool false
    exit 0
fi

# Convert Timestamp

last_check_in_time_epoch=$(date -j -f "%b %d %T" "${last_check_in_time}" "+%s" 2>/dev/null)

if [[ -z "${last_check_in_time_epoch}" ]]; then
    defaults write "${preference_file_location}" "${extension_id}" -string "${redCircle}Invalid Date"
    defaults write "${preference_file_location}" "${extension_id}_loading" -bool false
    exit 0
fi

# Human Readable Time

if [[ "${twenty_four_hour_format}" == "true" ]]; then
    last_check_in_time_human_readable=$(date -r "${last_check_in_time_epoch}" "+%A %H:%M")
else
    last_check_in_time_human_readable=$(date -r "${last_check_in_time_epoch}" "+%A %I:%M %p")
fi

# Determine Status Color

now_epoch=$(date +%s)
diff_seconds=$(( now_epoch - last_check_in_time_epoch ))

if   (( diff_seconds >= EIGHT_HOURS )); then status_symbol="${redCircle}"
elif (( diff_seconds >= FOUR_HOURS ));  then status_symbol="${yellowCircle}"
else                                         status_symbol="${greenCircle}"
fi

# Write the completed extension values.

final_output="${status_symbol}${last_check_in_time_human_readable}"

defaults write "${preference_file_location}" "${extension_id}" -string "${final_output}"

defaults write "${preference_file_location}" "${extension_id}_loading" -bool false

exit 0