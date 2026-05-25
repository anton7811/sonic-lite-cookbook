# Wazuh installation and configuration

1. [Server configuration](#wazuh-system-installation-on-linux-server)
2. [Switch configuration](#wazuh-agent-configuration-on-sonic-lite-switch)

## Disclaimer

This is a quick guide for connecting SONiC Lite and Wazuh. For full Wazuh documentation, see the official site: https://wazuh.com/

## Wazuh system installation on Linux server


### Install Wazuh manager, dashboard, and indexer

```bash
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && sudo bash ./wazuh-install.sh -a
```

### Add rule(s) to generate alerts

This step is required to confirm that syslog messages from SONiC Lite are ingested by the Wazuh manager.

By default, Wazuh stores incoming logs in the archives without generating alerts unless they match predefined rules, so syslog forwarding is hard to verify. A custom rule makes specific log entries trigger alerts and confirms that syslog integration works.

> **NOTE**: Decide which events you need to track and add rules for them.

Below is an **example** of how to alert on *SyncD* logs so they appear in Wazuh:

```bash
sudo vi /var/ossec/etc/rules/local_rules.xml
```

```xml
<group name="sonic,syslog">

  <rule id="100002" level="5">
    <match>syncd</match>
    <description>SyncD event detected</description>
  </rule>

</group>
```

### Restart the Wazuh manager

```bash
sudo systemctl restart wazuh-manager
```


## Wazuh agent configuration on SONiC Lite switch


### Install Wazuh agent

Use the architecture that matches your switch (`uname -m`).

```bash
ARCH=$(uname -m)
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.3-1_${ARCH}.deb && \
sudo WAZUH_MANAGER='<WAZUH_SERVER_IP>' WAZUH_AGENT_NAME='sonic' dpkg -i ./wazuh-agent_4.14.3-1_${ARCH}.deb
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
```

### Set the Wazuh manager IP in `/var/ossec/etc/ossec.conf`

```bash
sudo vi /var/ossec/etc/ossec.conf
```

Replace `WAZUH_SERVER_IP` with the IP address of your Linux server (Wazuh manager):

```xml
...
<client>
  <server>
    <address>WAZUH_SERVER_IP</address>
  </server>
</client>
...
```

### Enable syslog forwarding to the Wazuh server

On the SONiC Lite switch:

```bash
sudo config syslog add <WAZUH_SERVER_IP> -p 514
```
