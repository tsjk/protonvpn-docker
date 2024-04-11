#!/bin/bash
declare -g F='/log/protonwire-natpmpc.log' f
declare -g I='/tmp/protonwire-natpmp.ok'
declare -g ip tcp_port udp_port l t d

__exit() {
  [[ -z "${f}" ]] || rm "${f}"
  if [[ ${1} -ne 0 ]]; then
    [[ ! -e "${I}" ]] || rm "${I}"
  else
    touch "${I}"
  fi
  exit ${1}
}

[[ -s "${F}" ]] || __exit 1
[[ $(grep -n -E ' \| [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}(:[0-9]{2}){2}$' "${F}" | wc -l) -gt 0 ]] || __exit 1

l=$(grep -n -E ' \| [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}(:[0-9]{2}){2}$' "${F}" | tail -n 1 | awk -F ':' '{ print $1 }')
[[ -n "${l}" ]] || __exit 1
t=$(tail -n +${l} "${F}" | head -n 1 | grep -E -o '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}(:[0-9]{2}){2}$')

d=$(( $(date "+%s") - $(stat -c "%Y" "${F}") ))
[[ ${d} -lt 60 ]] || { echo "ERROR - Log file is stale" | ts 'natpmp-healthcheck.sh[%Y-%m-%d %H:%M:.%S]:' >&2; __exit 1; }

f=$(mktemp); tail -n +${l} "${F}" > "${f}"
[[ $(wc -l < "${f}") -eq 23 ]] || { echo "Possible natpmp error (or race condition)..." | ts 'natpmp-healthcheck.sh[%Y-%m-%d %H:%M:.%S]:' >&2; __exit 1; }

ip=$(grep -P -o "(?<=Public IP address : )[0-9]{1,3}(\.[0-9]{1,3}){3}(?=(\s|$))" "${f}" | tail -n 1)
[[ -n "${ip}" ]] || { echo "No IP address detected" | ts 'natpmp-healthcheck.sh[%Y-%m-%d %H:%M:.%S]:' >&2; __exit 1; }

udp_port=$(grep -P -o '(?<=Mapped public port )[1-9][0-9]*(?= protocol UDP to local port 0 liftime 60(\s|$))' "${f}")
tcp_port=$(grep -P -o '(?<=Mapped public port )[1-9][0-9]*(?= protocol TCP to local port 0 liftime 60(\s|$))' "${f}")
[[ -n "${udp_port}" && -n "${tcp_port}" && "${udp_port}" == "${tcp_port}" ]] || \
  { echo "No valid port mapping detected" | ts 'natpmp-healthcheck.sh[%Y-%m-%d %H:%M:%.S]:' >&2; __exit 1; }

echo "SUCCESS@(${t}) - ${ip}:${tcp_port}" | ts 'natpmp-healthcheck.sh[%Y-%m-%d %H:%M:%.S]:'
__exit 0
