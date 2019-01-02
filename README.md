# taigainstall
A script to auto install taiga for production on a single machine.

## Create a user named taiga, and give it root permissions

sudo adduser taiga
sudo adduser taiga sudo
sudo su taiga
cd ~

Then run:

git clone https://github.com/vegarberget/taigainstall.git

~/taigainstall/taigainstall.sh
