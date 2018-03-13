#!/bin/bash
# Author: Alvinho - DEPED
# Tested on Ubuntu Server 14.04 Thrusty Tahr 64 bits
# Alvaro Lopez Antelo
# Script to configure a monitoring station for a batman-adv mesh network
# The station has a wired interface for remote http access via Observium NMS
# and another vlan sub-interface to speak mesh protocol and reach mesh nodes
# We monitor mesh nodes via SNMP and the station also use ALFRED to receive topology info
# from the mesh network

# Update Ubuntu
sudo apt -y update
sudo apt -y upgrade
sudo apt-get autoremove

# Global config

# Define version of batman-adv protocol
# To use Experimental version 5 set batman_version=5
# To use Stable version 4 set batman_version=4
export batman_version='5'

# Batman-adv mesh ethenet cable interface, IPv4 address and gateway address
echo "Selecione qual interface de rede será conectada na porta LAN mesh do gateway?"
echo "Essa interface é dedicada para comunicação via protocolo batman-adv para monitoração"
echo "Não deve ser a mesma utilizada para acessar a internet"
cd /sys/class/net && select batman_iface in *
	do echo $batman_iface selected; break
done
# Batman-adv mesh ethenet cable interface, IPv4 address and gateway address
export batman_iface_ip='10.61.34.1'
export batman_iface_mask='255.255.255.0'
export gateway_ip='10.61.34.254'

# Observium database credentials
export mysql_root_user='observium'
export observium_db_user='observium'
export observium_db_pwd='observium'

# Node base geolocation
export gps_longitude='-46.6573279'
export gps_latitude='-23.5632479'

# Install all dependencies
sudo apt install -y apache2 binutils bridge-utils build-essential \
byacc ethtool expect fping g++ gcc git graphviz htop imagemagick \
ipmitool iw libapache2-mod-php7.0 libcap-dev libgps-dev libncurses5-dev \
libnl-3-dev libnl-genl-3-dev libpcap-dev libreadline-dev make mtr-tiny \
mysql-client openjdk-8-jre openssh-server php7.0-cli php7.0-gd php7.0-json \
php7.0-mcrypt php7.0-mysql php-pear python-dev python-mysqldb python-paste \
python-pastedeploy python-pip python-setuptools python-twisted rrdtool \
snmp subversion unzip vim wget whois wireless-tools

cd /home/$USER

# Download latest stable version of BATMAN-ADV
git clone https://git.open-mesh.org/batman-adv.git batman-adv
# Enable BATMAN-ADV V
if [ $batman_version -eq "5" ]; then
    cd batman-adv
    sed -i "s/export CONFIG_BATMAN_ADV_BATMAN_V=n/export CONFIG_BATMAN_ADV_BATMAN_V=y/" Makefile
    cd ..
fi

# Download latest stable version of ALFRED
git clone https://git.open-mesh.org/alfred.git alfred

# Download latest stable version of BATCTL
git clone https://git.open-mesh.org/batctl.git batctl

# Compile BATMAN, BATCTL and ALFRED, make use of multicore SMP
cd batman-adv && make -j${nproc} && sudo make install
cd ../batctl && make -j${nproc} && sudo make install
cd ../alfred && make LIBCAP_CFLAGS='' LIBCAP_LDLIBS='-lcap' && sudo make LIBCAP_CFLAGS='' LIBCAP_LDLIBS='-lcap' install
# Load batman-adv kernel module at startup
echo 'batman-adv' | sudo tee --append /etc/modules

# Install Java Graphviz Renderer Engine
cd /opt
sudo git clone https://github.com/omerio/graphviz-server

# Prepare for unatended MySQL Server installation - preassign root password to database server
echo "mysql-server-5.7 mysql-server/root_password password $mysql_root_user" | sudo debconf-set-selections
echo "mysql-server-5.7 mysql-server/root_password_again password $mysql_root_user" | sudo debconf-set-selections
sudo apt-get -y install mysql-server-5.7

# Install Observium monitoring tool (latest community edition)
sudo mkdir -p /opt/observium; cd /opt
sudo wget -c --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 http://www.observium.org/observium-community-latest.tar.gz
sudo tar zxvf observium-community-latest.tar.gz
sudo rm -f observium-community-latest.tar.gz

