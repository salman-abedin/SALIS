#!/bin/sh

CARD="$(ip link | grep -o 'w.*:' | tr -d ':')"

iwctl station "$CARD" get-networks

while :; do
   echo "SSID?: "
   read -r SSID
   [ -n "$SSID" ] && break
   echo 'This script doesnt work for retards'
done

while :; do
   echo "PASS?: "
   read -r PASS
   [ -n "$PASS" ] && break
   echo 'This script doesnt work for retards'
done

iwctl --passphrase "$PASS" station "$CARD" connect "$SSID"
