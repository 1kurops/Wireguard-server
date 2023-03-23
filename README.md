# Wireguard-server

This project provides automatic deployment of a WireGuard VPN server depending on the server group. It includes the installation and initial setup of a master or slave VPN server, setting up the WireGuard unit, activating its auto-loading, enabling traffic forwarding, copying scripts from the repository for creating, deleting, updating, disabling, and enabling WireGuard configurations. It also includes copying the Prometheus exporter for WireGuard and its setup and activation.

The project involves using the WireGuard Exporter for Prometheus, developed by MindFlavor, for monitoring purposes. The scripts used in the project have an added feature that utilizes the "friendly_name" parameter of the exporter, making it easier to monitor the consumption and usage of each configuration. 

### Technologies

`WireGuard, Bash.`


## Installation

To install, run the following command with root privileges:
```
sudo curl -o- https://raw.githubusercontent.com/1kurops/wireguard-server/main/installwg-server.sh | bash
```

## Configuration

This configuration uses the /10 subnet mask for the internal subnet, which means you will have access to generating 4,194,304 internal IP addresses. Thus, the maximum number of configurations is 4,194,304.

### To manage WireGuard configurations, use the following scripts located in `/etc/wireguard/scripts/`:

  `wg_make.sh`: creates a new configuration. This script also supports arguments. For example, running wg_make.sh conf_name will create a configuration with the name "conf_name."

  `wg_remove.sh`: deletes a configuration. This script also supports arguments.

  `wg_disable.sh`: disables a configuration.

  `wg_enable.sh`: enables a configuration.

  `clients.sh` displays information about clients.

Additionally, there are several service scripts that are active by default:

  `backup.sh`: creates an incremental backup of the WireGuard directory. Copies of backups older than 14 days are automatically deleted.
  
  `banscript.sh`: tracks traffic usage and, if it exceeds a certain limit (10GB by default), disables the configuration until the next day.
  
  `clientcheck.sh`: tracks unused configurations and writes their names to the file /opt/wireguard_server/usercheck.txt.

### Contributors

1kurops
