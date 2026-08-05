# Handoff: install path and boot screens

State of the work as of commit `8090344f` (2026-08-02). Written for whoever
picks this up next, including a future me. It covers what changed, what is
genuinely verified versus merely written, what is still missing, and how to
debug a Fedory VM without rediscovering the awkward parts.

## Context

Work started from a single report — a fresh bootstrap failed while configuring
the login screen — and followed the causes outward. Every change below came
from a real failure on a real install, not from reading code looking for
problems. Nine commits, `ca77469a..8090344f`. The shell suite went from 313 to
396 assertions across 25 files.

## What changed

### Install reliability

- **`ca77469a`** — `fedory-pkg-add` now waits for the RPM database lock before
  installing. A bootstrap lost a race against a concurrent transaction; dnf
  aborted the whole 386-package transaction, 65 packages including `sddm`
  never installed, and the only visible error was `install/login/sddm.sh`
  failing to copy a theme into a `/usr/share/sddm` that never existed. The
  guard already existed but only `fedory-migrate` used it. Also dropped two
  `|| true`s that made a wholesale transaction failure look like success.
- **`6799cf58`** — that guard then *looked* like a hang: a 900s ceiling with
  one printed line and silent polling. Now 120s, emitting `[waited/timeout]`
  markers so the progress bar counts down.

### Boot screens

- **`592800a1`** — the Plymouth theme shipped in `default/plymouth/` but
  nothing ever installed it. Fresh installs booted on Fedora's stock `bgrt`,
  which draws the firmware logo — and a VM has none, so with `rhgb quiet` the
  whole boot was a black screen.
- **`fb217303`** — that step then failed with `/usr/lib64/plymouth/script.so
  does not exist`. The theme declares `ModuleName=script` and the `plymouth`
  package does not ship the script renderer; `plymouth-plugin-script` was
  never in the package list.
- **`8090344f`** — GRUB theming, previously a deliberate stub. See below.

### Installer UX

- **`67e4e835`** — progress bars redrawn with block glyphs, sub-cell
  precision, a gradient fill, and a comet for indeterminate waits. Falls back
  to the original ASCII bars outside a UTF-8 locale.
- **`3bcc5406`** — optional install groups (`office-media`, `docker`,
  `printing`), offered opt-out at bootstrap. Verified end to end: declining all
  three took a real install from 394 packages / 3.19 GiB to 229 / 1.96 GiB,
  with nothing from a declined group leaking into the transaction.

### First-run

- **`ceece86d`** — the keybindings toast rendered with a literal `\n` and its
  heading stranded mid-message. Two causes: a double-quoted `\n`, and an empty
  `-g` that swallowed the title as the glyph value.
- **`fb9cc53b`** — the "Update System" toast repeated on every login on a
  machine with nothing to update. Root cause was two first-run steps that fail
  on *every* machine (see "Unported assets"), which kept `fedory-first-run`
  from ever marking itself complete, so the whole sequence replayed each login.
  `wifi.sh` also never checked whether updates existed and had no once-marker.

## Verified versus written

Be careful with this distinction; several things are green in tests but have
never run for real.

| Change | Status |
|---|---|
| Optional install groups | **Verified on a real install.** 229 packages / 1.96 GiB, no leakage |
| Plymouth splash | **Verified installed.** Step completes in 22s, theme and `script.so` present. Never confirmed *rendering* |
| Package list split | **Verified lossless.** Union is byte-for-byte the pre-change set |
| Progress bars | Rendered and inspected by hand; never watched during a real install |
| GRUB theming | **Unverified.** Tests drive stubbed `grub2-mkconfig`/`grub2-mkfont`. No real `grub.cfg` regenerated, no menu rendered |
| RPM lock guard | **Unexercised.** Has not fired on any run; only unit tests cover it |
| First-run fixes | Tests pass; the loop has not been observed breaking on a live machine |

The Plymouth sequence is the cautionary tale: the theme copied fine and the
step still failed, on a missing package no test would have caught. Treat the
first real run of anything above as the actual test.

## GRUB theming — the part worth knowing

The blocker was not the theme. Fedora ships `GRUB_TERMINAL_OUTPUT="console"`,
which puts GRUB in text mode where **themes are not rendered at all**. A theme
installed without flipping that to `gfxterm` is a correct-looking change that
is completely invisible. That is the assertion `test/shell.d/grub-test.sh`
leans on.

Three other things that will bite anyone editing this:

- `/etc/default/grub` is **shared with the distribution** — `GRUB_CMDLINE_LINUX`
  there carries the kernel arguments the machine boots with. `set_grub_key`
  replaces or appends individual keys rather than templating the file.
- The generated `.pf2` font must live **inside the theme directory**.
  `/etc/grub.d/00_header` only emits `loadfont` for fonts it finds there;
  anywhere else and GRUB rejects the theme for naming a font it never loaded.
- The theme is **pixmap-free** on purpose. Sliced `*_c.png`/`*_w.png` sets are
  what make most GRUB themes brittle — a missing slice silently drops the
  widget that used it.

## Unported assets

A sweep of every `$FEDORY_PATH`/`$FEDORY_INSTALL` path referenced from scripts
found **ten** referenced-but-absent asset groups. Two of them were live bugs
(they are what kept first-run replaying). The rest are latent: the code path
that needs them has presumably not been exercised.

