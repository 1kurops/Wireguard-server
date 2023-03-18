#!/bin/bash
########################
#                      #
#      lastseenvpn     #
#                      #
########################


wgset="/etc/wireguard/scripts/wgset.conf"
source "${wgset}"
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}


# Parse input arguments
if [[ "$#" -gt 0 ]]; then
CLIENT_NAME="$1"
fi

cd /etc/$wireguard || exit

if [[ -z "${CLIENT_NAME}" ]]; then
  read -r -p "Enter a Name for the Client: " CLIENT_NAME
elif [[ "${CLIENT_NAME}" =~ [^a-zA-Z0-9.@_-] ]]; then
  err "Name can only contain alphanumeric characters and these symbols (.-@_)."
  exit 1
elif [[ "${CLIENT_NAME:0:1}" == "-" ]]; then
  err "Name cannot start with -"
  exit 1
elif [[ "${CLIENT_NAME}" =~ ^[0-9]+$ ]]; then
  err "Names cannot be integers."
  exit 1
elif [[ -z "${CLIENT_NAME}" ]]; then
  err "You cannot leave the name blank. "
  exit 1
elif [[ -f "configs/${CLIENT_NAME}.conf" ]]; then
  err "A client with this name already exists"
  exit 1
fi

wg genkey \
  | tee "keys/${CLIENT_NAME}_priv" \
  | wg pubkey > "keys/${CLIENT_NAME}_pub"
wg genpsk | tee "keys/${CLIENT_NAME}_psk" &> /dev/null
echo "Client Keys generated"

#generate random number and convertation on ipv4 adress
#check value virtual ip
if 
A=$(shuf -i 171966466-176160766 -n 1)
! grep -q "${A}" /etc/$wireguard/configs/clients.txt; then
    i=$A
    let "F1=$i/256**3"
    let "F2=($i-$F1*256**3)/256**2"
    let "F3=(($i-$F1*256**3)-$F2*256**2)/256"
    let "F4=(($i-$F1*256**3)-$F2*256**2)-$F3*256"
    VIRTUAL_IP=$F1.$F2.$F3.$F4
    echo "${CLIENT_NAME} $(< keys/"${CLIENT_NAME}"_pub) $(date +%s) ${A}" \
      | tee -a configs/clients.txt > /dev/null
elif 
A=$(shuf -i 171966466-176160766 -n 1)
! grep -q "${A}" /etc/$wireguard/configs/clients.txt; then
    i=$A
    let "F1=$i/256**3"
    let "F2=($i-$F1*256**3)/256**2"
    let "F3=(($i-$F1*256**3)-$F2*256**2)/256"
    let "F4=(($i-$F1*256**3)-$F2*256**2)-$F3*256"
    VIRTUAL_IP=$F1.$F2.$F3.$F4
    echo "${CLIENT_NAME} $(< keys/"${CLIENT_NAME}"_pub) $(date +%s) ${A}" \
      | tee -a configs/clients.txt > /dev/null
elif 
A=$(shuf -i 171966466-176160766 -n 1)
! grep -q "${A}" /etc/$wireguard/configs/clients.txt; then
    i=$A
    let "F1=$i/256**3"
    let "F2=($i-$F1*256**3)/256**2"
    let "F3=(($i-$F1*256**3)-$F2*256**2)/256"
    let "F4=(($i-$F1*256**3)-$F2*256**2)-$F3*256"
    VIRTUAL_IP=$F1.$F2.$F3.$F4
    echo "${CLIENT_NAME} $(< keys/"${CLIENT_NAME}"_pub) $(date +%s) ${A}" \
      | tee -a configs/clients.txt > /dev/null
else
    echo "please try again later"
    exit 1  
fi

{
  echo '[Interface]'
  echo "PrivateKey = $(cat "keys/${CLIENT_NAME}_priv")"
  echo -n "Address = $VIRTUAL_IP"
  echo
  echo -n "DNS = ${wgDNS1}"

  if [[ -n "${wgDNS2}" ]]; then
    echo ", ${wgDNS2}"
  else
    echo
  fi

  echo
  echo '[Peer]'
  echo "PublicKey = $(cat keys/server_pub)"
  echo "PresharedKey = $(cat "keys/${CLIENT_NAME}_psk")"
  echo "Endpoint = ${wgHOST}:${wgPORT}"
  echo "AllowedIPs = ${ALLOWED_IPS}"

  if [[ -n "${PERSISTENTKEEPALIVE}" ]]; then
    echo "PersistentKeepalive = ${PERSISTENTKEEPALIVE}"
  fi
} > "configs/${CLIENT_NAME}.conf"

echo "Client config generated"

{
  echo "### begin ${CLIENT_NAME} ###"
  echo '[Peer]'
  echo "# friendly_json={"\"id_user\"":"\"${A}\"", "\"user_name\"":"\"${CLIENT_NAME#*_}\"", "\"auth_data\"":"\"$(date +%s)\"", "\"locate\"":"\"${wgHOST}\""}"
  echo "PublicKey = $(cat "keys/${CLIENT_NAME}_pub")"
  echo "PresharedKey = $(cat "keys/${CLIENT_NAME}_psk")"
  echo "AllowedIPs = $VIRTUAL_IP/32"
  if [[ -n "${PERSISTENTKEEPALIVE}" ]]; then
  echo "PersistentKeepalive = ${PERSISTENTKEEPALIVE}"
  fi
  echo "### end ${CLIENT_NAME} ###"
} >> $wg0.conf

echo "Updated server config"


  if systemctl reload wg-quick@wg0; then
    echo "WireGuard reloaded"
  else
    err "Failed to reload WireGuard"
  fi

