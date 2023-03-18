#!/bin/bash

wgset="/etc/wireguard/scripts/wgset.conf"

if [[ ! -f "${wgset}" ]]; then
  err "Missing setup vars file!"
  exit 1
fi

# shellcheck disable=SC1090
source "${wgset}"
banlist="/etc/wireguard/banlist.txt"

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

cd /etc/wireguard || exit
unban () {
  CHANGE=0
  for CLIENT_NAME in $(cat $banlist); do
  #если не находит имя пользователя
  if ! grep -q "^${CLIENT_NAME} " configs/clients.txt; then
    exit 1
  else
  if grep -q "${CLIENT_NAME}" wg0.conf; then
      # Enable the peer section from the server config
      sed_pattern="/begin ${CLIENT_NAME}/,"
      sed_pattern="${sed_pattern}/end ${CLIENT_NAME}/ s/#\[disabled\] //"
      sed -e "${sed_pattern}" -i wg0.conf
      unset sed_pattern

      echo "Updated server config"
      ((CHANGE++))
      echo "Successfully enabled ${CLIENT_NAME}"
  fi
  fi
  done
  echo  > $banlist
  # Restart WireGuard only if some clients were actually deleted
      if [[ "${CHANGE}" -gt 0 ]]; then
      if systemctl reload wg-quick@wg0; then
        echo "WireGuard reloaded"
      else
        echo "Failed to reload WireGuard"
      fi
    fi
}
enableconf () {
  if [[ ! -s configs/clients.txt ]]; then
    err "There are no clients to change"
    exit 1
  fi

  if [[ "${DISPLAY_DISABLED}" ]]; then
    grep '\[disabled\] ### begin' wg0.conf | sed 's/#//g; s/begin//'
    exit 1
  fi

  mapfile -t LIST < <(awk '{print $1}' configs/clients.txt)

  if [[ "${#CLIENTS_TO_CHANGE[@]}" -eq 0 ]]; then
    echo -e "::\e[4m  Client list  \e[0m::"
    len="${#LIST[@]}"
    COUNTER=1

    while [[ "${COUNTER}" -le "${len}" ]]; do
      printf "%0${#len}s) %s\r\n" "${COUNTER}" "${LIST[(($COUNTER - 1))]}"
      ((COUNTER++))
    done

    echo -n "Please enter the Index/Name of the Client to be enabled "
    echo -n "from the list above: "
    read -r CLIENTS_TO_CHANGE

    if [[ -z "${CLIENTS_TO_CHANGE}" ]]; then
      err "You can not leave this blank! "
      exit 1
    fi
  fi

CHANGE=0

  for CLIENT_NAME in "${CLIENTS_TO_CHANGE[@]}"; do
    re='^[0-9]+$'

      if [[ "${CLIENT_NAME}" =~ $re ]]; then
        CLIENT_NAME="${LIST[$((CLIENT_NAME - 1))]}"
      fi

      if ! grep -q "^${CLIENT_NAME} " configs/clients.txt; then
      echo -e "\e[1m${CLIENT_NAME}\e[0m does not exist"
      else
        if [[ -n "${CONFIRM}" ]]; then
          REPLY="y"
        else
        read -r -p "Confirm you want to enable ${CLIENT_NAME}? [Y/n] "
        fi

        if [[ "${REPLY}" =~ ^[Yy]$ ]] || [[ -z "${REPLY}" ]]; then
          echo "${CLIENT_NAME}"

          sed_pattern="/begin ${CLIENT_NAME}/,"
          sed_pattern="${sed_pattern}/end ${CLIENT_NAME}/ s/#\[disabled\] //"
          sed -e "${sed_pattern}" -i wg0.conf
          unset sed_pattern

          echo "Updated server config"
        ((CHANGE++))
          echo "Successfully enabled ${CLIENT_NAME}"
        fi
      fi
  done
# Restart WireGuard only if some clients were actually deleted
  if [[ "${CHANGE}" -gt 0 ]]; then
    if systemctl reload wg-quick@wg0; then
      echo "WireGuard reloaded"
    else
      echo "Failed to reload WireGuard"
    fi
  fi

}


if [[ "$#" -eq 0 ]]; then
  disableconf
else
  while true; do
    case "${1}" in
      -ub | unban)
        unban
        exit 0
        ;;
      *)
        enableconf
        exit 0
        ;;
    esac
  done
fi