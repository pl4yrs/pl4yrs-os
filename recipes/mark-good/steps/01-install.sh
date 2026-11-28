#!/bin/bash

set -euo pipefail

install -m 0755 "${RECIPE_DIR}/files/pl4yrs-mark-good.sh" \
    /usr/local/sbin/pl4yrs-mark-good.sh
install -m 0644 "${RECIPE_DIR}/files/pl4yrs-mark-good.service" \
    /etc/systemd/system/pl4yrs-mark-good.service

install -d -m 0755 /etc/pl4yrs
install -m 0644 "${RECIPE_DIR}/files/pl4yrs-mark-good.conf" \
    /etc/pl4yrs/mark-good.conf

systemctl enable pl4yrs-mark-good.service
