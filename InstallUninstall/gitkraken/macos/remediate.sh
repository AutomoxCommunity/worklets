#!/bin/bash

echo -e "Downloading GitKraken..."
curl -L -o "/tmp/InstallGitKraken.dmg" https://release.gitkraken.com/darwin/installGitKraken.dmg

echo -e "Installing GitKraken..."
hdiutil attach "/tmp/InstallGitKraken.dmg" -nobrowse
ditto "/Volumes/Install GitKraken/GitKraken.app" "/Applications/GitKraken.app"

echo -e "Cleaning up..."
hdiutil detach "/Volumes/Install GitKraken"
rm -f "/tmp/InstallGitKraken.dmg"
