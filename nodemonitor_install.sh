!/bin/bash
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb
dpkg -i zabbix-release_7.0-2+ubuntu24.04_all.deb
apt update
rm zabbix-release_7.0-2+ubuntu24.04_all.deb
apt install -y jq bc zabbix-agent
name=$(cat /etc/zabbix/zabbix_agentd.conf | grep ^Hostname= | sed -r 's/Hostname=(.+)/\1/g')
server=$(cat /etc/zabbix/zabbix_agentd.conf | grep ^Server= | sed -r 's/Server=(.+)/\1/g')
echo $name
echo $server

if [ "$server" != "" ] && [ "$name" != "" ]; then
    echo "Zabbix configuration contains: Server = $server and Hosname = $name. Replace this configuration? (y/n)"
    read answer
    if [[ $answer == [Yy]* ]]; then
        echo "Enter IP or hostname of Zabbix server:"
        read server1
        if [ "$server" != "" ]; then
            server=$server1
        fi
        echo "Enter name of this server:"
        read name1
        if [ "$name1" != "" ]; then
            name=$name1
        fi
        mv /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.bak
        wget https://raw.githubusercontent.com/SimyriK/zabbix_solana/master/zabbix_agentd.conf -P /etc/zabbix/
        sed -i 's/SEARCH_STRING_FOR_SERVER/'$server'/g' /etc/zabbix/zabbix_agentd.conf
        sed -i 's/SEARCH_STRIN_FOR_HOSTNAME/'$name'/g' /etc/zabbix/zabbix_agentd.conf
        echo "Config file /etc/zabbix/zabbix_agentd.conf edited"
    fi
else
    echo "Enter IP or hostname of Zabbix server:"
    read server1
    if [ "$server" != "" ]; then
        server=$server1
    fi
    echo "Enter name of this server:"
    read name1
    if [ "$name1" != "" ]; then
        name=$name1
    fi
    mv /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.bak
    wget https://raw.githubusercontent.com/SimyriK/zabbix_solana/master/zabbix_agentd.conf -P /etc/zabbix/
    sed -i 's/SEARCH_STRING_FOR_SERVER/'$server'/g' /etc/zabbix/zabbix_agentd.conf
    sed -i 's/SEARCH_STRIN_FOR_HOSTNAME/'$name'/g' /etc/zabbix/zabbix_agentd.conf
    echo "Config file /etc/zabbix/zabbix_agentd.conf edited"
fi

mkdir /etc/zabbix/scripts
systemctl stop nodemonitor.service
systemctl stop zabbix-agent
mv /etc/zabbix/scripts/nodemonitor.sh /etc/zabbix/scripts/nodemonitor.sh.bak
wget https://raw.githubusercontent.com/SimyriK/zabbix_solana/master/nodemonitor.sh -P /etc/zabbix/scripts
chmod a+x /etc/zabbix/scripts/nodemonitor.sh

