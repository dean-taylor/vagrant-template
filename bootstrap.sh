#!/usr/bin/env bash

modules=( \
  'puppetlabs-stdlib --version 4.13.1' \
  'puppetlabs-concat --version 2.2.0' \
  'puppetlabs-ntp --version 4.2.0' \
)
d_modules='/etc/puppet/modules'

[[ $EUID -eq 0 ]] || { echo "Run as root user."; exit 1; }

yum -y install deltarpm epel-release kernel-devel
yum -y install \
  dkms \
  git \
  puppet \
  tmux

[ -d /vagrant/skel ] && rsync -ro --exclude '.gitignore' /vagrant/skel/ /home/vagrant/

# Ensure Git operations are first so that conflicts in Puppet install
# dependancy resolution are less likely to occur.
#
[[ -d "${d_modules}" ]] || mkdir -p "${d_modules}"
cd "${d_modules}"

for module in "${modules[@]}"; do
echo "  puppet module install $module"
  puppet module install $module
  d_module=${module#*-}; d_module=${d_module%% *}
  grep -q "/${d_module}/" .gitignore || echo "/${d_module}/" >>.gitignore
done

cd /etc
if [ ! -d .git ]; then
  git init
  cat >>.gitignore <<EOF
/puppet/
EOF
  git add .
  git commit -m 'initial commit'
fi
