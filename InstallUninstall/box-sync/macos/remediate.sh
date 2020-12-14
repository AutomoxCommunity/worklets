#!/bin/bash

echo -e "Downloading Box Sync..."
curl -L -o "/tmp/Box Sync Installer.dmg" https://e3.boxcdn.net/box-installers/sync/Sync+4+External/Box%20Sync%20Installer.dmg

echo -e "Installing Box Sync..."
hdiutil attach "/tmp/Box Sync Installer.dmg" -nobrowse
ditto "/Volumes/Box Sync Installer/Box Sync.app" "/Applications/Box Sync.app"

echo -e "Cleaning up..."
hdiutil detach "/Volumes/Box Sync Installer"
rm -f "/tmp/Box Sync Installer.dmg"
