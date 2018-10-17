#!/bin/bash

echo -e "Downloading LogMeIn Client..."
curl -L -o "/tmp/LogMeInClientMac.dmg" https://secure.logmein.com/LogMeInClientMac.dmg

echo -e "Installing LogMeIn Client..."
hdiutil attach "/tmp/LogMeInClientMac.dmg" -nobrowse
ditto "/Volumes/LogMeInClient/LogMeIn Client.app" "/Applications/LogMeIn Client.app"

echo -e "Cleaning up..."
hdiutil detach "/Volumes/LogMeInClient"
rm -f "/tmp/LogMeInClientMac.dmg"
