#!/usr/bin/env bash

modules=( \
  'puppetlabs-stdlib --version 4.13.1' \
  'puppetlabs-concat --version 2.2.0' \
  'puppetlabs-ntp --version 4.2.0' \
)
modules_d='/etc/puppet/modules'

[[ $EUID -eq 0 ]] || { echo "Run as root user."; exit 1; }

ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="7"
[ -f /etc/os-release ] && . /etc/os-release

case $ID_LIKE in
  debian)
    dpkg_release=( jessie precise squeeze trusty utopic wheezy )

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
  rhel*)
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
  *) echo "bootstrap.sh is not compatible with this OS distribution." >&2; exit 1 ;;
esac

[ -d /vagrant/skel ] && rsync -ro --exclude '.gitignore' /vagrant/skel/ /home/vagrant/

# Ensure Git operations are first so that conflicts in Puppet install
# dependancy resolution are less likely to occur.
#
[[ -d "${modules_d}" ]] || mkdir -p "${modules_d}"
cd "${modules_d}"

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

exit 0