CONFIGDIR='$HOME/.config/solana'
IDENTITYPUBKEY=$(solana address)
VOTEACCOUNT=$(solana validators --output json-compact | jq -r '.validators[] | select (.identityPubkey == '\"$IDENTITYPUBKEY\"') | .voteAccountPubkey')
BINDIR=$(cat ~/.config/solana/install/config.yml | grep active_release_dir | awk '{print$2}')
BINDIR+='/bin'
LOGPATH='/nodemonitor'
LOGNAME='nodemonitor.log'

echo "Check following configuration:"
echo "CONFIGDIR = $CONFIGDIR"
echo "IDENTITYPUBKEY = $IDENTITYPUBKEY"
echo "VOTEACCOUNT = $VOTEACCOUNT"
echo "BINDIR = $BINDIR"
echo "LOGPATH = $LOGPATH"
echo "LOGNAME = $LOGNAME"

echo "Do you want to customize config? (y/n):"
read answer
if [[ $answer == [Yy]* ]]; then
    
    echo "Enter directory for solana the config files (default is $CONFIGDIR). For default press Enter:"
    read dir
    if [ "$dir" != "" ]; then
        CONFIGDIR=$dir
    fi

    echo "Your identity pubkey is $IDENTITYPUBKEY? Press enter to confirm or enter the identity pubkey:"
    read validatorPubkey
    if [ "$validatorPubkey" != "" ]; then
        IDENTITYPUBKEY=$validatorPubkey
    fi

    echo "Your Vote account pubkey is $VOTEACCOUNT? Press enter to confirm or enter the vote account pubkey:"
    read VotePubkey
    if [ "$VotePubkey" != "" ]; then
        VOTEACCOUNT=$VotePubkey
    fi

    echo "Is bin folder is $BINDIR? Press enter to confirm or enter path:"
    read binpath
    if [ "$binpath" != "" ]; then
        BINDIR=$binpath
    fi

    echo "Enter folder for nodemonitor log location (default is $LOGPATH). For default press Enter:"
    read logdir
    if [ "$logdir" != "" ]; then
        LOGPATH=$logdir
    fi

    echo "Enter name of nodemonitor log file (default is $LOGNAME). For default press Enter:"
    read logfile
    if [ "$logfile" != "" ]; then
        LOGNAME=$logfile
    fi

fi

mkdir $LOGPATH
touch $LOGPATH/$LOGNAME
zabbixSericeFile=$(systemctl status zabbix-agent.service | grep Loaded | sed -r 's/.+\((\/[^; ]+); .+/\1/g')
zabbixUser=$(cat $zabbixSericeFile | grep User | sed -r 's/User=(.*)/\1/g')
zabbixUserGroup=$(cat $zabbixSericeFile | grep Group | sed -r 's/Group=(.*)/\1/g')
mkdir /etc/zabbix/zabbix_agentd.conf.d
mkdir /var/log/zabbix-agent/
chown zabbix:zabbix /etc/zabbix/zabbix_agentd.conf.d
chown zabbix:zabbix /var/log/zabbix-agent/
chown $zabbixUser:$zabbixUserGroup $LOGPATH
chown $zabbixUser:$zabbixUserGroup $LOGPATH/$LOGNAME
chmod 777 $LOGPATH
chmod 777 $LOGPATH/$LOGNAME


CONFIGDIR=$(sed 's,/,\\/,g' <<< $CONFIGDIR)
BINDIR=$(sed 's,/,\\/,g' <<< $BINDIR)
LOGPATH=$(sed 's,/,\\/,g' <<< $LOGPATH)

sed -i 's/CONFIGDIR=""/CONFIGDIR="'$CONFIGDIR'"/g' /etc/zabbix/scripts/nodemonitor.sh
sed -i 's/IDENTITYPUBKEY=""/IDENTITYPUBKEY="'$IDENTITYPUBKEY'"/g' /etc/zabbix/scripts/nodemonitor.sh
sed -i 's/VOTEACCOUNT=""/VOTEACCOUNT="'$VOTEACCOUNT'"/g' /etc/zabbix/scripts/nodemonitor.sh
sed -i 's/BINDIR=""/BINDIR="'$BINDIR'"/g' /etc/zabbix/scripts/nodemonitor.sh
sed -i 's/LOGPATH=""/LOGPATH="'$LOGPATH'"/g' /etc/zabbix/scripts/nodemonitor.sh
sed -i 's/LOGNAME=""/LOGNAME="'$LOGNAME'"/g' /etc/zabbix/scripts/nodemonitor.sh

rm /etc/systemd/system/nodemonitor.service
cat > /etc/systemd/system/nodemonitor.service <<"EOF"
[Unit]
Description=Solana Monitoring service
[Service]
ExecStart=/etc/zabbix/scripts/nodemonitor.sh
User=root
[Install]
WantedBy=multi-user.target
EOF

systemctl enable nodemonitor.service
systemctl start nodemonitor.service
systemctl enable zabbix-agent
systemctl start zabbix-agent
