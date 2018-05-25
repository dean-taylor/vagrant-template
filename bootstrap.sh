#!/usr/bin/env bash

[[ $EUID -eq 0 ]] || { echo "Run as root user."; exit 1; }

ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="7"
[ -f /etc/os-release ] && . /etc/os-release

case $ID_LIKE in
  debian)
    packages=( \
      augeas-tools \
      dkms \
      git \
      python \
      tmux \
    )
    apt-get update && apt-get -y install ${packages[@]}
  ;;
  rhel*)
    packages=( \
      deltrpm \
      epel-release \
      kernel-devel \
      dkms \
      git \
      tmux \
    )
    yum -y install ${packages[@]}
  ;;
  *) echo "bootstrap.sh is not compatible with this OS distribution." >&2; exit 1 ;;
esac

[ -d /vagrant/skel ] && rsync -ro --exclude '.gitignore' /vagrant/skel/ /home/vagrant/

cd /etc
if [ ! -d .git ]; then
  git init
  git add .
  git commit -m 'initial commit'
fi

exit 0
