# Tablet profile

Fedory's optional tablet profile adds touchscreen workspace gestures, larger
desktop text, automatic display and input-device rotation, and a Wayland
on-screen keyboard. Fedory offers the profile during first-run setup when it
detects both a touchscreen and either a tablet/convertible chassis or an
accelerometer.

## Setup

Enable, inspect, or disable the profile with:

```bash
fedory setup tablet enable
fedory setup tablet status
fedory setup tablet disable
```

The same actions are available under **Setup > Tablet Profile** in the Fedory
menu. Enabling the profile installs `iio-sensor-proxy`, builds a pinned wvkbd
revision from upstream source, enables its user services, increases the shared
text size to 16px, and enables touchscreen edge swipes. Building wvkbd requires
network access and installs its Fedora build dependencies through the normal
Fedory package helper.

Disabling the profile stops the keyboard and rotation services, removes the
Hyprland tablet settings, and restores the previous text size when it has not
been changed again by the user. Installed packages and the compiled keyboard
are intentionally retained.

## Rotation

The rotation service follows `monitor-sensor` orientation events. It rotates
the built-in `eDP`, `LVDS`, or `DSI` display and applies the same transform to
touch and pen devices so input remains aligned with the screen.

Use **Hardware > Automatic Rotation** to stop or start automatic rotation. The
rotation service only starts when Fedory detects an accelerometer.

## On-screen keyboard

The keyboard is 320px tall with touch-sized labels and normally appears when a
Wayland application activates a text field. Use **Hardware > On-screen
Keyboard** to disable or re-enable the keyboard service entirely.

On the ASUS ROG Flow Z13 GZ302EA, Fedory watches for the detachable keyboard's
USB ID (`0b05:1a30`):

- While the hardware keyboard is attached, the on-screen keyboard is
  suppressed, including for text fields focused with a mouse.
- Within about one second of detachment, automatic text-field behavior is
  enabled.
- Reattaching the hardware keyboard hides the on-screen keyboard again.

Other supported tablets use wvkbd's normal automatic text-field behavior.
Wayland's text-input protocol does not identify whether a field was focused by
touch or mouse, so device-aware suppression requires a known detachable
keyboard identifier.

Flatpak Chromium does not read the host `chromium-flags.conf` itself. Fedory's
Chromium launcher forwards the required Wayland IME flags while filtering host
extension paths that are not visible inside the Flatpak sandbox. Chromium must
be fully restarted after those flags are first installed.

## Troubleshooting

Start with:

```bash
fedory setup tablet status
systemctl --user status fedory-tablet-keyboard.service
systemctl --user status fedory-tablet-rotation.service
```

Status reports touchscreen and accelerometer detection, physical-keyboard
attachment state, both user services, and the current text size. If an
application does not summon the keyboard, confirm it is running natively on
Wayland and supports the Wayland text-input protocol. The Hardware menu can be
used to stop or start either tablet service without disabling the full profile.

Existing installations receive repaired service files and Chromium integration
through Fedory's migration system during `fedory update`.
