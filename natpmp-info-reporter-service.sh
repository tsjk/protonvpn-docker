#!/bin/bash
declare -g PROTONWIRE_NATPMPC_LOG='/log/protonwire-natpmpc.log'
__get-protonwire-ip() {
  local x
  [[ -s "${PROTONWIRE_NATPMPC_LOG}" ]] && \
    x=$(tail -n 46 "${PROTONWIRE_NATPMPC_LOG}" | grep -Po '(?<=Public IP address : )[0-9]{1,3}(\.[0-9]{1,3}){3}' | tail -n 1)
  [[ -n "${x}" ]] && { echo "${x}"; } || { echo "127.255.255.254"; return 1; }
}

__get-protonwire-udp-port() {
  local x
  [[ -s "${PROTONWIRE_NATPMPC_LOG}" ]] && \
    x=$(tail -n 46 "${PROTONWIRE_NATPMPC_LOG}" | grep -Po '(?<=Mapped public port )[1-9][0-9]*(?= protocol UDP to local port 0 liftime 60)' | tail -n 1)
  [[ -n "${x}" ]] && { echo "${x}"; } || { echo 0; return 1; }
}

__get-protonwire-tcp-port() {
  local x
  [[ -s "${PROTONWIRE_NATPMPC_LOG}" ]] && \
    x=$(tail -n 46 "${PROTONWIRE_NATPMPC_LOG}" | grep -Po '(?<=Mapped public port )[1-9][0-9]*(?= protocol TCP to local port 0 liftime 60)' | tail -n 1)
  [[ -n "${x}" ]] && { echo "${x}"; } || { echo 0; return 1; }
}

declare PROTONWIRE_ADDRESS=$(__get-protonwire-ip)

echo "HTTP/1.1 200 OK"
echo "Content-Type: text/plain"
echo
echo "TCP:${PROTONWIRE_ADDRESS}:$(__get-protonwire-tcp-port)"
echo "UDP:${PROTONWIRE_ADDRESS}:$(__get-protonwire-udp-port)"