# Create Observium default config
cd /opt/observium && sudo cp config.php.default config.php

# Configure config.php to correct database credentials and table
sudo sed -i "s/\$config\['db_host'\].*/\$config\['db_host'\] = 'localhost';/" /opt/observium/config.php
sudo sed -i "s/\$config\['db_user'\].*/\$config\['db_user'\] = '$observium_db_user';/" /opt/observium/config.php
sudo sed -i "s/\$config\['db_pass'\].*/\$config\['db_pass'\] = '$observium_db_pwd';/" /opt/observium/config.php
sudo sed -i "s/\$config\['db_name'\].*/\$config\['db_name'\] = 'observium';/" /opt/observium/config.php

# Enter default node GPS coordinates and geocoding engine
sudo bash -c 'cat >> /opt/observium/config.php << "END"
$config["geocoding"]["api"] = "google";
$config["geocoding"]["default"]["lat"] =  gps_latitude;  // Default latitude
$config["geocoding"]["default"]["lon"] =  gps_longitude;  // Default longitude
END'

# Substitute for actual variables
sudo sed -i "s/gps_latitude/$gps_latitude/" /opt/observium/config.php
sudo sed -i "s/gps_longitude/$gps_longitude/" /opt/observium/config.php

# Enable Syslog integration with Observium
# Enable syslog globally
sudo bash -c 'cat >> /opt/observium/config.php << "END"
$config["enable_syslog"]   = 1;
END'

# Activate UDP port 514 on rsyslog
sudo sed -i "s/#\$ModLoad imudp/\$ModLoad imudp/" /etc/rsyslog.conf
sudo sed -i "s/#\$UDPServerRun 514/\$UDPServerRun 514/" /etc/rsyslog.conf

# Rsyslog redirection to observium
sudo wget -c https://www.dropbox.com/s/z4840d23k7mkv9f/30-observium.conf -O /etc/rsyslog.d/30-observium.conf
sudo service rsyslog restart

# Create Observium directories and permissions
cd /opt/observium && sudo mkdir logs && sudo mkdir rrd
sudo chown www-data:www-data rrd && sudo chown www-data:www-data logs

# Use expect to non-interactively create observium database and grant permissions to it's user
CONFIGURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql -u root -p
expect \"Enter password:\"
send \"$mysql_root_user\r\"
expect \"mysql>\"
send \"CREATE DATABASE observium DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;\r\"
expect \"mysql>\"
send \"GRANT ALL PRIVILEGES ON observium.* TO 'observium'@'localhost' IDENTIFIED BY 'observium';\r\"
expect \"mysql>\"
send \"flush privileges;\r\"
expect \"mysql>\"
send \"exit\r\"
expect eof
")
echo "$CONFIGURE_MYSQL"

# Remove now unnecessary package
sudo apt-get purge -y expect
sudo apt-get autoremove -y

# Create Observium database schema
cd /opt/observium && ./discovery.php -u

# Configure default Apache 2.4+ virtualhost
sudo bash -c 'cat > /etc/apache2/sites-available/000-default.conf << "END_APACHE"
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /opt/observium/html
    <Directory />
            Options FollowSymLinks
            AllowOverride None
    </Directory>
    <Directory /opt/observium/html/>
           Options Indexes FollowSymLinks MultiViews
           AllowOverride All
           Require all granted
    </Directory>
    ErrorLog  ${APACHE_LOG_DIR}/error.log
    LogLevel warn
    CustomLog  ${APACHE_LOG_DIR}/access.log combined
    ServerSignature On
</VirtualHost>
END_APACHE'

# Create logs directory, adjust permissions
sudo mkdir -p /opt/observium/logs; sudo chown www-data:www-data /opt/observium/logs

# Enable PHP mcrypt module
sudo phpenmod mcrypt

# Give apache host a name
sudo bash -c 'cat >> /etc/apache2/apache2.conf << "END"
ServerName localhost
END'

# Edit PHP default timezone and GPS coordinates
#sudo sed -i 's/;date.timezone =.*/date.timezone = America\/Sao_Paulo/' /etc/php5/apache2/php.ini
#sudo sed -i 's/;date.default_latitude =.*/date.default_latitude = $gps_latitude/' /etc/php5/apache2/php.ini
#sudo sed -i 's/;date.default_longitude =.*/date.default_longitude = $gps_longitude/' /etc/php5/apache2/php.ini

