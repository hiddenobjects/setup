#!/bin/bash

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)

   KEY_LENGTH=${#KEY}
   VALUE="${ARGUMENT:$KEY_LENGTH+1}"

   export "$KEY"="$VALUE"
done

declare -A setup_args

setup_args[ip]=$ip
setup_args[uid]=$uid
setup_args[gid]=$gid
setup_args[pw_grafana]=$pw_grafana
setup_args[pw_worker]=$pw_worker
setup_args[pw_dbroot]=$pw_dbroot
setup_args[forwarder]=$forwarder
setup_args[forwarder_ip]=$forwarder_ip
setup_args[forwarder_port]=$forwarder_port
setup_args[dns_real]=$dns_real
setup_args[git_link]=$git_link
setup_args[path]=$path

echo ""
cat << 'EOF'
█ █ ██ █  ████  █  ██ ████  █  ██ █   ██ ██ ████ ██  ████ █ ██ █ █
█ █ ██ █  ████  █  ██ ████  █  ██ █   ██ ██ ████ ██  ████ █ ██ █ █
█ █ ██ █  ████  █  ██ ████  █  ██ █   ██ ██ ████ ██  ████ █ ██ █ █
█ █ ██ █  ████  █  ██ ████  █  ██ █   ██ ██ ████ ██  ████ █ ██ █ █
█ █ ██ █  ████  █  ██ ████  █  ██ █   ██ ██ ████ ██  ████ █ ██ █ █
█ █ ██ █  ████  █  ██ ████  █  ██ █   ██ ██ ████ ██  ████ █ ██ █ █
█ █ ██ █  ████  █  ██ ████  █  ██ █   ██ ██ ████ ██  ████ █ ██ █ █
█ █ ██ █  ████  █  ██ ████  █  ██ █   ██ ██ ████ ██  ████ █ ██ █ █
█    _  _ ___ ___  ___  ___ _  _    ___  ___    _ ___ ___ _____  █
█| || |_ _|   \|   \| __| \| |  / _ \| _ )_ | | __/ __|_   _/ __|█
█| __ || || |) | |) | _|| .` | | (_) | _ \ || | _| (__  | | \__ \█
█|_||_|___|___/|___/|___|_|\_|  \___/|___/\__/|___\___| |_| |___/█
█ SpyDR                                                          █
EOF

echo ""
echo ""


help_msg=$(cat << EOF
Use ./setup.sh OPTIONS

Options:

./setup.sh 

MANDATORY
ip=10.111.0.1 -> IP Address of appliance

OPTIONAL
path=/home/spydr/ -> Install path, Default: Current path
forwarder=true -> Activate forwarding to SIEM?, Default: false
forwarder_ip=10.111.20.123 -> SIEM IP address
forwarder_port=4432 -> SIEM Port (tcp)
dns_real=1.1.1.1 -> Real DNS requests will be forwarded to this DNS Server, Default: 1.1.1.1 (cloudflare)
git_link=git@github.com:hiddenobjects/spydrweb.git -> Provide GIT Link to automatically download the repository
uid=1000 -> User ID of SpyDR User, Default: Current User
gid=1000 -> Group ID of SpyDR User, Default: Current User

Set own passwords:
pw_worker=<PASSWORD> -> Internal DB User password, Default: random
pw_grafana=<PASSWORD> -> Grafana DB User password, Default: random
pw_dbroot=<PASSWORD>  -> MySQL DB ROOT User password, Default: random
EOF
)


#  needed
if [[ -z $ip ]]; then 
   echo "HELP"
   echo "***********************************************************"
   echo ""
   echo "$help_msg"
   echo ""
   echo "***********************************************************"
   exit 0
fi

echo "SETUP CONFIG"
echo "***********************************************************"
# optional
if [[ -z $uid ]]; then 
   setup_args[uid]=$(cat /etc/passwd | grep `whoami`: | cut -d: -f3)
   echo "No UID provided. Using current user."
fi
if [[ -z $gid ]]; then 
   setup_args[gid]=$(cat /etc/passwd | grep `whoami`: | cut -d: -f4)
   echo "No GID provided. Using current user."
fi
if [[ -z $pw_grafana ]]; then 
   echo "No Grafana DB User Password provided. Random password generated."
   setup_args[pw_grafana]=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 18 ; echo '')
fi
if [[ -z $pw_worker ]]; then 
   echo "No Worker DB User Password provided. Random password generated."
   setup_args[pw_worker]=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 18 ; echo '')
fi
if [[ -z $pw_dbroot ]]; then 
   echo "No Root DB User Password provided. Random password generated."
   setup_args[pw_dbroot]=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 18 ; echo '')
fi
if [[ $forwarder != "true" ]]; then 
   echo "No Forwarder Settings enabled. Disabling it."
   setup_args[forwarder]="false"
   setup_args[forwarder_ip]="10.111.0.128"
   setup_args[forwarder_port]="16002"
fi
if [[ $forwarder == "true" ]] && ([[ $forwarder_ip -eq "" ]] || [[ $forwarder_port -eq "" ]])
then
   echo "Warning: Forwarder is enabled, but no Forwarder IP or Port is set."
   echo ""
   echo "$help_msg"
   exit 0
fi
if [[ -z $dns_real ]]; then 
   echo "No DNS Server is provided. Using 1.1.1.1."
   setup_args[dns_real]="1.1.1.1"
fi
if [[ -z $git_link ]]; then 
   echo "No GIT URL is provided. No GIT Download will be executed."
fi
if [[ -z $path ]]; then
   echo "No install path provided. Using current directory."
   setup_args[path]=$(pwd)
fi


echo "***********************************************************"
echo "OVERVIEW"
echo "***********************************************************"
echo "Installation path: ${setup_args[path]}"
echo "UID/GID: ${setup_args[uid]}:${setup_args[gid]}"
echo "IP Address: ${setup_args[ip]}"
# echo "GRAFANA DB PW: ${setup_args[pw_grafana]}"
echo "FORWARDER: ${setup_args[forwarder]} ${setup_args[forwarder_ip]} ${setup_args[forwarder_port]}"
echo "Real DNS Server: ${setup_args[dns_real]}"
if [[ -n $git_link ]]; then 
   echo "GIT Download from: ${setup_args[git_link]}"
fi
echo "***********************************************************"

data_ok=true
while $data_ok; do
   echo "Please take a look over the details? Provided information ok? y/n"
   read ok
   if [[ $ok == "n" ]]; then
      data_ok=false
      echo "Ok, please start again."
      echo "**************************END******************************"
      exit 0
   elif [[ $ok == "y" ]]; then
      data_ok=false
   fi
done

echo "***************************START****************************"

cd ${setup_args[path]}

if [[ -n $git_link ]]; then 
   git clone ${setup_args[git_link]}
   slashes=$(echo ${setup_args[git_link]} | grep -o / | wc -l)
   pos=$(($slashes+1))
   git_folder=$(echo ${setup_args[git_link]} | cut -d / -f $pos | cut -d . -f1)

   cd $git_folder
fi


echo "Configuring IP Address..."
sed -i "s/SPYDR_IP/${setup_args[ip]}/g" docker-compose.yml
echo "Configuring UID..."
sed -i "s/UID/${setup_args[uid]}/g" docker-compose.yml
echo "Configuring GID..."
sed -i "s/GID/${setup_args[gid]}/g" docker-compose.yml
echo "Configuring Grafana PW..."
sed -i "s/PW_GRAFANA/${setup_args[pw_grafana]}/g" docker-compose.yml
echo "Configuring Worker PW..."
sed -i "s/PW_WORKER/${setup_args[pw_worker]}/g" docker-compose.yml
echo "Configuring DB Root PW..."
sed -i "s/PW_DBROOT/${setup_args[pw_dbroot]}/g" docker-compose.yml
echo "Configuring Forwarder..."
sed -i "s/FORWARDER_ACTIVE/${setup_args[forwarder]}/g" docker-compose.yml
echo "Configuring Forwarder Port..."
sed -i "s/FORWARDER_X_PORT/${setup_args[forwarder_port]}/g" docker-compose.yml
echo "Configuring Forwarder IP..."
sed -i "s/FORWARDER_X_IP/${setup_args[forwarder_ip]}/g" docker-compose.yml
echo "Configuring DNS Server..."
sed -i "s/ALTERNATE_DNS/${setup_args[dns_real]}/g" docker-compose.yml
echo "Configuration done."

echo "***************************DONE****************************"




