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

# pl4yrs debs: pinned URLs when the params are set, otherwise local dev builds
# dropped into recipes/pl4yrs/files/.
install_pl4yrs_deb() {
    local name="$1" url="$2" sha256="$3"
    local deb
    if [ -n "${url}" ]; then
        [ -n "${sha256}" ] || { echo "pl4yrs: ${name} sha256 param required with a URL" >&2; exit 1; }
        deb="/tmp/${name}.deb"
        curl -fsSL "${url}" -o "${deb}"
        echo "${sha256}  ${deb}" | sha256sum -c -
    else
        deb="$(find "${RECIPE_DIR}/files" -maxdepth 1 -name "${name}_*.deb" | head -1)"
        [ -n "${deb}" ] || { echo "pl4yrs: no ${name} .deb — set the url params or drop one in files/" >&2; exit 1; }
    fi
    apt-get install -y "${deb}"
    case "${deb}" in /tmp/*) rm -f "${deb}" ;; esac
}

install_pl4yrs_deb pl4yrs-backend \
    "${RECIPE_PARAM_BACKEND_DEB_URL}" "${RECIPE_PARAM_BACKEND_DEB_SHA256}"
install_pl4yrs_deb pl4yrs-tui \
    "${RECIPE_PARAM_TUI_DEB_URL}" "${RECIPE_PARAM_TUI_DEB_SHA256}"

systemctl enable pl4yrs-backend.service
