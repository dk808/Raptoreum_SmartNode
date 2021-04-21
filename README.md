# Raptoreum SmartNode
Script needs to be ran under a sudo user and not under root. It will install binaries, configure basic firewall settings, and create a daemon service for you. It also has a bootstrap option for quick syncing and option to create a Cron job that will check on daemon's health every hour.  

> ℹ Note: This has only been tested on a VPS using Ubuntu 18. USE AT OWN RISK.

## Installation
Create a sudo user and run this under that sudo user. Script will exit if logged in as root.  
Script will ask for BLS PrivKey(operatorSecret) that you get from the protx quick_setup/bls generate command. So have it ready. If opting to have script create Cron job you will need the protx hash you got from the protx quick_setup.
```bash
bash <(curl -s https://raw.githubusercontent.com/dk808/Raptoreum_Smartnode/main/install.sh)
```
> ℹ Info: This will also create a script to update binaries.