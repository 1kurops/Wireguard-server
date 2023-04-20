#!/bin/bash
########################
#                      #
#      lastseenvpn     #
#                      #
########################

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

apt-get update
apt-get --yes --no-install-recommends install net-tools
apt-get --yes --no-install-recommends install git
apt-get --yes --no-install-recommends install wireguard
apt-get --yes --no-install-recommends install rsync
apt-get --yes --no-install-recommends install cron
WgUrl="https://github.com/1kurops/wireguard-server.git"
cd /opt/
echo "cloning reporitory"

git clone $WgUrl
touch /opt/wireguard-server/wgset.conf
wgset="/opt/wireguard-server/wgset.conf"
touch /etc/wireguard/wg0.conf
wgconf="/etc/wireguard/wg0.conf"

function setup_master_server_info() {
  IP_MAIN_SERV="$(dig +short myip.opendns.com @208.67.222.222)"
  echo "IP addres server $IP_MAIN_SERV"
  echo -n "Please enter the domain name: "
  read -r domain_name
}

function setup_slave_server_info() {
  echo -n "Please enter the ipAddress slave server: "
  read -r IP_SLAVE_SERV
  echo -n "Please enter the domain name: "
  read -r domain_name
}

function verify_domainname() {
  if [ -z "$domain_name" ]; then
    echo "error domain name, be used IPaddres"
    IPv4pub="$(dig +short myip.opendns.com @208.67.222.222)"
  else
    if [ -z "$ip_address" ]; then
      echo "error domain name, be used IPaddres"
      IPv4pub="$(dig +short myip.opendns.com @208.67.222.222)"
    else
      echo "domain name corrert"
      IPv4pub=$domain_name
    fi
  fi
}

function master_slave_property() {
  echo -n "Specify if this is a master or slave server (m/s): "
  read -r master_slave

  if [ -z "$master_slave" ]; then
    echo "Please enter m or s"
    master_slave_property
  elif [ "$master_slave" != "m" ] && [ "$master_slave" != "s" ]; then
    echo "Invalid input. Please enter m or s"
    master_slave_property
  fi
}

function slave_availability() {
  echo -n "do you have slave server ? (y/n): "
  read -r slave_true
  if [ -z "$slave_true" ]; then
    echo "Please enter y or n"
  elif [ "$slave_true" != "y" ] && [ "$slave_true" != "n" ]; then
    echo "Invalid input. Please enter y or n"
    slave_availability
  elif [ "$slave_true" != "n" ]; then
    setup_slave_server_info
  else
    setup_master_server_info
  fi
}
echo -n "Please enter the port vpn server (default 51820): "
read -r port
if [ -z "$port" ]; then
  wgPORT="51820"
else
if [ ! -z "$port" ]; then
  wgPORT="$port"
fi
fi
echo -n "Please enter the DNS (default 1.1.1.1): "
read -r DNS
if [ -z "$DNS" ]; then
  wgDNS1="1.1.1.1"
  wgDNS2="1.0.0.1"
else
if [ ! -z "$DNS" ]; then
  wgDNS1=$DNS
fi
fi
echo -n "Please enter the MTU (default 1420): "
read -r MTU
if [ -z "$MTU" ]; then
  wgMTU="1420"
else
  wgMTU="$MTU"
fi

{
  echo "wgNET=10.64.0.1"
  echo "subnetClass=10"
  echo "ALLOWED_IPS="0.0.0.0/0, ::0/0""
  echo "PERSISTENTKEEPALIVE="
  echo "wgPORT=$wgPORT"
  echo "wgDNS1=$wgDNS1"
  echo "wgDNS2=$wgDNS2"
  echo "wgMTU=$wgMTU"
} >>$wgset

master_slave_property
if [ $master_slave == "m" ]; then
  slave_availability
  if [ $slave_true == "y" ]; then
    setup_slave_server_info
    verify_domainname "$domain_name"
    cd /root/.ssh/
    {
      echo "Host slave"
      echo "HostName $IP_SLAVE_SERV"
      echo "Port 22"
      echo "User root"
      echo "IdentityFile ~/.ssh/$name"
      echo "IdentitiesOnly yes"
      echo "wgDEV=wg0"
    } >>config
    echo "IpSlave=$IP_SLAVE_SERV" >>$wgset
  else
    echo "Setup main server"
    setup_master_server_info
    verify_domainname "$domain_name"
    echo "wgHOST=$IPv4pub" >>$wgset
  fi
fi

echo "Setup available Interface"
availableInterfaces="$(echo "$(ip -o link)" | awk '/state UP/ {print $2}')"
availableInterfaces="$(echo "${availableInterfaces}" |
  cut -d ':' -f 1 |
  cut -d '@' -f 1 |
  grep -v -w 'lo' |
  grep -v '^docker' |
  head -1)"
echo "IPv4dev=$availableInterfaces" >>$wgset
IPv4dev=$availableInterfaces

cp -r /opt/wireguard-server/scripts/ /etc/wireguard/
mkdir /etc/wireguard/configs
mkdir /etc/wireguard/keys

source "${wgset}"
wg genkey |
  tee /etc/wireguard/keys/server_priv &>/dev/null
cat /etc/wireguard/keys/server_priv |
  wg pubkey |
  tee /etc/wireguard/keys/server_pub &>/dev/null

echo "Server Keys have been generated."
{
  echo '[Interface]'
  echo "PrivateKey = $(cat /etc/wireguard/keys/server_priv)"
  echo "Address = ${wgNET}/${subnetClass}"
  echo "MTU = ${wgMTU}"
  echo "ListenPort = ${wgPORT}"
  echo "PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $IPv4dev -j MASQUERADE"
  echo "PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $IPv4dev -j MASQUERADE"

} | tee /etc/wireguard/wg0.conf &>/dev/null
echo "Enable Forwarding"
forward="net.ipv4.ip_forward=1"
if ! grep -q "$forward" /etc/sysctl.conf; then
  echo "$forward" >>/etc/sysctl.conf
else
  sed -i "s|#net.ipv4.ip_forward=1|${forward}|" /etc/sysctl.conf
fi
echo 'net.ipv4.ip_forward=1' |
  tee /etc/sysctl.d/99-wireguard.conf >/dev/null
sysctl -p

cat /etc/wireguard/scripts/wg-quick@.service >/etc/systemd/system/wg-quick@.service
rm /etc/wireguard/scripts/wg-quick@.service
systemctl daemon-reload
systemctl start wg-quick@wg0.service
systemctl enable wg-quick@wg0.service

{
  echo "30 1 * * * root bash /etc/wireguard/scripts/backup.sh &> /dev/null"
  echo "30/* * * * root bash /etc/wireguard/scripts/banscript.sh 10 &> /dev/null"
  echo "1 */1 * * * root bash /etc/wireguard/scripts/wg_disable.sh -b &> /dev/null"
  echo "2 2 * * * root bash /etc/wireguard/scripts/wg_enable.sh -ub &> /dev/null"
  echo "1 1 * * * root bash /etc/wireguard/scripts/usercheck.sh &> /dev/null"
  echo "5 2 * * * root wg-quick down wg0; systemctl restart wg-quick@wg0.service"
  echo "* * * * * root systemctl reload wg-quick@wg0.service"
} >>/etc/crontab

chmod 700 /etc/wireguard/
chmod +x /etc/wireguard/scripts/*.sh
mv $wgset /etc/wireguard/scripts/
export PATH=$PATH:/etc/wireguard/scripts
source ~/.bashrc

echo "Installation Complete!"
