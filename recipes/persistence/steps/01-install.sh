#!/bin/bash

set -euo pipefail

install -D -m 0644 "${RECIPE_DIR}/files/pl4yrs.toml" -t /etc/rugix/state/

install -d -m 0755 /etc/systemd/journald.conf.d
sed "s/JOURNAL_MAX_USE_PLACEHOLDER/${RECIPE_PARAM_JOURNAL_MAX_USE:-64M}/" \
    "${RECIPE_DIR}/files/journald-pl4yrs.conf" \
    > /etc/systemd/journald.conf.d/pl4yrs.conf

# Pre-create the journal directory with proper ownership.
install -d -m 2755 -o root -g systemd-journal /var/log/journal
