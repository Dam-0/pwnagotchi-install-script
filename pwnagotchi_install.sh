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
apt install bettercap python3-pip libpcap0.8 libpcap0.8-dev libpcap-dev libglib2.0-dev build-essential cmake sudo zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libsqlite3-dev libreadline-dev libffi-dev curl libbz2-dev gfortran git dkms aircrack-ng hcxtools -y

## Install wifi driver for ALFA AWUS036ACH (rtl8812au)
git clone https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au
make dkms_install
cd ..
rm -rf rtl8812au

## Update bettercap
bettercap -eval "caplets.update; ui.update; quit"

## Edit pwnagotchi caplets for wifi
sed -i 's/mon0/wlan1/' /usr/local/share/bettercap/caplets/pwnagotchi-auto.cap
sed -i 's/mon0/wlan1/' /usr/local/share/bettercap/caplets/pwnagotchi-manual.cap

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
mv pwngrid /usr/bin/
pwngrid -generate -keys /etc/pwnagotchi
rm -f pwngrid_linux_aarach64*


## Make python folder (Pretty sure this is not required but oh well)
mkdir /usr/local/share/python3.7

## Downloads Python 3.7.17
wget https://www.python.org/ftp/python/3.7.17/Python-3.7.17.tar.xz
tar -xf Python-3.7.17.tar.xz
cd Python-3.7.17

## Build and Install Python 3.7.17
./configure --enable-shared --with-ensurepip=install
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


## Add permissions to files
chmod 755 /usr/bin/bettercap
chown root:root /usr/bin/bettercap
chmod 755 /usr/bin/bettercap-launcher
chmod 755 /usr/bin/pwngrid
chown root:root /usr/bin/pwngrid
chmod 755 /usr/local/bin/pwnagotchi
chown root:root /usr/local/bin/pwnagotchi
chmod 711 /usr/bin/pwnagotchi-launcher

## Overwrite config.toml file
mv config.toml /etc/pwnagotchi/config.toml

## Install plugins
wget https://github.com/evilsocket/pwnagotchi-plugins-contrib/raw/master/hashie.py
mkdir /etc/pwnagotchi/custom-plugins/
mv hashie.py /etc/pwnagotchi/custom-plugins/hashie.py

## Alias
echo """alias pwnlog='tail -f -n300 /var/log/pwn*.log | sed --unbuffered "s/,[[:digit:]]\{3\}\]//g" | cut -d " "''"''" -f 2-'""" >> /root/.bashrc
echo """alias pwnver='python3 -c "import pwnagotchi as p; print(p.version)"'""" >> /root/.bashrc

## Enable services
systemctl enable bettercap pwngrid-peer pwnagotchi
