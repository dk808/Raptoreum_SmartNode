# Raptoreum SmartNode
Script needs to be ran under a sudo user and not under root. It will install binaries, configure basic firewall settings, and create a daemon service for you. It also has a bootstrap option for quick syncing.

> ℹ Note: This has only been tested on Ubuntu 18 but should work on 16. USE AT OWN RISK.

## Installation
Create a sudo user and run this under that sudo user. Script will exit if ran under root.  
Script will ask for BLS PrivKey(operatorSecret) that you get from the protx quick_setup command. So have it ready.
```
bash <(curl -s https://raw.githubusercontent.com/dk808/Raptoreum_Smartnode/main/install.sh)
```
