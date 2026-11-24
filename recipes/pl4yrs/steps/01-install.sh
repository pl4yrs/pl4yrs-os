#!/bin/bash

set -euo pipefail

# Create the pl4yrs user
useradd --system --groups audio --shell /usr/sbin/nologin \
    --comment "pl4yrs service account" pl4yrs 2>/dev/null || true

# Rugix bootstrap layout
mkdir -p /etc/rugix
sed "s/@SYSTEM_SIZE@/${RECIPE_PARAM_SYSTEM_SIZE}/" \
    "${RECIPE_DIR}/files/bootstrapping.toml" > /etc/rugix/bootstrapping.toml
chmod 644 /etc/rugix/bootstrapping.toml

# Locale: Debian minbase ships none generated.
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/default/locale

# Pinned sendspin-cli release.
deb=/tmp/sendspin-cli.deb
curl -fsSL "${RECIPE_PARAM_SENDSPIN_URL}" -o "${deb}"
echo "${RECIPE_PARAM_SENDSPIN_SHA256}  ${deb}" | sha256sum -c -
apt-get install -y "${deb}"
rm -f "${deb}"

systemctl enable sendspin-cli.service
