#!/bin/bash

set -euo pipefail

install -m 0644 "${RECIPE_DIR}/files/tmux.conf" /etc/tmux.conf
install -m 0644 "${RECIPE_DIR}/files/vimrc" /root/.vimrc
