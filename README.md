# Raptoreum SmartNode
Script needs to be ran under a sudo user and not under root. It will install binaries, configure basic firewall settings, create a daemon service, and also create a Cron job that will check on daemon's health every 15 minutes. It also has a bootstrap option for quick syncing.  

> ℹ Note: This has only been tested on a VPS using Ubuntu 20. USE AT OWN RISK.

## Installation
Create a sudo user and run this under that sudo user. Script will exit if logged in as root.  
Script will ask for BLS PrivKey(operatorSecret) that you get from the protx quick_setup/bls generate command. So have it ready.  
If opting to have script create Cron job you will need the protx hash you got from the protx quick_setup.  
Please check [Wiki](https://github.com/dk808/Raptoreum_SmartNode/wiki) for a detailed guide.
```bash
bash <(curl -s https://raw.githubusercontent.com/dk808/Raptoreum_Smartnode/main/install.sh)
```
> ℹ Info: This will also create a script to update binaries.
***
## Docker Usage
Install docker if you don't have it installed on the server. Execute everything below as one command while logged in as root.
```bash
apt-get update && apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && apt-get update && apt-get install docker-ce docker-ce-cli containerd.io -y
```
If planning to run container under user add user to docker group. Replace USER with username you will run container with.
```bash
adduser USER docker
```
Create a directory to use for volume so you have persistent data for the container to use.
```bash
mkdir smartnode
```
Run command below to use the bootstrap for quick syncing. This is optional but highly recommend to use it or it could take a while to sync.  
Example shown below is using `/root/smartnode` for binding volume. Change it to absolute path of the directory you created in previous step. So if under a user then it should be `/home/USER/smartnode`
```bash
docker run \
  -ti \
  --rm \
  -v /root/smartnode:/raptoreum \
  dk808/rtm-smartnode:latest \
  bootstrap.sh
```  
| ENV VARIABLES |                         DESCRIPTION                         |
|:-------------:|:-----------------------------------------------------------:|
|   EXTERNALIP  |                     IP Address of server                    |
|    BLS_KEY    | Operator Secret Key from ProTx or from bls generate command |
|   PROTX_HASH  |    ProTx Hash(right click on your smartnode in qt wallet)   |

The table above shows env variables you will need to use at runtime if you want to run the container as a smartnode.  
Example shown below to run the container. Please change env variables to your values.
```bash
docker run \
  -d \
  -p 10226:10226 \
  --name smartnode \
  -e EXTERNALIP=149.28.200.164 \
  -e BLS_KEY=084784f5dc8e01de1926fe7bdfd055916f22eb3823a10adb050fee9457dd483b \
  -e PROTX_HASH=d32c998e8155265900b590813e0e85ad7998e4f45b03e1ab722ec9be782b8eea \
  -v /root/smartnode:/raptoreum \
  --restart=unless-stopped \
  dk808/rtm-smartnode:latest
  ```
__Do not forget to open port 10226__  
> ℹ Info: You could ask support questions in [Raptoreum's Discord](https://discord.gg/wqgcxT3Mgh)
