#!/bin/sh
# plasma-hud installer.
#
#   ./installer.sh              build, link packages, enable units, apply the panel/wallpaper layout
#   ./installer.sh --no-layout  everything except touching panels and wallpapers
#   ./installer.sh --dry-run    print what the layout step would change, change nothing
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

# Helba Gate (window open / close / minimize): replaces Glide and Squash.
effect_keys="glideEnabled scaleEnabled fadeEnabled squashEnabled magiclampEnabled helbagateEnabled"

apply_gate() {
    if [ "$(kreadconfig6 --file kwinrc --group Plugins --key helbagateEnabled 2>/dev/null)" != true ]; then
        mkdir -p "$state"
        : > "$state/effects.before"
        for k in $effect_keys; do
            printf '%s=%s\n' "$k" "$(kreadconfig6 --file kwinrc --group Plugins --key "$k" 2>/dev/null)" >> "$state/effects.before"
        done
    fi
    for k in glideEnabled scaleEnabled fadeEnabled squashEnabled magiclampEnabled; do
        kwriteconfig6 --file kwinrc --group Plugins --key "$k" false
    done
    kwriteconfig6 --file kwinrc --group Plugins --key helbagateEnabled true
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    say "window animations: Helba Gate (Glide / Squash off)"
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
    --restore)
        ensure_hudctl
        if [ -n "${2:-}" ]; then "$hudctl" restore "$2"; else "$hudctl" restore; fi
        restore_scheme
        restore_frames
        restore_kvantum
        restore_gate
        ;;
    --no-layout)
        build
        generate
        prepare_theme
        link_packages
        link_schemes
        link_frames
        link_kvantum
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
        apply_theme
        apply_scheme
        apply_frames
        apply_kvantum
        apply_gate
        units
        "$hudctl" layout
        ;;
    *)
        sed -n '2,13s/^# \{0,1\}//p' "$0"
        exit 2
        ;;
esac
