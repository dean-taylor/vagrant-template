#!/usr/bin/env bash
#[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@" || :

tmp='/vagrant/tmp'
tmp_hosts="${tmp}/etc_hosts"	# This file can be write locked to ensure consistency
dev='eth1'

set -e

function update_tmp_hosts {
  ip=${1}; shift
  fqdn=${1}; shift

  host="${ip} ${fqdn}"
  [[ ${#} -gt 0 ]] && host="${host} $@"

  eval $(read line <"${tmp_hosts}" && echo ${line#*#})
  (( sn++ ))

  sed -i \
    -e '/^#sn=/s/^.*$/#sn='"${sn}"'/' \
    -e '/\s'"${fqdn}"'/{h;s/^.*$/'"${host}"'/};${x;/^$/{s//'"${host}"'/;H};x}' \
    "${tmp_hosts}"
}

if whereis hostname &>/dev/null; then
  if ! HOSTNAME=$(hostname --fqdn 2>/dev/null); then
    HOSTNAME=$(hostname --short 2>/dev/null)
    ALIAS=''
  else
    ALIAS=$(hostname --short 2>/dev/null)
  fi
else
  HOSTNAME=$(hostnamectl status |sed -n '/Static hostname:/ s/^\s*Static hostname:\s\+\(.*\)$/\1/p')
  ALIAS=${HOSTNAME#*.}
fi

[ -d "${tmp}" ] || mkdir -p "${tmp}"

# Create hosts reference file if it does not exist
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
    if ! grep -q '^#sn=' <(head -n1 /etc/hosts); then
      ip_addr_all=$(ip addr show dev $dev scope global up) || exit 0
      ip_addr=$(echo $ip_addr_all |sed 's;^.*\s\+inet\s\+\([0-9.]\+\).*$;\1;')

      update_tmp_hosts ${ip_addr} ${HOSTNAME} ${ALIAS}

    fi
  ;;
esac

# Update local /etc/hosts if sn do not match
eval $(read line <"${tmp_hosts}" && echo ${line#*#})
read -r line </etc/hosts
if echo "${line}" |grep -q '^#sn='; then
  sn_tmp_hosts=$sn
  eval "${line#*#}"
  [[ $sn_tmp_hosts -gt $sn ]] && cp "${tmp_hosts}" /etc/hosts
else
  cp "${tmp_hosts}" /etc/hosts
fi

exit 0
