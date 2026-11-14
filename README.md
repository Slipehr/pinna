# Pinna

A small control panel for the Logitech PRO X 2 LIGHTSPEED headset on Linux with
PipeWire. It covers the features that Logitech's G HUB provides on Windows:
virtual surround, an equaliser, microphone noise suppression, sidetone, auto
power-off and battery level.

The name is the anatomical term for the outer ear, the part of hearing that
virtual surround models.

It is an independent project and is not affiliated with Logitech.

## Requirements

- PipeWire with WirePlumber 0.5 or newer (smart filters are used for the
  equaliser and the microphone filter)
- Python 3 with GTK 4 and libadwaita 1.4 or newer (`python3-gi`,
  `gir1.2-adw-1`), taken from the system
- `systemctl --user`, `pw-dump`, `pw-cli`, `pw-metadata`, `wpctl`
- `pkexec` for the one-time device permission

The AppImage bundles the helper binaries and data files, but not Python or GTK.
It was built and tested on Pop!_OS 24.04 with PipeWire 1.6.8.

## Running

```sh
./Pinna-x86_64.AppImage
```

The **About** button in the window's title bar and `./Pinna-x86_64.AppImage --version`
show which version you are running.

Settings take effect as you change them and stay in place after the app is
closed and after a reboot. The app only needs to keep running for the panel
icon.

Two command-line modes exist for scripting and debugging:

| Command | Effect |
|---|---|
| `--apply` | Re-apply the saved settings (rewrite config, start or stop the filter services) |
| `--print-conf` | Print the PipeWire filter modules the current settings generate |
| `--background` | Start hidden, with only the panel icon |

## Features

### Headset

| Control | Notes |
|---|---|
| Battery level | Shown in the title bar, refreshed every minute |
| Sidetone | 0 to 100. Hear your own voice in the headset |
| Auto power-off | Minutes of silence before the headset switches off. 0 means never |

