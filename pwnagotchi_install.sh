#!/usr/bin/env bash

## Check if running as sudo/root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

## Update DNS
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

## Install required packages and dependancies
apt update
apt upgrade -y
apt install bettercap python3-pip libpcap0.8 libpcap0.8-dev libpcap-dev libglib2.0-dev build-essential cmake sudo zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libsqlite3-dev libreadline-dev libffi-dev curl libbz2-dev gfortran git dkms -y

## Install wifi driver for ALFA AWUS036ACH (rtl8812au)
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au
sudo make dkms_install
cd ..
rm -rf rtl8812au

## Update bettercap
bettercap -eval "caplets.update; ui.update; quit"

## Edit pwnagotchi caplets for wifi
sudo sed -i 's/mon0/wlan1/' /usr/local/share/bettercap/caplets/pwnagotchi-auto.cap
sudo sed -i 's/mon0/wlan1/' /usr/local/share/bettercap/caplets/pwnagotchi-manual.cap

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
""" > /usr/bin/bettercap-launcher


echo """
#!/usr/bin/env bash
/usr/bin/monstart
if [[ $(ifconfig | grep usb0 | grep RUNNING) ]] || [[ $(cat /sys/class/net/eth0/carrier) ]]; then
  # if override file exists, go into auto mode
  if [ -f /root/.pwnagotchi-auto ]; then
    /usr/bin/bettercap -no-colors -caplet pwnagotchi-auto -iface wlan1
  else
    /usr/bin/bettercap -no-colors -caplet pwnagotchi-manual -iface wlan1
  fi
else
  /usr/bin/bettercap -no-colors -caplet pwnagotchi-auto -iface wlan1
fi
""" > /etc/systemd/system/bettercap.service

## Install and setup pwngrid
wget "https://github.com/evilsocket/pwngrid/releases/download/v1.10.3/pwngrid_linux_aarch64_v1.10.3.zip"
unzip pwngrid_linux_aarch64_v1.10.3.zip
sudo mv pwngrid /usr/bin/
sudo pwngrid -generate -keys /etc/pwnagotchi


## Make python folder (Pretty sure this is not required but oh well)
sudo mkdir /usr/local/share/python3.7

## Downloads Python 3.7.17
wget https://www.python.org/ftp/python/3.7.17/Python-3.7.17.tar.xz
tar -xf Python-3.7.17.tar.xz
cd Python-3.7.17

## Build and Install Python 3.7.17
./configure --enable-optimizations --enable-shared --with-ensurepip=install
make -j 4
sudo make altinstall
sudo ldconfig /usr/local/share/python3.7
sudo update-alternatives --install /usr/bin/python python /usr/local/bin/python3.7 1
cd ..
rm -rf Python3.7.17

## Download pwnagotchi
git clone https://github.com/Dam-0/pwnagotchi
cd pwnagotchi
sudo pip3.7 install --upgrade wheel setuptools
sudo python3.7 -m pip install tensorflow-1.15.0-cp37-cp37m-linux_aarch64.whl
sudo pip3.7 install -r requirements.txt
sudo pip3.7 install .

## Add permissions to files
sudo chmod 755 /usr/bin/bettercap
sudo chown root:root /usr/bin/bettercap
sudo chmod 755 /usr/bin/bettercap-launcher
sudo chmod 755 /usr/bin/pwngrid
sudo chown root:root /usr/bin/pwngrid
sudo chmod 755 /usr/local/bin/pwnagotchi
sudo chown root:root /usr/local/bin/pwnagotchi
sudo chmod 711 /usr/bin/pwnagotchi-launcher

##
## ADD PWNAGOTCHI CONFIG FILES


## Enable services
sudo systemctl enable bettercap pwngrid-peer pwnagotchi
