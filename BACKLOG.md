# Backlog

Ordered. Check things off as they land.

## Now
- [x] Minimized windows vanish from their screen's task strip (KWin marks them hidden; stop filtering hidden)
- [x] Floating islands bar, replacing the stock panel entirely:
  - left: HUD launcher button + workspace switcher
  - center: task strip with redesigned buttons (no per-icon frames)
  - right: plate wraps the stock tray + HUD clock + telemetry
  - island height adapts to the panel thickness
- [x] hudctl layout v2: remove kickoff/pager/clock/show-desktop/separator, place islands
- [x] Panels docked (no floating bounce when windows maximize)
- [x] Active-title expansion is opt-in (default off)
- [x] No panel blur / contrast / shadow (helba-hud desktop theme)
- [x] Chroma drift visible (bigger, faster hue swing on colored pixels only)

## Next
- [x] Launch-or-raise: Enter brings an already-running app forward (launcher + gate), Shift+Enter starts new
- [x] Search ranks by your usage (KActivities "popular"); new ↺ Frequent tab in Root Town
- [x] .hack gate warp on all screens for every workspace switch (gate, panel maps); gate veil spans all screens
- [x] Warp v2: sigil draw-in + keyword typing on the center screen, veil/white-out on all screens, ~3.5s
- [x] Data Drain: .hack wallpaper effect over the image (hudwall effect 1, the default); no gold specks;
      spans all screens seamlessly (shared seed + wall-clock time); pauses when windows cover ~90% of a screen
- [x] Add / remove workspaces: + slot and hover close mark (or middle-click) on the panel maps;
      Chaos Gate "Close this area" command and Shift+Del (twice) on an area row
- [x] Light / dark: System | Light | Dark switch (System follows the KDE color scheme live); light .hack
      palette (parchment, bronze, teal); theme SVGs recoloured from the scheme (dev/theme_gen.py);
      Helba World + Helba World Light KDE color schemes (dev/scheme_gen.py), applied by the installer
- [x] New areas warp you there once they have their keywords
- [x] Launcher search latency: apps match locally and instantly, KRunner results merge in as they land
- [x] HUD app launcher (start menu) on Plasma's kicker models; Meta key opens it
- [x] Islands without text readouts: pulse trace, seconds-sweep clock, workspace constellation
- [x] Workspace switcher: live window maps per desktop, drag windows between desktops
- [x] Launcher reworked as .hack "Root Town" menu; always opens on the primary screen
- [x] HUD popup cards as standalone desktop widgets: "HUD Tile" (org.helba.hudtile), one card each
      (telemetry, cores, load, net, processes, system, command deck); the popup is built from the same cards
- [x] .hack the helba-hud desktop theme (dialog/tooltip/heading/list/slider/switch/button/field/scrollbar
      SVGs + colors): stock popups (volume, network, bluetooth, notifications, calendar) now match
- [x] Chaos Gate (Meta+Space): command palette + workspace warp. Each workspace gets a generated
      three-word area name (e.g. "Δ Hidden Forbidden Holy Ground"); type keywords to warp, clean
      transition between workspaces; also runs commands/actions
- [x] .hack window frames: Aurorae themes helba-world + helba-world-light (dev/aurorae_gen.py): glass title
      band, bronze edge and seam, diamond studs, soft shadow, diamond buttons; the Chaos Gate swaps them with
      the color scheme
- [x] Pinned apps no longer blink out of the strip while launching
- [x] .hack right-click menus + app chrome: Helba World color schemes + Kvantum style (dev/kvantum_gen.py),
      menus with gold edge, studs and the cyan/bracket hover; works on the Wayland translucent path
- [x] Gate in / gate out window animations: KWin effect helbagate (packages/helbagate). Windows assemble
      from data cells on open / unminimize and drain away on close / minimize (toward their task tile);
      replaces Glide and Squash
- [x] Kvantum list items: .hack hover / press / selection, no white press flash; KDE apps translucent + blur
- [x] Alt+Tab party roster (helba-roster): member lines with diamond icon badges, cyan wash + gold
      brackets on the current one, live view of it; Meta+Tab gate ring (helba-gatering): live windows on
      a tilted ring around the Chaos Gate sigil
- [x] Lock screen (packages/lockshell, org.helba.lockshell): serif clock over the wallpaper with the
      turning sigil; any key raises "The World" log-in plate (avatar diamond, glass field, shake on
      failure). Loaded via PLASMA_DEFAULT_SHELL in KWin's unit only (Plasma 6.7 has no look-and-feel
      lock screens)
- [x] Login screen (SDDM, packages/sddm/helba-world): sigil + glass plate, user diamonds, session,
      power keycaps; `./installer.sh --sddm` installs it with screen 0's wallpaper (sudo)
- [x] Gate-in arrival on login (once per session) and on unlock (ScreenSaver.ActiveChanged)
- [x] Helba World for GTK (packages/gtk/HelbaWorld): Breeze + .hack trim for GTK 3 (gold-edged menus,
      popovers, tooltips; cyan wash + gold brackets on selection; gold tabs, checks, scrollbars),
      colors live from the KDE scheme; GTK 2 gets Breeze Dark with Helba colors; GTK 4 / libadwaita
      take the scheme colors through Plasma's gtkconfig
- [x] .hack icon theme v1 (packages/icons/HelbaWorld, dev/icons_gen.py): glass folders with a bronze rim,
      studs and a diamond emblem per place, trash, start-here; inherits Papirus-Dark for the rest
- [x] Icons v2: .hack tray / status icons (Wi-Fi, wired, VPN, volume, microphone, battery, Bluetooth,
      airplane mode), recolored live from the color scheme
- [ ] Icons v3: mimetypes

## After the backlog
- [x] .hack identity (The World) across the widget: bar islands, task buttons, launcher emblem, clock,
      pulse, HUD popup, task preview + menu (glitch / scanlines / chamfers removed)
- [x] .hack for what is left: Plasma theme popups, switchers, lock, login
- [x] Splash screen at login (packages/lookandfeel, org.helba.world via ksplashrc): the Chaos Gate draws in by stage
- [x] Logout / shutdown screen (org.helba.world logout): gold-trimmed plates for each way out, countdown ring on direct requests
- [x] Tray icons for media playback, brightness and Night Light (plus the media popup buttons)

## Pending outside this repo
- [x] muralist: hudwall-aware wallpaper setter (b395269); verified live on all three screens
