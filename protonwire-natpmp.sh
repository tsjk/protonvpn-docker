#!/bin/bash
declare -g F='/log/protonwire-natpmpc.log'

__update_natpmp() {
  local -i r=0
  ts "[%Y-%m-%dT%H:%M:%S] |" <({ date "+%Y-%m-%d %H:%M:%S"; natpmpc -a 1 0 udp 60 -g 10.2.0.1; r=${?}; [[ ${r} -eq 0 ]] && { natpmpc -a 1 0 tcp 60 -g 10.2.0.1; r=${?}; }; } 2>&1) >> "${F}"
  return ${r}
}
__trim_log() {
  [[ $(wc -l < "${F}") -lt $((128 * 1024)) ]] || sed "1,$(( (128 * 1024) - (96 * 1024) ))d" "${F}" | sponge "${F}"
}
__socat_server() {
  [[ ! -f "/usr/bin/protonwire-natpmp-info-reporter-service.sh" || ! -s "/usr/bin/protonwire-natpmp-info-reporter-service.sh" ]] || \
    { socat "TCP-LISTEN:1009,bind=$(ip -j address show eth0 | jq -r '.[] | .addr_info[].local'),crlf,reuseaddr,fork" SYSTEM:"/bin/bash -c /usr/bin/protonwire-natpmp-info-reporter-service.sh" & }
}
__sleep() {
  [[ "${1}" =~ ^[0-9][0-9]*$ ]] && \
    { local -i T=$(( $(date "+%s") + ${1} )); while [[ $(date "+%s") -lt ${T} ]]; do sleep 1; done; }
}

__socat_server
while true; do
  __update_natpmp || \
    { echo "Failed to update port mapping" | ts "[%Y-%m-%dT%H:%M:%S] |" >&2; }
  __trim_log; __sleep 45
done
