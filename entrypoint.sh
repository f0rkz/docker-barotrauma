#!/bin/bash

# This path has to exist
mkdir -p /home/steam/.local/share/Daedalic\ Entertainment\ GmbH/Barotrauma/

APPID=1026340
steamcmd.sh +quit
# steamcmd.sh +login anonymous +force_install_dir /data/barotrauma/