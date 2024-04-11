#!/bin/bash
# shellcheck disable=SC2317
declare -g -i RETRY_INTERVAL_IN_SECONDS=20
declare -g -i DO_RUN=1
declare -g -i DO_RECONNECT=0
declare -g -i PROTONWIRE_EXIT_CODE=0
declare -g -i PROTONWIRE_PID=0

__sleep() {
  [[ "${1}" =~ ^[0-9][0-9]*$ ]] && {
    local -i T=$(( $(date "+%s") + ${1} ))
    while [[ ${DO_RUN} -ne 0 && $(date "+%s") -lt ${T} ]]; do sleep 1; done
   }
}

__sigint_handler() {
  echo "entrypoint.sh: Received SIGINT, exiting..."
  DO_RUN=0; [[ ${PROTONWIRE_PID} -eq 0 ]] || kill -INT "${PROTONWIRE_PID}"
}

__sigterm_handler() {
  echo "entrypoint.sh: Received SIGTERM, exiting..." >&2
  DO_RUN=0; [[ ${PROTONWIRE_PID} -eq 0 ]] || kill -TERM "${PROTONWIRE_PID}"
}

__sighup_handler() {
  echo "entrypoint.sh: Received SIGHUP, disconnecting..." >&2
  DO_RECONNECT=1
  [[ ${PROTONWIRE_PID} -eq 0 ]] || kill -TERM "${PROTONWIRE_PID}"
}

__get_server_info() {
  [[ -n "${PROTONVPN_SERVER}" ]] || return 1
  local f="/tmp/protonwire.server.json"
  [[ $(( $(date '+%s') - $(stat -c '%Y' "${f}") )) -gt 3600 || $(jq '.Nodes | length' "${f}.new" 2> /dev/null) -le 0 ]] || return 0
  local u; local -i T=3 t=0
  [[ -n "${METADATA_URL}" ]] && u="${METADATA_URL}" || u="https://protonwire-api.vercel.app/v1/server"; u="${u}/${PROTONVPN_SERVER//#/-}"
  while true; do
    curl -sSfL -A 'protonwire/v7' -m 30 -o "${f}.new" "${u}"
    [[ ${?} -ne 0 || $(jq '.Nodes | length' "${f}.new" 2> /dev/null) -le 0 ]] || \
      { mv --force "${f}.new" "${f}"; return 0; }
    [[ ${t} -lt ${T} ]] || return 1
    t+=1; sleep 10
  done
}

trap '__sigint_handler' SIGINT
trap '__sigterm_handler' SIGTERM
trap '__sighup_handler' SIGHUP

while [[ ${DO_RUN} -ne 0 ]]; do
  __get_server_info || echo "Failed to get server metadata..." | ts 'entrypoint.sh[%Y-%m-%d %H:%M:%.S]:' >&2
  /usr/bin/protonwire connect --container --log-format long &
  PROTONWIRE_PID=${!}; wait -p PROTONWIRE_EXIT_CODE "${PROTONWIRE_PID}"; PROTONWIRE_PID=0
  if [[ ${DO_RECONNECT} -ne 0 ]]; then
    DO_RECONNECT=0
    echo "Received SIGHUP, will try to reconnect in ${RETRY_INTERVAL_IN_SECONDS} seconds." | ts 'entrypoint.sh[%Y-%m-%d %H:%M:%.S]:' >&2
    __sleep ${RETRY_INTERVAL_IN_SECONDS}
  elif [[ ${DO_RUN} -ne 0 ]]; then
    echo "entrypoint.sh: protonwire script died (with exit code ${PROTONWIRE_EXIT_CODE}) - disconnecting..." | ts 'entrypoint.sh[%Y-%m-%d %H:%M:%.S]:' >&2
    /usr/bin/protonwire disconnect --container --log-format long
    echo "...will try to reconnect in ${RETRY_INTERVAL_IN_SECONDS} seconds." | ts 'entrypoint.sh[%Y-%m-%d %H:%M:%.S]:' >&2
    __sleep ${RETRY_INTERVAL_IN_SECONDS}
  fi
  [[ ! -e /etc/resolv.conf.protonwire ]] || \
    { cat /etc/resolv.conf.protonwire > /etc/resolv.conf; rm -f /etc/resolv.conf.protonwire; }
done

exit ${PROTONWIRE_EXIT_CODE}
