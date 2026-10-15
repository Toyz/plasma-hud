# plasma-hud

My personal KDE Plasma 6 rice, themed after .hack's "The World": midnight glass, gold
trim, data cyan, Greek server glyphs, gate warps. It is built for my own machine
(CachyOS, Wayland, three monitors) and shared as-is.

> **This is a personal theme.** You are welcome to use it, fork it, or take pieces of it
> under the MIT license. I am not accepting contributions, and issues and pull requests
> will be looked at rarely, if ever.

## What is in it

- **Island bar** (`org.helba.plasmahud`): replaces the stock panel with docked, transparent
  islands. Left: the Root Town launcher and live workspace maps (click to warp, drag
  windows between areas, + to add, x to remove). Middle: the task strip. Right: the tray,
  a seconds-sweep clock and a CPU/GPU/memory pulse.
- **Root Town** (Meta): app launcher on the primary screen. Instant search ranked by use,
  pinned and frequent tabs, and launch-or-raise for apps that are already open.
- **Chaos Gate** (`org.helba.chaosgate`, Meta+Space): command palette. Warp between
  workspaces by their generated three-word area names, jump to windows, and run commands.
- **Gate warp**: a .hack gate-out / gate-in transition across every screen on each
  workspace switch.
- **Helba Gate** (`packages/helbagate`): KWin effect for window open, close and minimize.
  Windows assemble from data cells and drain away, in GLSL. It is the one small piece
  of JavaScript in the repo, because KWin only accepts third-party animation effects as
  scripts.
- **Switchers**: Alt+Tab is the party roster (`helba-roster`), a list of windows with a
  live view of the selected one. Meta+Tab is the gate ring (`helba-gatering`), with live
  windows turning on a ring around the Chaos Gate sigil.
- **Lock screen** (`packages/lockshell`): a serif clock over your wallpaper with the Chaos
  Gate sigil turning behind it; any key raises "The World" log-in plate. Plasma 6.7 loads
  lock screens from a shell package, so this is a lock-screen-only shell package that the
  screen locker picks up through `PLASMA_DEFAULT_SHELL`, set for KWin alone (the desktop
  shell is untouched). It applies from the next login.
- **Login screen** (`packages/sddm/helba-world`): SDDM theme with the gate sigil and "The
  World" plate (user diamonds, session, power). Install with `./installer.sh --sddm`
  (uses sudo; copies your screen 0 wallpaper in, since SDDM cannot read your home).
- **Splash** (`packages/lookandfeel`): while the session loads, the Chaos Gate draws itself in
  stage by stage under "The World", ending on the warp's midnight.
- **Logout screen**: "Leave The World?" over the turning sigil, with gold-trimmed plates
  for sleep, hibernate, restart, shut down, log out, lock and stay; a direct request
  (Shut down from a menu) shows its plate with a 30 s countdown ring.
- **Arrival**: the gate-in plays across every screen when you log in and when you unlock.
- **HUD popup and HUD Tiles** (`org.helba.hudtile`): telemetry cards (gauges, core matrix,
  load and net traces, processes, system, command deck), together in a popup or one per
  desktop widget.
- **HUD Shader Wall** (`org.helba.hudwall`): per-screen GLSL wallpaper effects driven by the
  image's own pixels. The default is Data Drain; others include chroma drift, depth, ink,
  pixel sort and growth. It can span all screens seamlessly and pauses when windows cover it.
- **Look**:
  - a Plasma desktop theme (`helba-hud`) for the stock popups (volume, network, bluetooth)
  - Helba World KDE color schemes, dark and light
  - Aurorae window frames, dark and light
  - a Kvantum widget style for menus, tooltips and controls

  - a GTK theme (`HelbaWorld`): Breeze with the same .hack trim for GTK 3 apps, Breeze
    Dark with Helba colors for GTK 2

  - icons (`HelbaWorld`): glass folders with a bronze rim and diamond emblems for every
    place, the trash and start-here; .hack tray icons (Wi-Fi, wired, VPN, volume,
    microphone, battery, Bluetooth, media, brightness, Night Light) that Plasma recolors
    from the scheme; every file type as a "data tablet" (glass page, bronze rim, category
    glyph, the type's short name); everything else comes from Papirus-Dark. App tray icons sent as pictures (Discord, Docker...) are
    tinted gold by the right island instead, since no icon theme can reach them

  Everything follows the KDE color scheme. Switch between Helba World and Helba World
  Light in System Settings and the whole rice flips.
- **hudprobe**: socket-activated telemetry daemon (top processes, load, IP, pacman state).
  It only samples while something is connected and exits when idle.

## Layout

```
Cargo.toml              workspace
crates/
  hudprobe/             telemetry daemon (one-shot probe + `serve` on a unix socket)
  hudsock/              Rust (cxx-qt) QML module org.helba.hud: ProbeSocket
  hudctl/               panel/wallpaper layout tool, edits Plasma's KConfig files directly
packages/
  org.helba.plasmahud/  island bar, launcher, HUD popup, warp (the shared QML lives here)
  org.helba.chaosgate/  Chaos Gate
  org.helba.hudtile/    HUD Tile desktop widget
  org.helba.hudwall/    shader wallpaper (shaders/build.sh -> .qsb)
  helba-hud/            Plasma desktop theme
  aurorae/              window frames
systemd/                hudprobe.socket / hudprobe.service user units
dev/                    generators (theme, color schemes, frames, Kvantum) and offscreen renderers
                        (switcher.sh / lock.sh / sddm.sh render the KWin switchers, lock
                        and login screens with mock data; gtk_preview.py renders GTK widgets)
installer.sh            the one entry point
```

## Install

Needs Plasma 6, Rust, Qt 6 shader tools (`qsb`), Python 3 and, for the widget style,
`kvantum`.

```sh
./installer.sh --dry-run    # show what the panel/wallpaper layout step would change
./installer.sh              # build, link, apply theme/colors/frames/style, lay out panels
./installer.sh --no-layout  # everything except touching panels and wallpapers
./installer.sh --restore    # put back the saved Plasma layout, color scheme, frames and style
./installer.sh --sddm       # install the login screen (sudo); --restore-sddm removes it
```

The layout step backs up your Plasma config to `~/.local/state/plasma-hud/` first, and so
does every look setting it changes. It is safe to re-run.

## License

MIT, see [LICENSE](LICENSE). The color schemes and Kvantum themes are generated on your
machine from Breeze's and Kvantum's own files (see `dev/scheme_gen.py` and
`dev/kvantum_gen.py`), so those outputs carry their sources' licenses and are not part of
this repository.
