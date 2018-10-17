#!/bin/bash

echo -e "Downloading Dashlane..."
curl -L -o "/tmp/Dashlane.dmg" https://www.dashlane.com/directdownload?platform=mac

echo -e "Installing Dashlane..."
hdiutil attach "/tmp/Dashlane.dmg" -nobrowse
ditto "/Volumes/Dashlane/Dashlane.app" "/Applications/Dashlane.app"

echo -e "Cleaning up..."
hdiutil detach "/Volumes/Dashlane"
rm -f "/tmp/Dashlane.dmg"
