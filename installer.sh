#!/bin/sh
# plasma-hud installer.
#
#   ./installer.sh              build, link packages, enable units, apply the panel/wallpaper layout
#   ./installer.sh --no-layout  everything except touching panels and wallpapers
#   ./installer.sh --dry-run    print what the layout step would change, change nothing
#   ./installer.sh --sddm       install the Helba World login screen (asks for sudo)
#   ./installer.sh --restore-sddm
#                               go back to the previous login screen (asks for sudo)
#   ./installer.sh --restore [DIR]
#                               put back the Plasma config saved before the last layout run
#                               (or DIR from ~/.local/state/plasma-hud/)
#
# Layout and restore are done by hudctl (crates/hudctl), which edits Plasma's config
# files directly while plasmashell is stopped, then starts it again.
set -eu

root=$(cd "$(dirname "$0")" && pwd)
data="${XDG_DATA_HOME:-$HOME/.local/share}"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/plasma-hud"
hud_pkg="$root/packages/org.helba.plasmahud"
hudctl="$root/target/release/hudctl"

say() { printf '\033[36m::\033[0m %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------------ build

build() {
    say "building crates"
    cargo build --release --workspace --manifest-path "$root/Cargo.toml"
    install -Dm755 "$root/target/release/hudprobe" "$hud_pkg/contents/bin/hudprobe"

    mod="$hud_pkg/contents/lib/org/helba/hud"
    mkdir -p "$mod"
    install -m755 "$root/target/release/liborg_helba_hud.so" "$mod/"
    install -m644 "$root/target/cxxqt/qml_modules/org/helba/hud/qmldir" \
                  "$root/target/cxxqt/qml_modules/org/helba/hud/plugin.qmltypes" "$mod/"

    # The ui qmldir must list every component (a qmldir makes Qt export only what it lists).
    ui="$hud_pkg/contents/ui"
    for f in "$ui"/*.qml; do
        n=$(basename "$f" .qml)
        case "$n" in main|configGeneral) continue ;; esac
        grep -qE "^(singleton )?$n [0-9]" "$ui/qmldir" || die "$n.qml is missing from $ui/qmldir"
    done

    say "compiling shaders"
    "$root/packages/org.helba.hudwall/contents/shaders/build.sh"
}

# ------------------------------------------------------------------ packages

# Where Plasma looks for each KPackage structure.
package_dir() {
    case "$1" in
        Plasma/Applet) echo "$data/plasma/plasmoids" ;;
        Plasma/Wallpaper) echo "$data/plasma/wallpapers" ;;
        Plasma/LookAndFeel) echo "$data/plasma/look-and-feel" ;;
        Plasma/Theme) echo "$data/plasma/desktoptheme" ;;
        KWin/Effect) echo "$data/kwin/effects" ;;
        KWin/WindowSwitcher) echo "$data/kwin/tabbox" ;;
        Plasma/Shell) echo "$data/plasma/shells" ;;
        *) return 1 ;;
    esac
}

json_field() { # $1 = file, $2 = field name (first match)
    sed -n "s/.*\"$2\": *\"\([^\"]*\)\".*/\1/p" "$1" | head -n1
}

# The HUD desktop theme ships The World's frames (popups, lists, sliders, buttons,
# fields, switches, panels), painted from the active KDE color scheme; anything it
# lacks comes from the theme that was active before it.
prepare_theme() {
    theme="$root/packages/helba-hud"
    current=$(kreadconfig6 --file plasmarc --group Theme --key name 2>/dev/null || true)
    [ -n "$current" ] && [ "$current" != helba-hud ] || current=$(sed -n 's/^FallbackTheme=//p' "$theme/plasmarc" 2>/dev/null || true)
    [ -n "$current" ] || current=default
    sed "s/@FALLBACK@/$current/" "$theme/plasmarc.in" | grep -v '^#' > "$theme/plasmarc"
    say "HUD theme falls back to $current"
}

apply_theme() {
    plasma-apply-desktoptheme helba-hud >/dev/null && say "desktop theme: helba-hud (no panel background, blur or shadow)"
}

# Helba World color schemes (dark and light). The desktop theme and the HUD widgets
# follow whichever KDE color scheme is active, so switching between the two in System
# Settings > Colors flips the whole rice. First install picks the one matching the
# current scheme's brightness and remembers the old scheme for --restore.
link_schemes() {
    mkdir -p "$data/color-schemes"
    for f in "$root"/packages/color-schemes/*.colors; do
        ln -sfn "$f" "$data/color-schemes/$(basename "$f")"
    done
    say "linked Helba World color schemes"
}

apply_scheme() {
    current=$(kreadconfig6 --group General --key ColorScheme 2>/dev/null || true)
    case "$current" in HelbaWorld*) say "color scheme: $current (kept)"; return ;; esac
    mkdir -p "$state"
    [ -n "$current" ] && printf '%s\n' "$current" > "$state/colorscheme.before"
    bg=$(kreadconfig6 --group Colors:Window --key BackgroundNormal 2>/dev/null || true)
    scheme=HelbaWorld
    if [ -n "$bg" ] && [ "$(echo "$bg" | awk -F, '{ print ($1 + $2 + $3) / 3 > 127 }')" = 1 ]; then
        scheme=HelbaWorldLight
    fi
    plasma-apply-colorscheme "$scheme" >/dev/null && say "color scheme: $scheme (was ${current:-unset})"
}

# Helba World window frames (Aurorae, dark and light). The Chaos Gate widget swaps
# between the two as the color scheme flips, as long as one of them is in use.
link_frames() {
    mkdir -p "$data/aurorae/themes"
    for d in "$root"/packages/aurorae/*/; do
        d=${d%/}
        ln -sfn "$d" "$data/aurorae/themes/$(basename "$d")"
    done
    say "linked Helba World window frames"
}

apply_frames() {
    lib=$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library 2>/dev/null || true)
    theme=$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme 2>/dev/null || true)
    case "$theme" in __aurorae__svg__helba-world*) say "window frames: $theme (kept)"; return ;; esac
    mkdir -p "$state"
    printf '%s\n%s\n' "$lib" "$theme" > "$state/decoration.before"
    want=__aurorae__svg__helba-world
    case "$(kreadconfig6 --group General --key ColorScheme 2>/dev/null)" in *Light*) want=$want-light ;; esac
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae.v2
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "$want"
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    say "window frames: $want (was ${theme:-default})"
}

