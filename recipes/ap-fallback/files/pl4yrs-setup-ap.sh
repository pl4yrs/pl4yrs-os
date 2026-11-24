#!/bin/bash
# Start/stop the provisioning hotspot (hostapd + dnsmasq on wlan0 @ 10.42.0.1).
set -u

case "${1:-start}" in
start)
    rfkill unblock wifi 2>/dev/null || true
    nmcli device set wlan0 managed no 2>/dev/null || true
    # NM may leave a scan-randomized MAC behind; restore the permanent one or
    # hostapd advertises a BSSID that doesn't match the driver state.
    perm=$(ethtool -P wlan0 2>/dev/null | awk '{print $3}')
    [ -n "$perm" ] && ip link set wlan0 address "$perm" 2>/dev/null || true
    ip addr flush dev wlan0 || true
    ip addr add 10.42.0.1/24 dev wlan0
    ip link set wlan0 up
    hostapd -B /etc/hostapd/pl4yrs.conf
    exec /usr/sbin/dnsmasq --interface=wlan0 --bind-interfaces \
        --dhcp-range=10.42.0.10,10.42.0.254,1h \
        --pid-file=/run/pl4yrs-dnsmasq.pid
    ;;
stop)
    pkill -f "dnsmasq.*pl4yrs-dnsmasq" 2>/dev/null || true
    pkill -x hostapd 2>/dev/null || true
    ip addr flush dev wlan0 2>/dev/null || true
    nmcli device set wlan0 managed yes 2>/dev/null || true
    ;;
esac