These talk to the USB receiver, which is readable only by root by default.
Click **Grant access** once and enter your password. This installs a udev rule
(see [Files](#files-the-app-creates)) that gives the logged-in user access to
that one device.

### Panel icon

While Pinna is running, a tray icon in the panel shows the battery percentage
as a number on a coloured tile: green, amber at 30% or less, red at 15% or
less, blue while charging, grey when the headset is off. Its menu opens the
window or quits.

- Closing the window keeps Pinna running in the panel. Use **Quit** in the
  icon's menu to stop it.
- **Start at login** (shown when running from the AppImage) starts Pinna hidden
  at login, so the battery level is always in the panel.
- The icon needs a panel that supports StatusNotifierItem tray icons (COSMIC,
  KDE Plasma, and GNOME with the AppIndicator extension). Without one, Pinna
  behaves as a normal window and closing it quits.

### Sound

| Control | Notes |
|---|---|
| Virtual surround | A 7.1 output rendered for headphones |
| Surround profile | Which virtualiser the room and speakers are modelled on. The default, DTS Headphone:X, is the technology G HUB uses |
| Equaliser | Ten bands, ±12 dB, with presets. Applies to everything played on the headset |

Things to know about surround:

- While it is on, the surround output is pinned as the default output, because
  games only send 5.1 or 7.1 audio to a default device that has those channels.
  Turning it off removes the pin and the system picks the output again.
- Stereo music sounds different with surround on, since it is played through
  two virtual front speakers in a room. Surround is mainly useful for games and
  films with real multichannel audio.
- The profiles are captures of other virtualisers, not Logitech's own tuning
  for this headset.

The equaliser lowers the overall level by the size of the largest boost, so
boosted bands do not clip. Slider changes apply live without interrupting
playback.

### Microphone

| Control | Notes |
|---|---|
| Noise suppression | Removes keyboard, fan and background noise using RNNoise |
| Strength | Voice-detection threshold. Higher cuts more noise but may clip quiet speech |

Apps that record from the headset microphone get the filtered signal
automatically. The default input device is not changed.

## How it works

Each sound or microphone effect is a PipeWire filter-chain, run by its own
small `pipewire` process under a systemd user service:

| Service | Filter |
|---|---|
| `pinna-filter@eq.service` | Equaliser |
| `pinna-filter@surround.service` | Virtual surround |
| `pinna-filter@mic.service` | Noise suppression |

Running them separately means toggling one filter never restarts another, and
none of them restart the main PipeWire daemon, so games and apps keep their
audio connection.

- **Equaliser and microphone filter** are WirePlumber smart filters targeted at
  the headset. WirePlumber inserts them into any stream that goes to or from
  the headset, without changing the default device. If the headset is not
  connected they are simply unused.
- **Surround** is a regular 8-channel virtual output that convolves each
  speaker channel with a 14-channel HeSuVi impulse response. Its output goes to
  the headset, passing through the equaliser if that is on. Before the surround
  output is removed, playing streams are moved back to the headset; removing an
  output that a browser is still playing into makes it stop playback.
- **Sidetone, auto power-off and battery** are sent with the bundled
  [HeadsetControl](https://github.com/Sapd/HeadsetControl) binary.

The headset's PipeWire device names are saved the first time it is seen, so
settings can still be changed while it is switched off.

## Files the app creates

| Path | Purpose |
|---|---|
| `~/.config/pinna/settings.json` | Saved settings |
| `~/.config/pipewire/pinna-<filter>.conf` | Generated config for each enabled filter |
| `~/.config/systemd/user/pinna-filter@.service` | Service template for the filters |
| `~/.config/autostart/pinna.desktop` | Created by **Start at login**; points at the AppImage's current location |
| `~/.local/share/pinna/` | Copies of the RNNoise plugin and surround profiles, at a path that stays valid after the AppImage closes |
| `/etc/udev/rules.d/70-pinna.rules` | Device permission, created by **Grant access** |

## Building

```sh
./build.sh
```

This needs `mksquashfs` (package `squashfs-tools`) and `python3`. It assembles
`build/AppDir` and writes `Pinna-x86_64.AppImage`. Rebuilding while the
app is open is fine; restart the app to use the new build.

The build expects these downloads under `vendor/`. They are not fetched by the
script:

| Folder | Contents | Source |
|---|---|---|
| `vendor/headsetcontrol-appimage/squashfs-root/` | Unpacked HeadsetControl 4.2.0 AppImage (binary plus its HID libraries) | <https://github.com/Sapd/HeadsetControl/releases> |
| `vendor/rnnoise/linux-rnnoise/` | RNNoise LADSPA plugin 1.10 | <https://github.com/werman/noise-suppression-for-voice/releases> |
| `vendor/hesuvi/extracted/HeSuVi/hrir/` | Surround impulse responses, unpacked from the HeSuVi installer with `7z x` | <https://sourceforge.net/projects/hesuvi/> |
| `vendor/appimagetool/` | appimagetool 1.9.1; only the AppImage runtime at the front of the file is reused, the tool itself is not run | <https://github.com/AppImage/appimagetool/releases> |

To run from source without building: `python3 pinna.py`.

## Troubleshooting

| Symptom | Check |
|---|---|
| Sidetone and power-off are greyed out | Click **Grant access**. If the row says the receiver was not found, the USB dongle is not plugged in |
| "Receiver found, headset is off or not responding" | Switch the headset on; the status refreshes within a minute |
| A filter does not come on | `systemctl --user status pinna-filter@surround` (or `eq`, `mic`) and `journalctl --user -u 'pinna-filter@*'` |
| Sound still goes to the surround output after turning it off | Run `./Pinna-x86_64.AppImage --apply` |
| Other headset or renamed device | The app looks for PipeWire nodes starting with `alsa_output.usb-Logitech_PRO_X_2` and USB ID `046d:0af7`; both are constants at the top of `pinna.py` |

## Removing

Turn all three filters off in the app first, then:

```sh
systemctl --user disable --now 'pinna-filter@eq' 'pinna-filter@surround' 'pinna-filter@mic'
rm ~/.config/systemd/user/pinna-filter@.service
rm ~/.config/pipewire/pinna-*.conf
rm -r ~/.config/pinna ~/.local/share/pinna
rm -f ~/.config/autostart/pinna.desktop
sudo rm /etc/udev/rules.d/70-pinna.rules
systemctl --user daemon-reload
```

## License

Pinna's own code (`pinna.py`, `build.sh`, the icon and this
documentation) is licensed under the
[PolyForm Noncommercial License 1.0.0](LICENSE). You may use, modify and share
it for any noncommercial purpose. Commercial use is not permitted.

Required Notice: Copyright 2026 Slipehr

This license does not cover the bundled third-party components listed below.
They keep their own licenses, which in the case of the GPL-3.0 components do
allow commercial use of those components themselves.

## Third-party components

| Component | License |
|---|---|
| [HeadsetControl](https://github.com/Sapd/HeadsetControl) 4.2.0 | GPL-3.0 |
| [noise-suppression-for-voice](https://github.com/werman/noise-suppression-for-voice) 1.10 (RNNoise plugin) | GPL-3.0 |
| [hidapi](https://github.com/libusb/hidapi), shipped with HeadsetControl | GPL-3.0, BSD-3-clause or HIDAPI license |
| [libudev](https://github.com/systemd/systemd), shipped with HeadsetControl | LGPL-2.1-or-later |
| [HeSuVi](https://sourceforge.net/projects/hesuvi/) impulse responses | See that project |
| [AppImage type 2 runtime](https://github.com/AppImage/type2-runtime) | See that project |

All of these are unmodified upstream releases. The full GPL-3.0 text and a
notice listing each component with its source are in
[third-party-licenses/](third-party-licenses/), and are also included inside
the AppImage under `usr/share/pinna/third-party-licenses/`.

Product names such as DTS Headphone:X, Dolby Atmos, GSX and SBX are trademarks
of their owners and are used here only to describe which virtualiser a profile
was captured from.