restore_frames() {
    [ -f "$state/decoration.before" ] || return 0
    lib=$(sed -n 1p "$state/decoration.before")
    theme=$(sed -n 2p "$state/decoration.before")
    if [ -n "$lib" ]; then
        kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library "$lib"
    else
        kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library --delete
    fi
    if [ -n "$theme" ]; then
        kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "$theme"
    else
        kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme --delete
    fi
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    say "window frames: ${theme:-default} (restored)"
}

# Color schemes and Kvantum themes are generated locally from Breeze's and Kvantum's
# own files (their licenses, not this repo's), so they are not shipped in git.
generate() {
    python3 "$root/dev/scheme_gen.py" "$root/packages/color-schemes" >/dev/null
    if [ -d /usr/share/Kvantum/KvFlat ]; then
        python3 "$root/dev/kvantum_gen.py" "$root/packages/kvantum" >/dev/null
        say "generated Helba World color schemes and Kvantum themes"
    else
        say "generated Helba World color schemes (install kvantum for the widget style)"
    fi
}

# Helba World Kvantum widget style (menus, tooltips, controls), dark and light.
link_kvantum() {
    [ -d "$root/packages/kvantum" ] || return 0
    mkdir -p "$config/Kvantum"
    for d in "$root"/packages/kvantum/*/; do
        d=${d%/}
        ln -sfn "$d" "$config/Kvantum/$(basename "$d")"
    done
    say "linked Helba World Kvantum themes"
}

apply_kvantum() {
    [ -d "$root/packages/kvantum" ] || return 0
    style=$(kreadconfig6 --group KDE --key widgetStyle 2>/dev/null || true)
    kv=$(kreadconfig6 --file "$config/Kvantum/kvantum.kvconfig" --group General --key theme 2>/dev/null || true)
    case "$kv" in HelbaWorld*) ;; *)
        mkdir -p "$state"
        printf '%s\n%s\n' "$style" "$kv" > "$state/widgetstyle.before" ;;
    esac
    want=HelbaWorld
    case "$(kreadconfig6 --group General --key ColorScheme 2>/dev/null)" in *Light*) want=HelbaWorldLight ;; esac
    kwriteconfig6 --file "$config/Kvantum/kvantum.kvconfig" --group General --key theme "$want"
    kwriteconfig6 --group KDE --key widgetStyle kvantum
    say "widget style: kvantum / $want (was ${style:-default}); restart apps to see it"
}

restore_kvantum() {
    [ -f "$state/widgetstyle.before" ] || return 0
    style=$(sed -n 1p "$state/widgetstyle.before")
    kv=$(sed -n 2p "$state/widgetstyle.before")
    kwriteconfig6 --group KDE --key widgetStyle "${style:-Breeze}"
    if [ -n "$kv" ]; then
        kwriteconfig6 --file "$config/Kvantum/kvantum.kvconfig" --group General --key theme "$kv"
    fi
    say "widget style: ${style:-Breeze} (restored)"
}

# Helba Gate (window open / close / minimize): replaces Glide and Squash. Slide goes
# too: the gate warp is the desktop-switch transition, and Slide painted the panels over
# it while switching.
effect_keys="glideEnabled scaleEnabled fadeEnabled squashEnabled magiclampEnabled slideEnabled helbagateEnabled"

apply_gate() {
    if [ "$(kreadconfig6 --file kwinrc --group Plugins --key helbagateEnabled 2>/dev/null)" != true ]; then
        mkdir -p "$state"
        : > "$state/effects.before"
        for k in $effect_keys; do
            printf '%s=%s\n' "$k" "$(kreadconfig6 --file kwinrc --group Plugins --key "$k" 2>/dev/null)" >> "$state/effects.before"
        done
    fi
    for k in glideEnabled scaleEnabled fadeEnabled squashEnabled magiclampEnabled slideEnabled; do
        kwriteconfig6 --file kwinrc --group Plugins --key "$k" false
    done
    kwriteconfig6 --file kwinrc --group Plugins --key helbagateEnabled true
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    say "window animations: Helba Gate (Glide / Squash / Slide off)"
}

restore_gate() {
    [ -f "$state/effects.before" ] || return 0
    while IFS='=' read -r k v; do
        if [ -n "$v" ]; then
            kwriteconfig6 --file kwinrc --group Plugins --key "$k" "$v"
        else
            kwriteconfig6 --file kwinrc --group Plugins --key "$k" --delete
        fi
    done < "$state/effects.before"
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    say "window animations: restored"
}

# Window switchers: Alt+Tab is the party roster, Meta+Tab the gate ring (KWin's
# "alternative" switcher). Shortcuts are set live through kglobalaccel; key codes are
# Qt's: Meta+Tab = 0x10000000 + 0x01000001, Meta+Shift+Backtab adds Shift + Backtab.
kga() { busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel "$@"; }

apply_switchers() {
    if [ "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName 2>/dev/null)" != helba-roster ]; then
        mkdir -p "$state"
        printf '%s\n%s\n' "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName 2>/dev/null)" \
            "$(kreadconfig6 --file kwinrc --group TabBoxAlternative --key LayoutName 2>/dev/null)" > "$state/switchers.before"
    fi
    kwriteconfig6 --file kwinrc --group TabBox --key LayoutName helba-roster
    kwriteconfig6 --file kwinrc --group TabBoxAlternative --key LayoutName helba-gatering
    a="Walk Through Windows Alternative"
    kga setForeignShortcutKeys 'asa(ai)' 4 kwin "$a" KWin "$a" 1 4 285212673 0 0 0 >/dev/null || true
    kga setForeignShortcutKeys 'asa(ai)' 4 kwin "$a (Reverse)" KWin "$a (Reverse)" 1 4 318767106 0 0 0 >/dev/null || true
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    say "switchers: Alt+Tab party roster, Meta+Tab gate ring"
}

restore_switchers() {
    [ -f "$state/switchers.before" ] || return 0
    main=$(sed -n 1p "$state/switchers.before")
    alt=$(sed -n 2p "$state/switchers.before")
    kwriteconfig6 --file kwinrc --group TabBox --key LayoutName "${main:-thumbnail_grid}"
    if [ -n "$alt" ]; then
        kwriteconfig6 --file kwinrc --group TabBoxAlternative --key LayoutName "$alt"
    else
        kwriteconfig6 --file kwinrc --group TabBoxAlternative --key LayoutName --delete
    fi
    a="Walk Through Windows Alternative"
    kga setForeignShortcutKeys 'asa(ai)' 4 kwin "$a" KWin "$a" 0 >/dev/null || true
    kga setForeignShortcutKeys 'asa(ai)' 4 kwin "$a (Reverse)" KWin "$a (Reverse)" 0 >/dev/null || true
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    say "switchers: restored"
}

# Lock screen. Plasma 6.7 loads the lock screen from a shell package: plasmashellrc
# [Shell] ShellPackage, else $PLASMA_DEFAULT_SHELL, else org.kde.plasma.desktop. That
# key also picks the desktop shell, so instead the variable is set for KWin only (the
# greeter is KWin's child and inherits it); plasmashell, its own unit, never sees it.
# Takes effect at the next login. If our QML ever failed the greeter would fall back to
# its built-in locker, so this cannot lock you out.
kwin_dropin="$config/systemd/user/plasma-kwin_wayland.service.d/helba-lockscreen.conf"

apply_lockscreen() {
    mkdir -p "$(dirname "$kwin_dropin")"
    cat > "$kwin_dropin" <<UNIT
# plasma-hud: the screen locker loads its UI from this shell package (lock screen only).
[Service]
Environment=PLASMA_DEFAULT_SHELL=org.helba.lockshell
UNIT
    systemctl --user daemon-reload
    say "lock screen: Helba World from the next login (KWin drop-in)"
}

restore_lockscreen() {
    [ -f "$kwin_dropin" ] || return 0
    rm -f "$kwin_dropin"
    systemctl --user daemon-reload
    say "lock screen: Plasma default from the next login"
}

# Login screen (SDDM). It runs as the sddm user and cannot read your home, so the
# theme is copied to /usr/share/sddm/themes with screen 0's wallpaper as its
# background, light or dark to match the current color scheme. Needs root.
sddm_dest=/usr/share/sddm/themes/helba-world
sddm_conf=/etc/sddm.conf.d/helba-world.conf

install_sddm() {
    ensure_hudctl
    tmp=$(mktemp -d)
    cp -r "$root/packages/sddm/helba-world/." "$tmp/"
    img=$("$hudctl" wallpaper 0 2>/dev/null || true)
    if [ -n "$img" ] && [ -f "$img" ]; then
        ext=${img##*.}
        cp "$img" "$tmp/background.$ext"
        sed -i "s|^background=.*|background=background.$ext|" "$tmp/theme.conf"
        say "login background: $img"
    else
        sed -i "s|^background=.*|background=|" "$tmp/theme.conf"
        say "login background: none found, using the glass color"
    fi
    case "$(kreadconfig6 --group General --key ColorScheme 2>/dev/null)" in
        *Light*) sed -i "s|^light=.*|light=1|" "$tmp/theme.conf" ;;
    esac
    say "installing $sddm_dest and $sddm_conf (sudo)"
    sudo install -d -m 755 "$sddm_dest" /etc/sddm.conf.d
    sudo cp -r "$tmp/." "$sddm_dest/"
    sudo chmod -R a+rX "$sddm_dest"
    printf '# plasma-hud: Helba World login screen\n[Theme]\nCurrent=helba-world\n' | sudo tee "$sddm_conf" >/dev/null
    rm -rf "$tmp"
    say "login screen: Helba World (shows at the next login)"
}

restore_sddm() {
    say "removing $sddm_conf and $sddm_dest (sudo)"
    sudo rm -f "$sddm_conf"
    sudo rm -rf "$sddm_dest"
    say "login screen: back to the system default"
}

# GTK apps: the HelbaWorld GTK theme is Breeze plus .hack trim, colored from the KDE
# scheme (Plasma's gtkconfig writes it into ~/.config/gtk-3.0/colors.css). Applied
# through gtkconfig so GTK 3, GTK 2 and xsettings all switch together.
gtkconfig() { qdbus6 org.kde.kded6 /modules/gtkconfig "org.kde.GtkConfig.$@"; }

link_gtk() {
    mkdir -p "$data/themes"
    ln -sfn "$root/packages/gtk/HelbaWorld" "$data/themes/HelbaWorld"
    say "linked HelbaWorld GTK theme"
}

apply_gtk() {
    current=$(gtkconfig gtkTheme 2>/dev/null || true)
    [ "$current" = HelbaWorld ] && { say "GTK theme: HelbaWorld (kept)"; return; }
    mkdir -p "$state"
    printf '%s\n' "$current" > "$state/gtktheme.before"
    gtkconfig setGtkTheme HelbaWorld >/dev/null 2>&1 || true
    say "GTK theme: HelbaWorld (was ${current:-unknown}); reopen GTK apps to see it"
}

restore_gtk() {
    [ -f "$state/gtktheme.before" ] || return 0
    prev=$(cat "$state/gtktheme.before")
    gtkconfig setGtkTheme "${prev:-Breeze}" >/dev/null 2>&1 || true
    say "GTK theme: ${prev:-Breeze} (restored)"
}

# Icons: HelbaWorld is a curated .hack set (folders, places, trash, start-here) that
# inherits the rest from Papirus-Dark / breeze-dark. Generated by dev/icons_gen.py.
link_icons() {
    mkdir -p "$data/icons"
    ln -sfn "$root/packages/icons/HelbaWorld" "$data/icons/HelbaWorld"
    say "linked HelbaWorld icons"
}

apply_icons() {
    current=$(kreadconfig6 --group Icons --key Theme 2>/dev/null || true)
    [ "$current" = HelbaWorld ] && { say "icons: HelbaWorld (kept)"; return; }
    mkdir -p "$state"
    printf '%s\n' "$current" > "$state/icons.before"
    /usr/lib/plasma-changeicons HelbaWorld >/dev/null 2>&1 || kwriteconfig6 --group Icons --key Theme HelbaWorld
    say "icons: HelbaWorld (was ${current:-default})"
}

restore_icons() {
    [ -f "$state/icons.before" ] || return 0
    prev=$(cat "$state/icons.before")
    /usr/lib/plasma-changeicons "${prev:-breeze-dark}" >/dev/null 2>&1 || true
    say "icons: ${prev:-breeze-dark} (restored)"
}

# Login splash: packages/lookandfeel is a look-and-feel package (org.helba.world) that only
# carries the splash; ksplashrc picks it, so the global theme stays as it is.
apply_splash() {
    current=$(kreadconfig6 --file ksplashrc --group KSplash --key Theme 2>/dev/null || true)
    [ "$current" = org.helba.world ] && { say "splash: Helba World (kept)"; return; }
    mkdir -p "$state"
    if [ -f "$config/ksplashrc" ]; then cp "$config/ksplashrc" "$state/ksplashrc.before"; else : > "$state/ksplashrc.before"; fi
    kwriteconfig6 --file ksplashrc --group KSplash --key Engine KSplashQML
    kwriteconfig6 --file ksplashrc --group KSplash --key Theme org.helba.world
    say "splash: Helba World (was ${current:-the global theme's})"
}

# Logout screen: ksmserver-logout-greeter only reads the global theme key, so it
# points at org.helba.world (splash + logout only). Nothing else reads that key
# outside the Global Theme settings page, where re-applying a theme sets it again.
apply_logout() {
    current=$(kreadconfig6 --group KDE --key LookAndFeelPackage 2>/dev/null || true)
    [ "$current" = org.helba.world ] && { say "logout screen: Helba World (kept)"; return; }
    mkdir -p "$state"
    printf '%s\n' "$current" > "$state/lookandfeel.before"
    kwriteconfig6 --group KDE --key LookAndFeelPackage org.helba.world
    say "logout screen: Helba World (global theme key was ${current:-default})"
}

restore_logout() {
    [ -f "$state/lookandfeel.before" ] || return 0
    prev=$(cat "$state/lookandfeel.before")
    if [ -n "$prev" ]; then kwriteconfig6 --group KDE --key LookAndFeelPackage "$prev"; else kwriteconfig6 --group KDE --key LookAndFeelPackage --delete; fi
    say "logout screen: ${prev:-default} (restored)"
}

# Cursors: HelbaWorld-cursors (dev/cursors_gen.py). The scalable SVGs are committed;
# the Xcursor files for X11 / XWayland apps are rendered here with rsvg-convert.
link_cursors() {
    if command -v rsvg-convert >/dev/null 2>&1; then
        python3 "$root/dev/cursors_gen.py" "$root/packages/cursors/HelbaWorld-cursors" --xcursor >/dev/null
    else
        say "cursors: rsvg-convert missing, X11 apps keep their cursor (scalable set only)"
    fi
    mkdir -p "$data/icons"
    ln -sfn "$root/packages/cursors/HelbaWorld-cursors" "$data/icons/HelbaWorld-cursors"
    say "linked HelbaWorld-cursors"
}

apply_cursors() {
    current=$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme 2>/dev/null || true)
    [ "$current" = HelbaWorld-cursors ] && { say "cursors: HelbaWorld-cursors (kept)"; return; }
    mkdir -p "$state"
    printf '%s\n' "$current" > "$state/cursors.before"
    plasma-apply-cursortheme HelbaWorld-cursors >/dev/null 2>&1 || kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme HelbaWorld-cursors
    say "cursors: HelbaWorld-cursors (was ${current:-breeze_cursors})"
}

restore_cursors() {
    [ -f "$state/cursors.before" ] || return 0
    prev=$(cat "$state/cursors.before")
    plasma-apply-cursortheme "${prev:-breeze_cursors}" >/dev/null 2>&1 || true
    say "cursors: ${prev:-breeze_cursors} (restored)"
}

# Alacritty: Helba World colors through an import (dev/alacritty_setup.py drops the
# inline color tables and adds the import; the rest of the config is kept). The
# imported file is a link to the dark or light theme; the Chaos Gate flips it.
apply_alacritty() {
    command -v alacritty >/dev/null 2>&1 || return 0
    conf="$config/alacritty/alacritty.toml"
    mkdir -p "$config/alacritty" "$state"
    [ -f "$conf" ] && [ ! -f "$state/alacritty.toml.before" ] && cp "$conf" "$state/alacritty.toml.before"
    variant=helba-world
    case "$(kreadconfig6 --group General --key ColorScheme 2>/dev/null)" in *Light*) variant=helba-world-light ;; esac
    ln -sfn "$root/packages/alacritty/$variant.toml" "$config/alacritty/helba-world.toml"
    python3 "$root/dev/alacritty_setup.py" "$conf" >/dev/null
    say "alacritty: Helba World colors ($variant)"
}

restore_alacritty() {
    [ -f "$state/alacritty.toml.before" ] || return 0
    cp "$state/alacritty.toml.before" "$config/alacritty/alacritty.toml"
    rm -f "$config/alacritty/helba-world.toml"
    say "alacritty: previous config restored"
}

# fastfetch: the Helba World readout (gate sigil + short system list). The config is
# linked into ~/.config/fastfetch; the fish greeting's fastfetch call is pointed at it.
apply_fastfetch() {
    command -v fastfetch >/dev/null 2>&1 || return 0
    mkdir -p "$config/fastfetch" "$state"
    ln -sfn "$root/packages/fastfetch/helba-world.jsonc" "$config/fastfetch/helba-world.jsonc"
    ln -sfn "$root/packages/fastfetch/helba-world.txt" "$config/fastfetch/helba-world.txt"
    fish="$config/fish/config.fish"
    if [ -f "$fish" ]; then
        [ -f "$state/config.fish.before" ] || cp "$fish" "$state/config.fish.before"
        python3 - "$fish" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
call = "fastfetch -c helba-world"
if re.search(r"^\s*fastfetch\b", s, re.M):
    s = re.sub(r"^(\s*)fastfetch\b.*$", lambda m: m.group(1) + call, s, flags=re.M)
else:
    s = s.rstrip("\n") + "\n\nfunction fish_greeting\n    " + call + "\nend\n"
open(p, "w").write(s)
PY
    fi
    say "fastfetch: Helba World readout"
}

restore_fastfetch() {
    [ -f "$state/config.fish.before" ] && cp "$state/config.fish.before" "$config/fish/config.fish"
    rm -f "$config/fastfetch/helba-world.jsonc" "$config/fastfetch/helba-world.txt"
    say "fastfetch: previous greeting restored"
}

restore_splash() {
    [ -f "$state/ksplashrc.before" ] || return 0
    if [ -s "$state/ksplashrc.before" ]; then cp "$state/ksplashrc.before" "$config/ksplashrc"; else rm -f "$config/ksplashrc"; fi
    say "splash: restored"
}

restore_scheme() {
    [ -f "$state/colorscheme.before" ] || return 0
    plasma-apply-colorscheme "$(cat "$state/colorscheme.before")" >/dev/null \
        && say "color scheme: $(cat "$state/colorscheme.before") (restored)"
}

link_packages() {
    for pkg in "$root"/packages/*/; do
        pkg=${pkg%/}
        meta="$pkg/metadata.json"
        [ -f "$meta" ] || continue
        id=$(json_field "$meta" Id)
        kind=$(json_field "$meta" KPackageStructure)
        dir=$(package_dir "$kind") || die "$id: unknown package type $kind"
        dest="$dir/$id"
        mkdir -p "$dir"
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            die "refusing to replace non-symlink $dest"
        fi
        ln -sfn "$pkg" "$dest"
        say "linked $kind $id"
    done
}

