#!/bin/bash
declare -g PROTONWIRE_NATPMPC_LOG='/log/protonwire-natpmpc.log' l f
declare -g I='/tmp/protonwire-natpmp.ok'
declare PROTONWIRE__IP_ADDRESS PROTONWIRE__TCP_PORT PROTONWIRE__UDP_PORT

__get-protonwire-ip() {
  local x; x=$(grep -Po '(?<=Public IP address : )[0-9]{1,3}(\.[0-9]{1,3}){3}' "${f}" | tail -n 1)
  [[ -n "${x}" ]] && { echo "${x}"; } || { echo "127.255.255.254"; return 1; }
}

__get-protonwire-udp-port() {
  local x; x=$(grep -Po '(?<=Mapped public port )[1-9][0-9]*(?= protocol UDP to local port 0 liftime 60)' "${f}" | tail -n 1)
  [[ -n "${x}" ]] && { echo "${x}"; } || { echo 0; return 1; }
}

__get-protonwire-tcp-port() {
  local x; x=$(grep -Po '(?<=Mapped public port )[1-9][0-9]*(?= protocol TCP to local port 0 liftime 60)' "${f}" | tail -n 1)
  [[ -n "${x}" ]] && { echo "${x}"; } || { echo 0; return 1; }
}

l=$(grep -n -E ' \| [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}(:[0-9]{2}){2}$' "${PROTONWIRE_NATPMPC_LOG}" | tail -n 1 | awk -F ':' '{ print $1 }')
[[ -n "${l}" ]] && { f=$(mktemp); tail -n +${l} "${PROTONWIRE_NATPMPC_LOG}" > "${f}"; }

if [[ -e "${I}" && -n "${f}" && -s "${f}" && $(wc -l < "${f}") -eq 23 ]]; then
  PROTONWIRE__IP_ADDRESS=$(__get-protonwire-ip)
  PROTONWIRE__TCP_PORT=$(__get-protonwire-tcp-port)
  PROTONWIRE__UDP_PORT=$(__get-protonwire-udp-port)
else
  PROTONWIRE__IP_ADDRESS="127.255.255.254"
  PROTONWIRE__TCP_PORT="0"
  PROTONWIRE__UDP_PORT="0"
fi

[[ -z "${f}" ]] || rm -f "${f}"

echo "HTTP/1.1 200 OK"
echo "Content-Type: text/plain"
echo
echo "TCP:${PROTONWIRE__IP_ADDRESS}:${PROTONWIRE__TCP_PORT}"
echo "UDP:${PROTONWIRE__IP_ADDRESS}:${PROTONWIRE__UDP_PORT}"
