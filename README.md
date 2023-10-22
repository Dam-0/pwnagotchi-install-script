# pwnagotchi-install-script
Automated pwnagotchi install for raspbery pi 4 B (Debain 12 - Bookworm)
(Might work for 5?)

I Use 64bit lite, but should work with all of them?

Headless install via SSH

This is configured for an external usb WIFI adapter so change the script as required

`config.toml` will have to be changed for bluetooth

```
sudo su
apt install git

git clone https://github.com/Dam-0/pwnagotchi-install-script
cd pwnagotchi-install-script
chmod +x pwnagotchi_install.sh
./pwnagotchi_install.sh
```