# ------------------------------------------------------------------ units

units() {
    dir="$config/systemd/user"
    mkdir -p "$dir"
    install -m644 "$root"/systemd/*.socket "$root"/systemd/*.service "$dir/"
    systemctl --user daemon-reload
    for s in "$root"/systemd/*.socket; do
        systemctl --user enable --now "$(basename "$s")"
    done
    # A running daemon keeps the old binary; the next connection starts the new one.
    systemctl --user stop hudprobe.service 2>/dev/null || true
    say "hudprobe.socket listening at ${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hudprobe.sock"
}

# ------------------------------------------------------------------ main

ensure_hudctl() {
    [ -x "$hudctl" ] || cargo build --release -p hudctl --manifest-path "$root/Cargo.toml"
}

case "${1:-}" in
    --dry-run)
        ensure_hudctl
        "$hudctl" layout --dry-run
        ;;
    --sddm)
        install_sddm
        ;;
    --restore-sddm)
        restore_sddm
        ;;
    --restore)
        ensure_hudctl
        if [ -n "${2:-}" ]; then "$hudctl" restore "$2"; else "$hudctl" restore; fi
        restore_scheme
        restore_frames
        restore_kvantum
        restore_gate
        restore_switchers
        restore_lockscreen
        restore_gtk
        restore_icons
        restore_splash
        restore_cursors
        restore_alacritty
        restore_fastfetch
        restore_logout
        ;;
    --no-layout)
        build
        generate
        prepare_theme
        link_packages
        link_schemes
        link_frames
        link_kvantum
        link_gtk
        link_icons
        link_cursors
        units
        ;;
    "")
        build
        generate
        prepare_theme
        link_packages
        link_schemes
        link_frames
        link_kvantum
        link_gtk
        link_icons
        link_cursors
        apply_theme
        apply_scheme
        apply_frames
        apply_kvantum
        apply_gate
        apply_switchers
        apply_lockscreen
        apply_gtk
        apply_icons
        apply_splash
        apply_cursors
        apply_alacritty
        apply_fastfetch
        apply_logout
        units
        "$hudctl" layout
        ;;
    *)
        sed -n '2,16s/^# \{0,1\}//p' "$0"
        exit 2
        ;;
esac
