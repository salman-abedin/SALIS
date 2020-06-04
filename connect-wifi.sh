#!/usr/bin/env sh

CARD="$(ip link | grep -o 'w.*:' | tr -d ':')"

iwctl station "$CARD" get-networks

while :; do
   echo "SSID?: "
   read -r SSID
   [ "$SSID" ] && break
   echo 'This script doesnt work for retards'
done

while :; do
   echo "PASS?: "
   read -r PASS
   [ "$PASS" ] && break
   echo 'This script doesnt work for retards'
done

iwctl --passphrase "$PASS" station "$CARD" connect "$SSID"
