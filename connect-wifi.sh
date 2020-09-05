#!/bin/sh
#
# Connect to wifi using iwd

CARD=$(awk -F: 'END { gsub(/ /, "", $1); print $1}' /proc/net/wireless)

iwctl station "$CARD" get-networks

echo "SSID?: "
read -r SSID

echo "PASS?: "
read -r PASS

iwctl --passphrase "$PASS" station "$CARD" connect "$SSID"
