#!/bin/bash

set -euo pipefail

install -m 0755 "${RECIPE_DIR}/files/pl4yrs-ap-fallback.sh" \
    /usr/local/sbin/pl4yrs-ap-fallback.sh
install -m 0755 "${RECIPE_DIR}/files/pl4yrs-setup-ap.sh" \
    /usr/local/sbin/pl4yrs-setup-ap.sh
install -m 0644 "${RECIPE_DIR}/files/pl4yrs-ap-fallback.service" \
    /etc/systemd/system/pl4yrs-ap-fallback.service
install -m 0644 "${RECIPE_DIR}/files/pl4yrs-ap-fallback.timer" \
    /etc/systemd/system/pl4yrs-ap-fallback.timer
install -m 0644 "${RECIPE_DIR}/files/pl4yrs-setup-ap.service" \
    /etc/systemd/system/pl4yrs-setup-ap.service

install -d -m 0755 /etc/pl4yrs
sed -e "s/UNPROVISIONED_DELAY_PLACEHOLDER/${RECIPE_PARAM_UNPROVISIONED_DELAY:-30}/" \
    -e "s/PROVISIONED_DELAY_PLACEHOLDER/${RECIPE_PARAM_PROVISIONED_DELAY:-180}/" \
    "${RECIPE_DIR}/files/ap-fallback.conf" \
    > /etc/pl4yrs/ap-fallback.conf

sed "s/REGDOM_PLACEHOLDER/${RECIPE_PARAM_WIFI_COUNTRY:-IT}/" \
    "${RECIPE_DIR}/files/hostapd-pl4yrs.conf" \
    > /etc/hostapd/pl4yrs.conf

sed "s/REGDOM_PLACEHOLDER/${RECIPE_PARAM_WIFI_COUNTRY:-IT}/" \
    "${RECIPE_DIR}/files/99-pl4yrs-regdom.rules" \
    > /etc/udev/rules.d/99-pl4yrs-regdom.rules
sed "s/REGDOM_PLACEHOLDER/${RECIPE_PARAM_WIFI_COUNTRY:-IT}/" \
    "${RECIPE_DIR}/files/pl4yrs-regdom.service" \
    > /etc/systemd/system/pl4yrs-regdom.service

install -D -m 0644 "${RECIPE_DIR}/files/90-pl4yrs-wlan0-mac.conf" \
    /etc/NetworkManager/conf.d/90-pl4yrs-wlan0-mac.conf

# hostapd and dnsmasq run under our own unit, not their packaged ones.
systemctl disable hostapd.service 2>/dev/null || true
systemctl disable dnsmasq.service 2>/dev/null || true
systemctl enable NetworkManager.service
systemctl enable pl4yrs-regdom.service
systemctl enable pl4yrs-ap-fallback.timer
