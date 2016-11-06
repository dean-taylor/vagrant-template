#!/usr/bin/env bash
# https://www.vagrantup.com/docs/boxes/base.html

set -e

PATH="/usr/bin:/usr/sbin:/bin:/sbin"
export PATH

[ getent passwd vagrant >/dev/null ] || adduser vagrant

curl -L https://github.com/mitchellh/vagrant/raw/master/keys/vagrant.pub > /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
