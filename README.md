## SALIS: Salman's Arch Linux Installer Script

## What does it do?

This is a bash script that automates the installation of **arch linux(base packages and linux firmwares)** on a given partition.

## Usage

```sh
sh -c "$(curl -L https://is.gd/salis_install)"
```

## Wifi (after reboot)

```sh
sh -c "$(curl -L https://is.gd/salis_wifi)"
```

## How to change the default Bangladeshi server

-  Visit https://www.archlinux.org/mirrors
-  Click the server of your country (or of the nearest one)
-  Note down the **mirror url**
-  Enter the url when the installer asks for it
-  Change your respective **time zone** after reboot
