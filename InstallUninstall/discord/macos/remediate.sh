#!/bin/bash

echo -e "Downloading Discord..."
curl -L -o "/tmp/Discord.dmg" https://discordapp.com/api/download?platform=osx

echo -e "Installing Discord..."
hdiutil attach "/tmp/Discord.dmg" -nobrowse
ditto "/Volumes/Discord/Discord.app" "/Applications/Discord.app"

echo -e "Cleaning up..."
hdiutil detach "/Volumes/Discord"
rm -f "/tmp/Discord.dmg"
