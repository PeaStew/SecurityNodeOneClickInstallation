#!/usr/bin/env bash

# Author: Lukas Bures
# Credits: Rolf Versluis

# -----------------------------------------------------------------------------------------------------------------
# YOU HAVE TO MANUALLY SET THESE VARIABLES:
# Fully Qualified Domain Name
FQDN="zennode.info"

# -----------------------------------------------------------------------------------------------------------------
echo $USER
date

# -----------------------------------------------------------------------------------------------------------------
# Update VPS
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get autoremove -y
sudo apt -y install pwgen

# -----------------------------------------------------------------------------------------------------------------
# If you do not have more than 4G of memory when you add your existing Mem and Swap, add some swap space to the server:
free -h
df -h
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile


# Make the swap come back on after a reboot:
sudo echo "/swapfile none swap sw 0 0" >> /etc/fstab

#Make the swap work better do this for your existing swap even if you did not add any. This setting makes the server
# wait until memory is 90% used before using the hard drive as memory:
sudo echo "vm.swappiness=10" >> /etc/sysctl.conf

free -h
df -h

# Install zen from packages
sudo apt-get install apt-transport-https lsb-release
echo 'deb https://zencashofficial.github.io/repo/ '$(lsb_release -cs)' main' | sudo tee --append /etc/apt/sources.list.d/zen.list
gpg --keyserver ha.pool.sks-keyservers.net --recv 219F55740BBF7A1CE368BA45FB7053CE4991B669
gpg --export 219F55740BBF7A1CE368BA45FB7053CE4991B669 | sudo apt-key add -

sudo apt-get update
sudo apt-get install zen
zen-fetch-params

# -----------------------------------------------------------------------------------------------------------------
# ZEND INSTALLATION:
# Run zend once and read the message. It then stops.
zend

# Create a new zen configuration file. Copy and paste this into the command line:
USERNAME=$(pwgen -s 16 1)
PASSWORD=$(pwgen -s 64 1)
sudo echo -e "rpcuser=$USERNAME\nrpcpassword=$PASSWORD\nrpcallowip=127.0.0.1\nserver=1\ndaemon=1\nlisten=1\ntxindex=1\nlogtimestamps=1\n### testnet config\n# testnet=1" >> ~/.zen/zen.conf

# Run the Zen application as a daemon:
zend

# Check status and make sure block are increasing:
zen-cli getinfo
sleep 5s
zen-cli getinfo

# -----------------------------------------------------------------------------------------------------------------
# CERTIFICATE INSTALLATION:
# Check your domain name has propagated and it matches the public IP address of your server:
if ping -q -c2 "$FQDN" &>/dev/null; then
    echo "$FQDN is Pingable"
else
    echo "$FQDN Not Pingable"
    exit
fi

# Install the acme script for creating a certificate:
sudo apt install socat
cd
git clone https://github.com/Neilpang/acme.sh.git
cd acme.sh
./acme.sh --install

# Create the certificate:
# It should tell you where your certs are. They should be in ~/.acme.sh/<FQDN>
sudo ~/.acme.sh/acme.sh --issue --standalone -d $FQDN

# Install the crontab that will check the script expiration date and renew it if necessary:
cd
touch ".selected_editor"
sudo echo "SELECTED_EDITOR=\"/bin/nano\"" >> /$USER/.selected_editor
(crontab -l -u $USER 2>/dev/null; echo "6 0 * * * \"/$USER/.acme.sh\"/acme.sh --cron --home \"/$USER/.acme.sh\" > /dev/null") | crontab -

# Copy the intermediate authority certificate to the Ubuntu certificate store and install it. Best way to do this is copy
# the next section into a text file, like Notepad, substituting your actual username and FQDN for the <USER> and <FQDN>
# fields, then copying and pasting the updated text into the linux command line.  As long as you stay logged in for the
# rest of the guide, you should not have to copy and paste the FQDN line at the top more than once. Use tab, space,
# enter to navigate the CA Certificates menu:
echo "<USER> is $USER"
echo "<FQDN> is $FQDN"
sudo cp /$USER/.acme.sh/$FQDN/ca.cer /usr/share/ca-certificates/ca.crt
sudo dpkg-reconfigure ca-certificates

# Stop the zen application and configure the certificate location, then start zend again:
pkill -f zend
zen-cli stop

# Update zend.conf file
sudo echo "tlscertpath=/home/$USER/.acme.sh/$FQDN/$FQDN.cer\ntlskeypath=/home/$USER/.acme.sh/$FQDN/$FQDN.key" >> ~/.zen/zen.conf

# Run ZEND again
zend

# Look for TLS cert status true – a line should say “tls_cert_verified”: true
zen-cli getnetworkinfo

# -----------------------------------------------------------------------------------------------------------------
# Configure Secure Node Requirements

# Create a new transparent address on your swing wallet – send it 42 zen. This is the collateral address <T_ADDR>.
# Do not send real ZEN to the node! Make sure the ZEN stays in that address, else your Secure Node will fail its checks.

# See if the node already has a shielded address:
zen-cli z_listaddresses

# If not, create a shielded address on the zen node:
zen-cli z_getnewaddress

# This address will be referred to as  <Z_ADDR>. Send 5 transactions of 0.25 zen to <Z_ADDR> from the ZenCash wallet
# you have running on your PC or Mac. Check to make sure the node knows it has funds. You are ready when it has more
# than 1 ZEN:

echo "Send me more than 1 ZEN to <Z_ADDR>"
read -p "Press enter to continue"

zen-cli z_gettotalbalance

# -----------------------------------------------------------------------------------------------------------------
# Install the tracker application. If you are upgrading your tracker application, read the upgrade instructions here:
# https://github.com/ZencashOfficial/secnodetracker

curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt-get install -y nodejs

# sudo apt -y install npm
# sudo npm install -g n
# sudo n latest

# Clone this repository then install node modules:
mkdir ~/zencash
cd ~/zencash
git clone https://github.com/ZencashOfficial/secnodetracker.git
cd secnodetracker
npm install

# Run the node setup application. You will need <T_ADDR> and an email address to receive alerts.
# TODO: automatically add all informations!
node setup.js

# Start the tracking app and make sure it is working:
node app.js