#!/bin/bash
# Spawn the provisioning hotspot when the device has no network connectivity.
# Intended to be run periodically from pl4yrs-ap-fallback.timer.
#
# Adaptive delay: without any saved Wi-Fi profile the AP fires after
# UNPROVISIONED_DELAY; once a profile exists, PROVISIONED_DELAY applies so a
# transient outage doesn't flap the hotspot. "Offline since" is tracked in
# /run and defaults to boot time, so a fresh device gets the AP quickly.
set -u

NMCLI=/usr/bin/nmcli
STAMP=/run/pl4yrs-offline-since

UNPROVISIONED_DELAY=30
PROVISIONED_DELAY=180
[ -f /etc/pl4yrs/ap-fallback.conf ] && . /etc/pl4yrs/ap-fallback.conf

rfkill unblock wifi 2>/dev/null || true

# Online if any ethernet or wifi device is connected.
online() {
    $NMCLI -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
        awk -F: '($2 == "ethernet" || $2 == "wifi") && $3 == "connected" { found=1 } END { exit !found }'
}

now=$(date +%s)

# Online: reset the offline marker and tear the hotspot down.
if online; then
    echo "$now" > "$STAMP"
    systemctl is-active --quiet pl4yrs-setup-ap.service && \
        systemctl stop pl4yrs-setup-ap.service
    exit 0
fi

# Hotspot already up.
systemctl is-active --quiet pl4yrs-setup-ap.service && exit 0

if $NMCLI -t -f connection.type connection show 2>/dev/null | grep -qx 802-11-wireless; then
    delay=$PROVISIONED_DELAY
else
    delay=$UNPROVISIONED_DELAY
fi

if [ -f "$STAMP" ]; then
    offline_since=$(cat "$STAMP")
    offline_for=$((now - offline_since))
else
    # Never observed connectivity this boot: count from boot, but give the
    # network at least BOOT_GRACE seconds to come up first (slow DHCP).
    offline_for=$(cut -d. -f1 /proc/uptime)
    [ "$offline_for" -ge "${BOOT_GRACE:-60}" ] || exit 0
fi

[ "$offline_for" -ge "$delay" ] || exit 0

exec systemctl start pl4yrs-setup-ap.service
