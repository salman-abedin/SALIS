## SALIS: Salman's Arch Linux Installer Script

## What does it do?

This is a bash script that automates the installation of **arch linux(base packages and linux firmwares)** on a given partition.

## Usage

```bash
curl -Lo install https://is.gd/salis_install && sh install
```

## Wifi (after reboot)

```bash
curl -Lo connect https://is.gd/salis_wifi && sh connect
```

## How to change the default Bangladeshi server

-  Visit https://www.archlinux.org/mirrors
-  Click the server of your country (or of the nearest one)
-  Note down the **mirror url**
-  Enter the url when the installer asks for it
-  Change your respective **time zone** after reboot
