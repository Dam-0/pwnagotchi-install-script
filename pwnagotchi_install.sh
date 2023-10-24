#!/usr/bin/env bash

## Check if running as sudo/root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

## VARS
WIFI_DEV="wlan1"

###
#config dtoverlay=dwc2,gether
#cmd    modules-load=dwc2

## Update DNS
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
chattr +i /etc/resolv.conf

## Install required packages and dependancies
apt update
apt upgrade -y
apt install libgl1-mesa-glx golang libusb-1.0-0-dev libnetfilter-queue-dev libpcap0.8-dev libpcap-dev libglib2.0-dev build-essential cmake sudo zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libsqlite3-dev libreadline-dev libffi-dev curl libbz2-dev git dkms aircrack-ng hcxtools neovim vim liblzma-dev -y


## Case install 
curl https://download.argon40.com/argon1.sh | bash

## libcap install (Have to use an older version)
dpkg -i libpcap0.8_1.9.1-4_arm64.deb

## Install wifi driver for ALFA AWUS036ACH (rtl8812au)
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au
make dkms_install
cd ..
modprobe 88XXau

## Manual install of bettercap
wget https://github.com/bettercap/bettercap/archive/refs/tags/v2.32.0.zip
unzip v2.32.0.zip
cd bettercap-2.32.0
make build -j4
mv bettercap /usr/bin/
cd ..

## Update bettercap
bettercap -eval "caplets.update; ui.update; quit"

## Create a bettercap service and launcher
echo """ 
[Unit]
Description=bettercap api.rest service.
Documentation=https://bettercap.org
Wants=network.target
After=pwngrid.service

[Service]
Type=simple
PermissionsStartOnly=true
ExecStart=/usr/bin/bettercap-launcher
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
""" > /etc/systemd/system/bettercap.service


echo """
#!/usr/bin/env bash ## FIX THIS
/usr/bin/monstart
if [[ $(ifconfig | grep usb0 | grep RUNNING) ]] || [[ $(cat /sys/class/net/eth0/carrier) ]]; then
  # if override file exists, go into auto mode
  if [ -f /root/.pwnagotchi-auto ]; then
    /usr/bin/bettercap -no-colors -caplet pwnagotchi-auto -iface $WIFI_DEV
  else
    /usr/bin/bettercap -no-colors -caplet pwnagotchi-manual -iface $WIFI_DEV
  fi
else
  /usr/bin/bettercap -no-colors -caplet pwnagotchi-auto -iface $WIFI_DEV
fi
""" > /usr/bin/bettercap-launcher


## Create pwngrid service
echo """
[Unit]
Description=pwngrid peer service.
Documentation=https://pwnagotchi.ai
Wants=network.target
[Service]
Type=simple
PermissionsStartOnly=true
ExecStart=/usr/bin/pwngrid -keys /etc/pwnagotchi -address 127.0.0.1:8666 -client-token /root/.api-enrollment.json -wait -log /var/log/pwngrid-peer.log -iface $WIFI_DEV
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
""" > /etc/systemd/system/pwngrid-peer.service

## Install and setup pwngrid
wget "https://github.com/evilsocket/pwngrid/releases/download/v1.10.3/pwngrid_linux_aarch64_v1.10.3.zip"
unzip pwngrid_linux_aarch64_v1.10.3.zip
mv pwngrid /usr/bin/
pwngrid -generate -keys /etc/pwnagotchi

## Make python folder (Pretty sure this is not required but oh well)
mkdir /usr/local/share/python3.7

## Downloads Python 3.7.17
wget https://www.python.org/ftp/python/3.7.17/Python-3.7.17.tar.xz
tar -xf Python-3.7.17.tar.xz
cd Python-3.7.17

## Build and Install Python 3.7.17
./configure --enable-shared --with-ensurepip=install -enable-optimizations
make -j 4
make altinstall
ldconfig /usr/local/share/python3.7
update-alternatives --install /usr/bin/python python /usr/local/bin/python3.7 1
cd ..
rm -rf Python-3.7.1*

## Download pwnagotchi
git clone https://github.com/Dam-0/pwnagotchi
cd pwnagotchi
pip3.7 install --upgrade wheel setuptools
python3.7 -m pip install ../tensorflow-1.15.0-cp37-cp37m-linux_aarch64.whl
pip3.7 install -r requirements.txt
pip3.7 install .
cd ..


###############
mkdir -p /etc/pwnagotchi/
cp config.toml /etc/pwnagotchi/config.toml


chmod u+x /usr/bin/monstart
chmod u+x /usr/bin/pwnagotchi-launcher

sed -i "s/mon0/$WIFI_DEV/g" /usr/local/share/bettercap/caplets/pwnagotchi-auto.cap
sed -i "s/mon0/$WIFI_DEV/g" /usr/local/share/bettercap/caplets/pwnagotchi-manual.cap
sed -i "s/mon0/$WIFI_DEV/g" /etc/systemd/system/pwngrid-peer.service
## Sets place modifed pwnlib
mv pwnlib /usr/bin/pwnlib


## Add permissions to files
chmod 755 /usr/bin/bettercap
chown root:root /usr/bin/bettercap
chmod 755 /usr/bin/bettercap-launcher
chmod 755 /usr/bin/pwngrid
chown root:root /usr/bin/pwngrid
chmod 755 /usr/local/bin/pwnagotchi
chown root:root /usr/local/bin/pwnagotchi
chmod 711 /usr/bin/pwnagotchi-launcher

## Install plugins
pwnagotchi plugins update
pwnagotchi plugins upgrade
pwnagotchi plugins install hashie

## Alias
echo "alias pwnlog=""'""tail -f -n300 /var/log/pwn*.log | sed --unbuffered "'"'"s/,[[:digit:]]\{3\}\]//g"'"'" | cut -d "'"'" "'"'" -f 2-""'" >> /root/.bashrc
echo "alias pwnver=""'""python3 -c "'"'"import pwnagotchi as p; print(p.version)""'" >> /root/.bashrc

## Enable services
systemctl enable bettercap pwngrid-peer pwnagotchi
systemctl start bettercap pwngrid-peer pwnagotchi

## Overwrite config.toml file
mv config.toml /etc/pwnagotchi/config.toml

systemctl restart bettercap pwngrid-peer pwnagotchi

cd ..
rm -rf pwnagotchi-install-script

exit 0