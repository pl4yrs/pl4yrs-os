#!/bin/bash
# Health-gated mark-good for provisional Rugix boots.
#
# Runs once per boot (oneshot). When the active boot group differs from the
# default poll the health gate.
#
# On success, calls `rugix-ctrl system commit` to mark this slot as the default.
#
# If unhealthy at DEADLINE, reboot.
# The boot flow falls back to the previously committed slot.
set -u

CONFIG_MOUNT=/run/rugix/mounts/config

HEALTH_URL=http://127.0.0.1:4243/health
SERVICES="pl4yrs-backend.service sendspin-cli.service"
POLL_INTERVAL=15
DEADLINE=300
VETO_FILE=pl4yrs/no-mark-good
[ -f /etc/pl4yrs/mark-good.conf ] && . /etc/pl4yrs/mark-good.conf

if [ -e "${CONFIG_MOUNT}/${VETO_FILE}" ]; then
    echo "mark-good: vetoed by ${CONFIG_MOUNT}/${VETO_FILE}"
    exit 0
fi

info=$(rugix-ctrl system info --json 2>/dev/null) || {
    echo "mark-good: unable to query system info" >&2
    exit 1
}
active=$(printf '%s' "$info" | sed -n 's/.*"activeGroup":"\([^"]*\)".*/\1/p')
default=$(printf '%s' "$info" | sed -n 's/.*"defaultGroup":"\([^"]*\)".*/\1/p')

if [ -z "$active" ] || [ -z "$default" ]; then
    echo "mark-good: unable to determine active/default boot group"
    exit 0
fi
if [ "$active" = "$default" ]; then
    echo "mark-good: boot group ${active} is committed, nothing to do"
    exit 0
fi

echo "mark-good: provisional boot of group ${active} (default ${default}), polling health for ${DEADLINE}s"

deadline=$(( $(cut -d. -f1 /proc/uptime) + DEADLINE ))
while true; do
    healthy=1
    for svc in $SERVICES; do
        if ! systemctl is-active --quiet "$svc"; then
            echo "mark-good: ${svc} not active"
            healthy=0
        fi
    done
    if ! curl -fsS -o /dev/null --max-time 5 "$HEALTH_URL"; then
        echo "mark-good: ${HEALTH_URL} unhealthy"
        healthy=0
    fi
    if [ "$healthy" -eq 1 ]; then
        echo "mark-good: healthy, committing boot group ${active}"
        exec rugix-ctrl system commit
    fi
    if [ "$(cut -d. -f1 /proc/uptime)" -ge "$deadline" ]; then
        echo "mark-good: deadline reached and still unhealthy, rebooting to previous slot" >&2
        systemctl reboot
        exit 1
    fi
    sleep "$POLL_INTERVAL"
done
