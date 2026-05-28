# JNUC2026

My presentation slides &amp; scripts I used at JNUC 2026 in Kansas City

I am using the excellent support.app utility [found here](https://github.com/root3nl/SupportApp) to help drive my users to a "common" point for utilities, notifications, shortcuts, etc.  

The initial setup of support.app takes some time to get it configured for your environment, but once it is setup it can become a very powerful tool.  Below are the extensions that I have developed for my users.

## Battery Health ##

[BatteryHealth.zsh](https://github.com/ScottEKendall/JNUC2026/blob/main/BatteryHealth.zsh)

This is designed to show the curent charge and maximum capacity of their laptop (running this on a desktop will show accordingly).  If the battery is "failing" (by Apple standards) it will reflect a red icon in the extension list as well as put an alert in the support app itself.

## JAMFCheckIn ##

[JAMFCheckin.zsh](https://github.com/ScottEKendall/JNUC2026/blob/main/JAMFCheckIn.zsh)

This is the same extension that the support.app website uses for their example, I just added some icons to show the status

## NetworkInfo ##

[NetworkInfo.zsh](https://github.com/ScottEKendall/JNUC2026/blob/main/NetworkInfo.zsh)

This extensions will show your connection type and an icon to reflect the connection as well.  It uses the priority of (VPN > Ethernet > Wifi).  It will also show an alert if it cannot find any active connection on your system.

## ShowPasswordAge ##

[ShowPasswordAge](https://github.com/ScottEKendall/JNUC2026/blob/main/ShowPasswordAge.zsh)

Designed to show the age of your password and when it was last change.  The status icons will changed based on the age (currently Green for over 14 days left, Yellow less then 14 days left and red if less then 14 days left)

The script is designed to work in tandem with my inTune Password script so I can retrieve the password age from our server rather then rely on the local account password age (theoritcally, they should always be the same, but I want to use the server as my "source of truth").  

The inTune password script can be found [here](https://github.com/ScottEKendall/JAMF-Pro-System-Scripts/blob/main/Maintenance%20-%20InTune%20-%20Passwords.sh)

![](./JNUCAnnouncement.jpeg)

