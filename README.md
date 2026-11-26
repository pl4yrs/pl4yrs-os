# pl4yrs-os

Build repository for the pl4yrs Raspberry Pi image: a minimal,
OTA-updatable Linux image shipping based on the awesome Rugix project.

## Layout

- `rugix-bakery.toml`. Defines the systems: `rpi-uboot-arm64` (production, Pi3) and
  `rpi-uboot-arm64-dev` (same layer + `development` mixin).
- `layers/customized.toml`. Uses `core/debian-trixie` (bootstrapped) +
  `core/rpi-debian-setup` (RPi kernel/firmware via the Raspberry Pi apt repo)
  + recipe list + parameters.
- `mixins/development.toml`. Defines dev-only extras: `core/ssh` with embedded keys
  and `dev-tools` (tmux, vim).
- `recipes/`. Configures `pl4yrs` (service user + sendspin-cli, pl4yrs-backend and
  pl4yrs-tui debs), `ap-fallback` (hostapd provisioning hotspot, adaptive delay),
  `pl4yrs-web` (placeholder page to test the AP fallback), `dev-tools` (debug
  packages, dev mixin only).
- `run-bakery`. Stock Rugix Bakery wrapper (`RUGIX_BAKERY_IMAGE=v0.9.6`).

### pl4yrs debs

The `pl4yrs` recipe installs `pl4yrs-backend` and `pl4yrs-tui` `.deb`s built from
the [pl4yrs repo](https://github.com/pl4yrs/pl4yrs). To test local builds,
drop them into `recipes/pl4yrs/files/`.

## Build

As I'm building mostly on MacOS, there is a helpful build script to be used
instead of the standard `./run-bakery`. This one should also work, but it's
currently untested.

```bash
./build.sh                    # bake all systems (production + dev)
./build.sh rpi-uboot-arm64    # bake only the listed system(s)
```

The script wraps the named-volume workflow macOS requires (VirtioFS bind
mounts lack xattr/ACL support): sources are synced into
`pl4yrs-rugix-build`, baked there, artifacts copied back to `build/`, and
`system.img.xz` is produced.
This can probably be optimized, but for now it's good enough.

Systems:
- `rpi-uboot-arm64` (production — sshd but no keys, no debug tools)
and
- `rpi-uboot-arm64-dev` (adds the `development` mixin: SSH keys, tmux,
vim, dotfiles).

Artifacts: `build/<system>/` — `system.img` / `system.img.xz` (flash),
`system.rugixb` (OTA bundle, unsigned), `system.rugixb-hash`, SBOMs.

## Flash / update on device

Once a new image is built, you can either flash it to an SD or scp it
over to your device, and run there in-place upgrade process.

```bash
# OTA (unsigned bundle, dev only)
rugix-ctrl update install --insecure-skip-bundle-verification system.rugixb
# Once completed it will reboot into the new system
# You can then check the status and commit changes
rugix-ctrl system info       # slot state
rugix-ctrl system commit     # make the new slot permanent (or next boot rolls back)
```

## Fallback AP

If no Ethernet connection is detected, after a timeout of ~60 seconds the system
will activate a fallback AP over WiFI.

- ESSID: `pl4yrs-setup`
- Password: `pl4yrs-setup`

The device will setup the local ip `10.42.0.1`. You can then ssh into it to
perform the manual setup. There is also a placeholder http server (nginx)
which will later replaced by a web UI to manage the fist-book configuration.
