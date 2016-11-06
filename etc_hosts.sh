#!/usr/bin/env bash
#[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@" || :

tmp='/vagrant/tmp'
tmp_hosts="${tmp}/etc_hosts"	# This file can be write locked to ensure consistency
dev='eth1'

HOSTNAME=$(hostnamectl status |sed -n '/Static hostname:/ s/^\s*Static hostname:\s\+\(.*\)$/\1/p')
ALIAS=${HOSTNAME#*.}

if [[ ! -f "${tmp_hosts}" ]]; then
  cat >"${tmp_hosts}" <<EOF
#sn=0
# Do not edit sn value. Required by Vagrant /etc/hosts scripts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF
fi

BASENAME=$(basename "${0}")
case "${BASENAME}" in
  dhclient-*-up-hooks)
    case $reason in
      BOUND|RENEW|REBIND)   # $new_ip_address $old_ip_address $interface
        if [[ ! -z $old_ip_address ]]; then
          eval $(sed -n '/^#sn=/ s/^#.*\(sn=[0-9]\)/\1/p' "${tmp_hosts}")
          sed -i \
            -e "s/${old_ip_address}/${new_ip_address}/" \
            -e "s/^#sn=.*$/#sn=$((sn+1))/" \
            "${tmp_hosts}" 
          cp "${tmp_hosts}" /etc/hosts
        else
          eval $(sed -n '/^#sn=/ s/^#.*\(sn=[0-9]\)/\1/p' "${tmp_hosts}")
          if grep -q "${HOSTNAME} ${ALIAS}" "${tmp_hosts}"; then
            sed -i \
              -e "/${HOSTNAME} ${ALIAS}/ s/^[0-9.]/${new_ip_address}/" \
              -e "s/^#sn=.*$/#sn=$((sn+1))/" \
              "${tmp_hosts}"
          else
            echo "$new_ip_address $HOSTNAME $ALIAS" >>"${tmp_hosts}"
            sed -i -e "s/^#sn=.*$/#sn=$((sn+1))/" "${tmp_hosts}"
          fi
        fi
      ;;
      *) echo "reason='${reason}'" ;;
    esac
  ;;
  etc_hosts-systemd)
    while : ; do
      eval $(sed -n '/^#sn=/ s/^#.*\(sn=[0-9]\)/\1/p' "${tmp_hosts}")
      if [[ $sn -ne 0 ]]; then
        sn_vagrant=$sn
        if grep -q '^#.*sn=' /etc/hosts; then
          sn=0
        else
          eval $(sed -n '/^#sn=/ s/^.*\(sn=[0-9]\)/\1/p' /etc/hosts)
        fi
        if [[ $sn -ne $sn_vagrant ]]; then
          # Update /etc/hosts
          # ToDo flock
          cp "${tmp_hosts}" /etc/hosts
        fi
      fi
      
      sleep 15
    done
  ;;
  *)
    ip_addr_all=$(ip addr show dev $dev scope global up) || exit 0
    ip_addr=$(echo $ip_addr_all |sed 's;^.*\s\+inet\s\+\([0-9.]\+\).*$;\1;')

    host="${ip_addr} ${HOSTNAME} ${ALIAS}"
    grep -q "${host}" "${tmp_hosts}" || echo "${host}" >>"${tmp_hosts}"

    IFS=$'\r\n' GLOBIGNORE='*' command eval 'hosts=($(</vagrant/tmp/etc_hosts))'
    for host in "${hosts[@]}"; do
      grep -q "${host}" /etc/hosts || echo "${host}" >>/etc/hosts
    done
  ;;
esac

exit 0

[[ $EUID == 0 ]] || { echo 'Run as root'; exit 1; }

if [[ -z $ip_addr ]]; then
  ip_addr_all=$(ip addr show dev $dev scope global up) || exit 0
  ip_addr=$(echo $ip_addr_all |sed 's;^.*\s\+inet\s\+\([0-9.]\+\).*$;\1;')
fi
[[ -z $name ]]    && name=$(hostname --fqdn 2>/dev/null)
[[ -z $alias ]]   && alias=$(hostname --short 2>/dev/null)

host="${ip_addr} ${name} ${alias}"

# Check host entries with Vagrant records

while read host; do
  grep -q "${host}" /etc/hosts || echo "${host}" >>/etc/hosts
done <"${tmp_hosts}"

exit 0