# Enable mod_rewrite Apache module and restart Apache
sudo a2dismod mpm_event && sudo a2enmod mpm_prefork && sudo a2enmod php7.0

# Enable mod_rewrite Apache module and restart Apache
sudo a2enmod rewrite && sudo apache2ctl restart
sudo service apache2 restart

# Add observium admin user
cd /opt/observium && ./adduser.php $observium_db_user $observium_db_pwd 10

# Startup script for ALFRED
sudo wget -c https://www.dropbox.com/s/vii9g1x6v5sce75/alfred.sh -O /opt/alfred.sh
sudo chmod +x /opt/alfred.sh

# System V service for ALFRED services
sudo wget -c https://www.dropbox.com/s/lfn73dppk5u7gfa/alfred.service -O /lib/systemd/system/alfred.service
sudo chmod 644 /lib/systemd/system/alfred.service
sudo systemctl daemon-reload
sudo systemctl enable alfred.service

# System V service for Graphviz server
sudo wget -c https://www.dropbox.com/s/hhs4rnhv99tosil/render_graphvis_dot_file.py -O /opt/render_graphvis_dot_file.py
sudo chmod 755 /opt/render_graphvis_dot_file.py
sudo wget -c https://www.dropbox.com/s/eygodhdbm2ajrxc/graphvis.service -O /lib/systemd/system/graphvis.service
sudo chmod 644 /lib/systemd/system/graphvis.service
sudo systemctl daemon-reload
sudo systemctl enable graphvis.service

# Startup configuration for batman-adv interfaces
sudo bash -c 'cat > /etc/rc.local << "END_RCLOCAL"
echo "Starting batman-adv mesh"
# Configure batman_iface batman interface as ADHOC, MTU to support batman and promiscuous mode
/sbin/ifconfig batman_iface down
echo BATMAN_PROTOCOL > /sys/module/batman_adv/parameters/routing_algo
/sbin/ifconfig batman_iface mtu 1560
/bin/sleep 10
/usr/local/sbin/batctl if add batman_iface
echo "Activating batman_iface batman interface"
/sbin/ifconfig batman_iface up promisc
/sbin/ifconfig bat0 up
echo "bat0 interface activated"
/sbin/ip addr add batman_iface_ip/batman_iface_mask dev bat0
exit 0
END_RCLOCAL'
# Substitute afterwards for real variables
sudo sed -i "s/batman_iface_ip/$batman_iface_ip/" /etc/rc.local
sudo sed -i "s/batman_iface_mask/$batman_iface_mask/" /etc/rc.local
sudo sed -i "s/batman_iface/$batman_iface/" /etc/rc.local
if [ $batman_version -eq 5 ]; then  
	sudo sed -i "s/BATMAN_PROTOCOL/BATMAN_V/" /etc/rc.local
else  
	sudo sed -i "s/BATMAN_PROTOCOL/BATMAN_IV/" /etc/rc.local
fi

# Add a cron.d job to run topology renderer at a 1 minute interval
# add Observium SNMP and housekeeping services at recommended intervals
sudo bash -c 'cat >> /etc/cron.d/batman-monitor << "END"
*/1 * * * * root /usr/bin/python /opt/render_graphvis_dot_file.py
# Run automated discovery of newly added devices every 5 minutes
*/5 *     * * *   root    /opt/observium/discovery.php -h new >> /dev/null 2>&1
# Run a complete discovery of all devices once every 6 hours
33  */6   * * *   root    /opt/observium/discovery.php -h all >> /dev/null 2>&1
# Run multithreaded poller wrapper every 5 minutes
*/5 *     * * *   root    /opt/observium/poller-wrapper.py 4 >> /dev/null 2>&1
# Run housekeeping script daily for syslog, eventlog and alert log
13 5 * * * root /opt/observium/housekeeping.php -ysel >> /dev/null 2>&1
# Run housekeeping script daily for rrds, ports, orphaned entries in the database and performance data
47 4 * * * root /opt/observium/housekeeping.php -yrptb >> /dev/null 2>&1
END'
