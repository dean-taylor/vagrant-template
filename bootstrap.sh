#!/usr/bin/env bash

ID=ubuntu
ID_LIKE=debian
VERSION_ID="16.04"
[ -f /etc/os-release ] && . /etc/os-release

modules=( \
  'puppetlabs-stdlib --version 4.13.1' \
  'puppetlabs-concat --version 2.2.0' \
  'puppetlabs-ntp --version 4.2.0' \
)
d_modules='/etc/puppet/modules'

dpkg_release=( jessie precise squeeze trusty utopic wheezy )

[[ $EUID -eq 0 ]] || { echo "Run as root user."; exit 1; }

case $ID_LIKE in
  "debian")
    if [[ " ${dpkg_release[@]} " =~ " ${VERSION_CODENAME} " ]]; then
      [ -f /tmp/puppetlabs-release-${VERSION_CODENAME}.deb ] || { cd /tmp; curl -L -O https://apt.puppetlabs.com/puppetlabs-release-${VERSION_CODENAME}.deb; }
      dpkg -i /tmp/puppetlabs-release-${VERSION_CODENAME}.deb
    fi

    apt-get update && apt-get -y install \
      augeas-tools \
      dkms \
      git \
      puppet \
      tmux
  ;;
  *)
    major=$(cat /etc/system-release-cpe | cut -d':' -f 5)
    rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-${major}.noarch.rpm

    yum -y install \
      deltrpm \
      epel-release \
      kernel-devel \
      dkms \
      git \
      puppet \
      tmux
  ;;
esac

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