| Missing asset | Referenced by |
|---|---|
| `default/systemd/user/` (5 units) | `install/user/first-run/enable-user-units.sh` |
| `default/audio/tunings/` | `bin/fedory-audio-tuning` |
| `default/audio/filter-chain-host.conf` | `bin/fedory-audio-tuning` |
| `default/firefox/policies.json` | `bin/fedory-install-browser` |
| `default/voxtype/config.toml` | `bin/fedory-voxtype-install` |
| `default/fedory-skill` | `bin/fedory-finalize-user` |
| `default/plymouth/preview-unlock.png` | `bin/fedory-plymouth-switcher` |
| `default/systemd/system-sleep/force-igpu` | `bin/fedory-toggle-hybrid-gpu` |
| `default/systemd/system-sleep/keyboard-backlight` | `bin/fedory-hibernation-setup` |
| `default/systemd/system/supergfxd.service.d/delay-start.conf` | `bin/fedory-toggle-hybrid-gpu` |

The five user units are the consequential ones — **bluetooth pairing agent,
sleep lock, migration notifier, and fcitx5 input method are not running on any
Fedory install right now.** `enable-user-units.sh` currently reports their
absence instead of failing, which unblocked first-run but did not restore the
functionality.

They are tractable. Upstream has all of them at
`default/systemd/user/*.service` (clone `basecamp/omarchy`, ref `quattro`); all
three Fedory commands they need already exist in `bin/`; `bluez-tools` and
`fcitx5` are already installed; and `config/systemd/user/fedory-tablet-rotation.service`
establishes the pattern for referencing a source checkout:

```
ExecStart=/usr/bin/bash -lc 'exec "$FEDORY_PATH/bin/fedory-..."'
```

Note the rename and path work: `OMARCHY_PATH` → `FEDORY_PATH`,
`/usr/bin/omarchy-*` → the wrapper above, and
`ConditionPathIsDirectory=/usr/share/omarchy/migrations` needs rethinking since
Fedory runs from a checkout under `~/.local/share/fedory`.

To re-run the sweep, walk `git ls-files`, extract paths matching
`\$\{?(FEDORY_PATH|FEDORY_INSTALL)\}?/...`, and check each for existence
(remember `FEDORY_INSTALL` is `<root>/install`).

## Other open items

- **`glibc-all-langpacks` is 227 MiB, 7% of every install**, and nothing asks
  for it — it arrives as a dependency default. Replacing it with
  `glibc-langpack-en` is a straight win for an English-language system. Not a
  user-facing choice, so it does not belong in the group mechanism.
- **COPR 404s** for `gpu-screen-recorder` (`dec05eba/gpu-screen-recorder`) and
  `yaru-icon-theme` (`heliocastro/yaru`) — no `fedora-44` builds. Handled
  gracefully; upstream availability, not a Fedory bug.
- **Whether the welcome toast's newline renders as a line break** or is
  collapsed by the notification daemon. A real newline is unambiguously correct
  to send; if it still shows on one line, the daemon wants `<br/>`.

## Debugging a Fedory VM

This cost real time to work out, so it is written down.

The test VM is `fedora-clone` under `qemu:///system`
(`/data/vms/fedora-1-clone.qcow2`).

**The QEMU guest agent is heavily confined by SELinux.** `qemu-ga` runs as
`virt_qemu_ga_t`, so even as root it cannot read `/var/log/fedory-install.log`
(type `var_log_t`), `/home`, or `/etc/systemd/system`, and cannot drive
`systemctl` or `systemd-run`. Running as uid 0 is not a bypass — this is type
enforcement, and it is deliberate: a compromised host would otherwise get
unrestricted root inside every guest. It is fine for `uptime`, `/proc` reads,
and listing `/usr/share`.

**To read anything real, mount the disk read-only from the host:**

```
qemu-nbd --read-only --connect=/dev/nbd0 \
  --image-opts "driver=qcow2,file.driver=file,file.filename=$IMG,file.locking=off"
```

`file.locking=off` is required because the running QEMU holds an exclusive
lock; it is safe only in combination with `--read-only`. This build of
`qemu-nbd` has no `--force-share`. Mount with `norecovery`/`noload` so it does
not try to replay the journal of a filesystem mounted elsewhere.

**The partition layout is not obvious:**

- `/dev/nbd0p2` is **ext4 `/boot`** — this is where `grub2/grub.cfg` lives
- `/dev/nbd0p3` is **btrfs**, with separate `root` and `home` subvolumes.
  Mounting `subvol=root` gives an empty `/home`; use `subvolid=5` to see both

Caveat: the guest is running, so recent writes may still be in its page cache
and absent from the disk. In practice a few minutes of quiet is enough.

## Conventions worth preserving

- **Shared helpers live in `install/helpers/` and are sourced by leaves**
  (`package-lock.sh`, `plymouth.sh`, `groups.sh`). `bin/` commands resolve them
  script-relative *before* `FEDORY_PATH`, because `FEDORY_PATH` can legitimately
  point somewhere without a `helpers/` directory — the migration tests do
  exactly that.
- **A leaf drives its own progress bar just by printing `[n/m]` markers**;
  `fedory_task_progress` parses them out of stdout. At `n == total` the
  renderer switches to an animated bar with a running clock, which is how a
  silent long step (dracut) shows it is alive.
- **`run_logged` is deliberately non-fatal.** One failing leaf must not strand
  the user with no desktop. The consequence is that the visible error is
  usually a summary and the real cause is only in the log.
- **Test hosts lie.** Two tests here passed only because this machine happened
  to have something installed (`script.so`) or happened to have a UTF-8 locale.
  Both now pin the dependency to a file the test controls. A check whose
  outcome depends on the test host is not a test.
