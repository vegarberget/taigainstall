#!/bin/bash

## Default variables to use
export INTERACTIVE=${INTERACTIVE:="true"}
export PVS=${INTERACTIVE:="true"}
export DOMAIN=${DOMAIN:="$(curl -s ipinfo.io/ip).nip.io"}
export USERNAME=${USERNAME:="taiga"}
export PASSWORD=${PASSWORD:=password}
export SCRIPT_REPO=${SCRIPT_REPO:="https://raw.githubusercontent.com/vegarberget/taigainstall/master/taigainstall.sh"}
export IP=${IP:="$(ip route get 8.8.8.8 | awk '{print $NF; exit}')"}

## Make the script interactive to set the variables
if [ "$INTERACTIVE" = "true" ]; then
	read -rp "Domain to use: ($DOMAIN): " choice;
	if [ "$choice" != "" ] ; then
		export DOMAIN="$choice";
	fi

	read -rp "Username: ($USERNAME): " choice;
	if [ "$choice" != "" ] ; then
		export USERNAME="$choice";
	fi

	read -rp "Password: ($PASSWORD): " choice;
	if [ "$choice" != "" ] ; then
		export PASSWORD="$choice";
	fi

	echo

fi

echo "******"
echo "* Your domain is $DOMAIN "
echo "* Your IP is $IP "
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "******"

## Install requirements

sudo apt-get update
sudo apt-get install -y build-essential binutils-doc autoconf flex bison libjpeg-dev libfreetype6-dev zlib1g-dev libzmq3-dev libgdbm-dev libncurses5-dev automake libtool libffi-dev curl git tmux gettext nginx rabbitmq-server redis-server postgresql-9.5 postgresql-contrib-9.5 postgresql-doc-9.5 postgresql-server-dev-9.5 python3 python3-pip python-dev python3-dev python-pip virtualenvwrapper libxml2-dev libxslt-dev libssl-dev libffi-dev

## Create a user named $USERNAME, and give it root permissions

sudo adduser $USERNAME
sudo adduser $USERNAME sudo
sudo su $USERNAME
cd ~

## Configure postgresql with the initial user and database:
sudo -u postgres createuser $USERNAME
sudo -u postgres createdb $USERNAME -O $USERNAME --encoding='utf-8' --locale=en_US.utf8 --template=template0

## Create a user named taiga, and a virtualhost for RabbitMQ (taiga-events)

sudo rabbitmqctl add_user $USERNAME PASSWORD_FOR_EVENTS
sudo rabbitmqctl add_vhost $USERNAME
sudo rabbitmqctl set_permissions -p $USERNAME $USERNAME ".*" ".*" ".*"

## BACKEND CONFIGURATION

cd ~
git clone https://github.com/taigaio/taiga-back.git taiga-back
cd taiga-back
git checkout stable

mkvirtualenv -p /usr/bin/python3 $USERNAME

pip install -r requirements.txt

python manage.py migrate --noinput
python manage.py loaddata initial_user
python manage.py loaddata initial_project_templates
python manage.py compilemessages
python manage.py collectstatic --noinput

python manage.py sample_data

## Change local.py settings according to your enviroment

cat ~taigainstall/taiga-back/settings/local.py | sed 's/example.com/$DOMAIN/' > ~/taiga-back/settings/local.py
cat ~taiga-back/settings/local.py | sed 's/theveryultratopsecretkey/$PASSWORD/' > ~/taiga-back/settings/local.py

## FRONTEND INSTALLATION

cd ~
git clone https://github.com/taigaio/taiga-front-dist.git taiga-front-dist
cd taiga-front-dist
git checkout stable

cat ~/taigainstall/taiga-front-dist/dist/conf.json | sed 's/example.com/$DOMAIN/ > ~/taiga-front-dist/dist/conf.json

## EVENTS INSTALLATION

cd ~
git clone https://github.com/taigaio/taiga-events.git taiga-events
cd taiga-events

curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt-get install -y nodejs
npm install

cat ~/taigainstall/taiga-events/config.json | sed 's/theveryultratopsecretkey/$PASSWORD/' > ~/taga-events/config.json

cat ~/taigainstall/etc/systemd/system/taiga_events.service >> /etc/systemd/system/taiga_events.service

sudo systemctl daemon-reload
sudo systemctl start taiga_events
sudo systemctl enable taiga_events

## START AND EXPOSE TAIGA

cat ~/taigainstall/etc/systemd/system/taiga.service >> /etc/systemd/system/taiga.service

sudo systemctl daemon-reload
sudo systemctl start taiga
sudo systemctl enable taiga

## NGINX

sudo rm /etc/nginx/sites-enabled/default

mkdir -p ~/logs

cat ~/taigainstall/etc/nginx/conf.d/taiga.conf > /etc/nginx/conf.d/taiga.conf

sudo systemctl restart nginx