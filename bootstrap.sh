#!/usr/bin/env bash

modules=( \
  puppetlabs-stdlib \
  puppetlabs-concat \
  puppetlabs-ntp \
)
d_modules='/etc/puppet/modules'

[[ $EUID -eq 0 ]] || { echo "Run as root user."; exit 1; }

yum -y install deltarpm epel-release kernel-devel
yum -y install \
  dkms \
  git \
  puppet \
  tmux

rsync -ro /vagrant/skel/ /home/vagrant/

# Ensure Git operations are first so that conflicts in Puppet install
# dependancy resolution are less likely to occur.
#
[[ -d "${d_modules}" ]] || mkdir -p "${d_modules}"
cd "${d_modules}"

for module in ${modules[@]}; do
  puppet module install $module
  d_module=${module##*-}
  grep -q "${d_module}/" .gitignore || echo "${d_module}/" >>.gitignore
done

cd /etc
git init
cat >>.gitignore <<EOF
/puppet/
EOF
git add .
git commit -m 'initial commit'
