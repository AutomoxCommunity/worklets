#!/bin/bash

if [ -d "/Applications/Dashlane.app" ]; then
    exit 0
else
    exit 1
fi
