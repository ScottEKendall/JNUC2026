#!/bin/zsh --no-rcs

# Support App Extension - Jamf Pro Last Check-In Time
#
#
# Copyright 2025 Root3 B.V. All rights reserved.
#
# Support App Extension to get the Jamf Pro Last Check-In Time
#
# REQUIREMENTS:
# - Jamf Pro Binary
#
# THE SOFTWARE IS PROVIDED BY ROOT3 B.V. "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
# EVENT SHALL ROOT3 B.V. BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# ------------------    edit the variables below this line    ------------------

# Enable 24 hour clock format. 12 hour clock enabled by default
twenty_four_hour_format="false"

# Extension ID
extension_id="last_check_in"
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

# ---------------------    do not edit below this line    ----------------------

# Support App preference plist
preference_file_location="/Library/Preferences/nl.root3.support.plist"

# Start spinning indicator
defaults write "${preference_file_location}" "${extension_id}_loading" -bool true

# Replace value with placeholder while loading
defaults write "${preference_file_location}" "${extension_id}" -string "KeyPlaceholder"

# Keep loading effect active for 0.5 seconds
sleep 0.5

# Get last Jamf Pro check-in time from jamf.log
last_check_in_time=$(grep "Checking for policies triggered by \"recurring check-in\"" "/private/var/log/jamf.log" | tail -n 1 | awk '{ print $2,$3,$4 }')

# Convert last Jamf Pro check-in time to epoch
last_check_in_time_epoch=$(date -j -f "%b %d %T" "${last_check_in_time}" +"%s")

# Convert last Jamf Pro epoch to something easier to read
if [[ "${twenty_four_hour_format}" == "true" ]]; then
  # Outputs 24 hour clock format
  last_check_in_time_human_reable=$(date -r "${last_check_in_time_epoch}" "+%A %H:%M")
else
  # Outputs 12 hour clock format
  last_check_in_time_human_reable=$(date -r "${last_check_in_time_epoch}" "+%A %I:%M %p")
fi

# Write output to Support App preference plist
defaults write "${preference_file_location}" "${extension_id}" -string "${last_check_in_time_human_reable}"
# Calculate the difference in seconds
now_epoch=$(date +%s)
diff_seconds=$(( now_epoch - last_check_in_time_epoch ))

# Define time thresholds in seconds
four_hours=14400
eight_hours=28800

# Determine the status symbol based on age
if [[ $diff_seconds -ge $eight_hours ]]; then
  # Red circle for over 8 hours
  status_symbol=$red_circle
elif [[ $diff_seconds -ge $four_hours ]]; then
  # Yellow circle for over 4 hours
  status_symbol=$yellow_circle
else
  # Green circle for recent check-in
  status_symbol=$green_circle
fi

# Update the human readable string to include the status symbol
final_output="${status_symbol} ${last_check_in_time_human_reable}"

# Write the final output with the circle to the plist
defaults write "${preference_file_location}" "${extension_id}" -string "${final_output}"

# Stop spinning indicator
defaults write "${preference_file_location}" "${extension_id}_loading" -bool false