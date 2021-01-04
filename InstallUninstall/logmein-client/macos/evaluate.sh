#!/bin/bash

if [ -d "/Applications/LogMeIn Client.app" ]; then
    exit 0
else
    exit 1
fi
