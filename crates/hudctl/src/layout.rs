//! The floating-islands layout. Every panel's own background is invisible (the
//! helba-hud desktop theme), so only HUD plates float over the wallpaper:
//!
//!   main screen    [◆ launcher | workspaces]   [ tasks (this screen) ]   [ tray | clock | CPU GPU MEM TMP ]
//!   side screens                               [ tasks (this screen) ]
//!
//! The stock launcher, pager, clock, show-desktop, separator and task managers are
//! removed from the main panel (pinned apps carry over); the system tray stays and the
//! right island wraps it. Every screen's `org.kde.image` wallpaper moves onto hudwall
//! with the same image. HUD panels are docked (never floating). Re-running is safe: anything already in place is left alone,
//! and widgets from the earlier layout are converted rather than duplicated.

use crate::kconfig::Doc;
use crate::plasma::{self, Applet, Containment, Ids};

pub const HUD: &str = "org.helba.plasmahud";
pub const WALL: &str = "org.helba.hudwall";
pub const GATE: &str = "org.helba.chaosgate";
/// The Chaos Gate's global shortcut (stored on its applet; Plasma registers it).
const GATE_SHORTCUT: &str = "Meta+Space";
const TRAY: &str = "org.kde.plasma.systemtray";
const STOCK_TASKS: [&str; 2] = ["org.kde.plasma.icontasks", "org.kde.plasma.taskmanager"];
/// Stock applets the islands replace.
const REPLACED: [&str; 7] = [
    "org.kde.plasma.kickoff",
    "org.kde.plasma.pager",
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.digitalclock",
    "org.kde.plasma.showdesktop",
    "org.kde.plasma.icontasks",
    "org.kde.plasma.taskmanager",
];
const IMAGE: &str = "org.kde.image";
const PANEL_THICKNESS: &str = "34";

// HUD widget modes (see Bar.qml).
const BOTH: u8 = 0;
const BADGE: u8 = 1;
const TASKS: u8 = 2;
const LEFT: u8 = 3;
const RIGHT: u8 = 4;

/// Both config files, edited together.
pub struct Config {
    pub applets: Doc,
    pub shell: Doc,
}

fn hud_mode(doc: &Doc, c: &str, a: &str) -> u8 {
    plasma::applet_config(doc, c, a, "mode").and_then(|m| m.parse().ok()).unwrap_or(BOTH)
}

fn huds(doc: &Doc, c: &str) -> Vec<(Applet, u8)> {
    plasma::applets(doc, c).into_iter().filter(|a| a.plugin == HUD).map(|a| {
        let m = hud_mode(doc, c, &a.id);
        (a, m)
    }).collect()
}

fn add_hud(doc: &mut Doc, ids: &mut Ids, c: &str, settings: &[(&str, &str)]) -> String {
    let id = plasma::add_applet(doc, ids, c, HUD);
    for (k, v) in settings {
        plasma::set_applet_config(doc, c, &id, k, v);
    }
    id
}

fn tasks_settings(launchers: &str) -> Vec<(&str, &str)> {
    vec![("mode", "2"), ("launchers", launchers), ("currentScreenOnly", "true")]
}

const RIGHT_SETTINGS: [(&str, &str); 7] = [
    ("mode", "4"),
    ("badgeCpu", "true"),
    ("badgeGpu", "true"),
    ("badgeMem", "true"),
    ("badgeTemp", "true"),
    ("badgeNet", "false"),
    ("badgeUptime", "false"),
];

/// Apply the layout to `cfg` in memory; returns a line per change (or decision).
pub fn apply(cfg: &mut Config) -> Vec<String> {
    let mut log = Vec::new();
    let doc = &mut cfg.applets;
    let mut ids = Ids::new(doc);
    let all = plasma::containments(doc);
    let panels: Vec<&Containment> = all.iter().filter(|c| c.is_panel()).collect();
    let mut screens: Vec<i32> = all.iter().filter(|c| !c.is_panel() && c.screen >= 0).map(|c| c.screen).collect();
    screens.sort_unstable();
    screens.dedup();

    // ------------------------------------------------------------ main panel
    let is_main = |doc: &Doc, p: &Containment| {
        plasma::applets(doc, &p.id).iter().any(|a| {
            a.plugin == TRAY || a.plugin == "org.kde.plasma.kickoff"
                || (a.plugin == HUD && matches!(hud_mode(doc, &p.id, &a.id), LEFT | RIGHT))
        })
    };
    let main = panels.iter().find(|p| is_main(doc, p)).or(panels.first()).map(|p| (*p).clone());
    let (main_id, main_screen) = match main {
        Some(p) => (p.id, p.screen.max(0)),
        None => {
            let s = screens.first().copied().unwrap_or(0);
            let id = plasma::add_panel(doc, &mut ids, s);
            let tray = plasma::add_applet(doc, &mut ids, &id, TRAY);
            plasma::set_applet_order(doc, &id, &[tray]);
            log.push(format!("no panel found: created main panel {id} on screen {s}"));
            (id, s)
        }
    };
    let before = plasma::applet_order(doc, &main_id);

    // Pinned apps from any stock task manager carry over to the HUD strip.
    let mut launchers: Vec<String> = Vec::new();
    for a in plasma::applets(doc, &main_id).iter().filter(|a| STOCK_TASKS.contains(&a.plugin.as_str())) {
        for l in plasma::applet_config(doc, &main_id, &a.id, "launchers").unwrap_or_default().split(',') {
            if !l.is_empty() && !launchers.iter().any(|x| x == l) {
                launchers.push(l.to_string());
            }
        }
    }

    // Reuse HUD widgets from earlier layouts by converting their mode.
    let existing = huds(doc, &main_id);
    let find = |modes: &[u8]| existing.iter().find(|(_, m)| modes.contains(m)).map(|(a, _)| a.id.clone());
    let mut taken: Vec<String> = Vec::new();

    let left = match find(&[LEFT]) {
        Some(id) => id,
        None => {
            let id = add_hud(doc, &mut ids, &main_id, &[("mode", "3")]);
            log.push(format!("main panel {main_id}: left island {id} (launcher + workspaces)"));
            id
        }
    };
    taken.push(left.clone());

    let tasks = match find(&[TASKS, BOTH]) {
        Some(id) => {
            if hud_mode(doc, &main_id, &id) != TASKS {
                plasma::set_applet_config(doc, &main_id, &id, "mode", "2");
                log.push(format!("main panel {main_id}: widget {id} becomes the tasks island"));
            }
            id
        }
        None => {
            let joined = launchers.join(",");
            let id = add_hud(doc, &mut ids, &main_id, &tasks_settings(&joined));
            log.push(format!(
                "main panel {main_id}: tasks island {id}; pinned: {}",
                if joined.is_empty() { "none" } else { &joined }
            ));
            id
        }
    };
    taken.push(tasks.clone());

    let right = match existing.iter().find(|(a, m)| matches!(*m, RIGHT | BADGE) && !taken.contains(&a.id)) {
        Some((a, m)) => {
            if *m != RIGHT {
                for (k, v) in RIGHT_SETTINGS {
                    plasma::set_applet_config(doc, &main_id, &a.id, k, v);
                }
                log.push(format!("main panel {main_id}: badge {} becomes the right island", a.id));
            }
            a.id.clone()
        }
        None => {
            let id = add_hud(doc, &mut ids, &main_id, &RIGHT_SETTINGS);
            log.push(format!("main panel {main_id}: right island {id} (tray + clock + telemetry)"));
            id
        }
    };

    // Drop what the islands replace.
    for a in plasma::applets(doc, &main_id).into_iter().filter(|a| REPLACED.contains(&a.plugin.as_str())) {
        doc.remove_tree(&["Containments", &main_id, "Applets", &a.id]);
        log.push(format!("main panel {main_id}: removed {} ({})", a.plugin, a.id));
    }

    // Order: left, tasks, whatever else the user had (kept in order), tray, right.
    let present: Vec<Applet> = plasma::applets(doc, &main_id);
    let tray: Vec<String> = present.iter().filter(|a| a.plugin == TRAY).map(|a| a.id.clone()).collect();
    let ours = [left.clone(), tasks.clone(), right.clone()];
    let mut others: Vec<String> = before
        .iter()
        .filter(|id| present.iter().any(|a| &a.id == *id) && !ours.contains(id) && !tray.contains(id))
        .cloned()
        .collect();
    for a in &present {
        if !ours.contains(&a.id) && !tray.contains(&a.id) && !others.contains(&a.id) {
            others.push(a.id.clone());
        }
    }
    // The Chaos Gate widget: invisible, last, carrying the Meta+Space shortcut.
    let gate = match present.iter().find(|a| a.plugin == GATE) {
        Some(a) => a.id.clone(),
        None => {
            let id = plasma::add_applet(doc, &mut ids, &main_id, GATE);
            log.push(format!("main panel {main_id}: Chaos Gate {id} on {GATE_SHORTCUT}"));
            id
        }
    };
    let shortcut = ["Containments", main_id.as_str(), "Applets", gate.as_str(), "Shortcuts"];
    if doc.get(&shortcut, "global").as_deref() != Some(GATE_SHORTCUT) {
        doc.set(&shortcut, "global", GATE_SHORTCUT);
    }
    others.retain(|id| *id != gate);

    let mut order = vec![left, tasks];
    order.extend(others);
    order.extend(tray);
    order.push(right);
    order.push(gate);
    if order != before {
        log.push(format!("main panel {main_id}: order {}", order.join(";")));
    } else {
        log.push(format!("main panel {main_id}: islands already in place"));
    }
    plasma::set_applet_order(doc, &main_id, &order);

    // ------------------------------------------------------------ side screens
    let mut new_panels = Vec::new();
    for &s in screens.iter().filter(|&&s| s != main_screen) {
        let here: Vec<_> = panels.iter().filter(|p| p.screen == s).collect();
        let has_tasks = here.iter().any(|p| huds(doc, &p.id).iter().any(|(_, m)| matches!(*m, TASKS | BOTH)));
        if has_tasks {
            log.push(format!("screen {s}: already has a tasks island"));
            continue;
        }
        let (pid, created) = match here.first() {
            Some(p) => (p.id.clone(), false),
            None => (plasma::add_panel(doc, &mut ids, s), true),
        };
        let t = add_hud(doc, &mut ids, &pid, &tasks_settings(""));
        let mut o = plasma::applet_order(doc, &pid);
        o.push(t);
        plasma::set_applet_order(doc, &pid, &o);
        if created {
            new_panels.push(pid.clone());
            log.push(format!("screen {s}: new panel {pid} with a tasks island (this screen's windows)"));
        } else {
            log.push(format!("screen {s}: tasks island added to panel {pid}"));
        }
    }

    // Every HUD panel is docked: a floating panel drops to the screen edge whenever a
    // window maximizes and floats back up after, so the islands would bob up and down.
    let hud_panels: Vec<String> = plasma::containments(&cfg.applets)
        .into_iter()
        .filter(|c| c.is_panel() && !huds(&cfg.applets, &c.id).is_empty())
        .map(|c| c.id)
        .collect();
    for pid in &hud_panels {
        let view = format!("Panel {pid}");
        if cfg.shell.get(&["PlasmaViews", &view], "floating").as_deref() != Some("0") {
            cfg.shell.set(&["PlasmaViews", &view], "floating", "0");
            log.push(format!("panel {pid}: docked (no floating bounce)"));
        }
    }

    // New panels look like the main one: opacity, length mode, thickness.
    for pid in &new_panels {
        let from = format!("Panel {main_id}");
        let to = format!("Panel {pid}");
        for key in ["panelOpacity", "panelLengthMode"] {
            if let Some(v) = cfg.shell.get(&["PlasmaViews", &from], key) {
                cfg.shell.set(&["PlasmaViews", &to], key, &v);
            }
        }
        let thickness = cfg.shell.get(&["PlasmaViews", &from, "Defaults"], "thickness");
        cfg.shell.set(&["PlasmaViews", &to, "Defaults"], "thickness", thickness.as_deref().unwrap_or(PANEL_THICKNESS));
    }

    // ------------------------------------------------------------ wallpapers
    let doc = &mut cfg.applets;
    for c in all.iter().filter(|c| !c.is_panel() && c.screen >= 0) {
        match c.wallpaper.as_str() {
            WALL => log.push(format!("screen {} (desktop {}): already on hudwall", c.screen, c.id)),
            IMAGE => {
                let src = ["Containments", &c.id, "Wallpaper", IMAGE, "General"];
                let dst = ["Containments", &c.id, "Wallpaper", WALL, "General"];
                let image = doc.get(&src, "Image").unwrap_or_default();
                let fill = doc.get(&src, "FillMode").unwrap_or_else(|| "2".into());
                doc.set(&["Containments", &c.id], "wallpaperplugin", WALL);
                doc.set(&dst, "Image", &image);
                doc.set(&dst, "FillMode", &fill);
                doc.set(&dst, "Effect", "16");
                doc.set(&dst, "Span", "true");
                log.push(format!("screen {} (desktop {}): hudwall Trace over {image}", c.screen, c.id));
            }
            other => log.push(format!("screen {} (desktop {}): wallpaper plugin {other} left alone", c.screen, c.id)),
        }
    }
    log
}

#[cfg(test)]
mod tests {
    use super::*;

    // A trimmed copy of a real three-screen setup: one stock panel on the middle screen.
    const APPLETS: &str = "\
[Containments][47]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][47][Applets][48]
immutability=1
plugin=org.kde.plasma.kickoff

[Containments][47][Applets][49]
immutability=1
plugin=org.kde.plasma.pager

[Containments][47][Applets][52]
immutability=1
plugin=org.kde.plasma.systemtray

[Containments][47][Applets][52][Applets][71]
immutability=1
plugin=org.kde.plasma.clipboard

[Containments][47][Applets][60]
immutability=1
plugin=org.kde.plasma.weather

[Containments][47][Applets][65]
immutability=1
plugin=org.kde.plasma.digitalclock

[Containments][47][Applets][66]
immutability=1
plugin=org.kde.plasma.showdesktop

[Containments][47][Applets][74]
immutability=1
plugin=org.kde.plasma.icontasks

[Containments][47][Applets][74][Configuration][General]
launchers=applications:systemsettings.desktop,preferred://filemanager

[Containments][47][General]
AppletOrder=48;49;74;60;52;65;66

[Containments][70]
lastScreen=1
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][70][Wallpaper][org.kde.image][General]
FillMode=2
Image=file:///pics/a.png

[Containments][71]
lastScreen=2
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.color

[Containments][72]
lastScreen=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][72][Wallpaper][org.kde.image][General]
Image=file:///pics/b c.png
";
    const SHELL: &str = "\
[PlasmaViews][Panel 47]
floating=1
panelOpacity=2

[PlasmaViews][Panel 47][Defaults]
thickness=34
";

    fn run(applets: &str) -> (Config, Vec<String>) {
        let mut cfg = Config { applets: Doc::parse(applets), shell: Doc::parse(SHELL) };
        let log = apply(&mut cfg);
        (cfg, log)
    }

    fn plugin(d: &Doc, c: &str, a: &str) -> String {
        d.get(&["Containments", c, "Applets", a], "plugin").unwrap_or_default()
    }

    #[test]
    fn builds_islands_from_a_stock_panel() {
        let (cfg, _) = run(APPLETS);
        let d = &cfg.applets;
        assert_eq!(cfg.shell.get(&["PlasmaViews", "Panel 47"], "floating").as_deref(), Some("0"));
        let order = plasma::applet_order(d, "47");
        // left, tasks, the user's weather widget, tray, right, gate.
        assert_eq!(order.len(), 6, "{order:?}");
        assert_eq!(plugin(d, "47", &order[5]), GATE);
        assert_eq!(d.get(&["Containments", "47", "Applets", &order[5], "Shortcuts"], "global").as_deref(), Some("Meta+Space"));
        assert_eq!(plasma::applet_config(d, "47", &order[0], "mode").as_deref(), Some("3"));
        assert_eq!(plasma::applet_config(d, "47", &order[1], "mode").as_deref(), Some("2"));
        assert_eq!(
            plasma::applet_config(d, "47", &order[1], "launchers").as_deref(),
            Some("applications:systemsettings.desktop,preferred://filemanager")
        );
        assert_eq!(order[2], "60");
        assert_eq!(order[3], "52");
        assert_eq!(plasma::applet_config(d, "47", &order[4], "mode").as_deref(), Some("4"));
        // Stock pieces gone (with their nested groups); the tray and its children stay.
        for gone in ["48", "49", "65", "66", "74"] {
            assert!(!d.has_group(&["Containments", "47", "Applets", gone]), "{gone} still there");
        }
        assert!(!d.has_group(&["Containments", "47", "Applets", "74", "Configuration", "General"]));
        assert!(d.has_group(&["Containments", "47", "Applets", "52", "Applets", "71"]));

        // Side screens get a tasks-only panel pinned to their screen, looking like the main one.
        let side: Vec<_> = plasma::containments(d).into_iter().filter(|c| c.is_panel() && c.id != "47").collect();
        assert_eq!(side.iter().map(|c| c.screen).collect::<Vec<_>>(), [1, 2]);
        for p in &side {
            let o = plasma::applet_order(d, &p.id);
            assert_eq!(o.len(), 1);
            assert_eq!(plugin(d, &p.id, &o[0]), HUD);
            assert_eq!(plasma::applet_config(d, &p.id, &o[0], "mode").as_deref(), Some("2"));
            let view = format!("Panel {}", p.id);
            assert_eq!(cfg.shell.get(&["PlasmaViews", &view], "floating").as_deref(), Some("0"));
            assert_eq!(cfg.shell.get(&["PlasmaViews", &view, "Defaults"], "thickness").as_deref(), Some("34"));
        }

        // Image wallpapers move to hudwall with the same image; others are untouched.
        assert_eq!(d.get(&["Containments", "70"], "wallpaperplugin").as_deref(), Some(WALL));
        assert_eq!(d.get(&["Containments", "70", "Wallpaper", WALL, "General"], "Image").as_deref(), Some("file:///pics/a.png"));
        assert_eq!(d.get(&["Containments", "72", "Wallpaper", WALL, "General"], "Image").as_deref(), Some("file:///pics/b c.png"));
        assert_eq!(d.get(&["Containments", "71"], "wallpaperplugin").as_deref(), Some("org.kde.color"));
        assert!(d.has_group(&["Containments", "70", "Wallpaper", "org.kde.image", "General"]));
    }

    #[test]
    fn converts_the_first_layout_without_duplicating() {
        // What the first hudctl layout left: HUD tasks (mode 2) + badge (mode 1) next to stock pieces.
        let first = APPLETS
            .replace(
                "[Containments][47][Applets][74]\nimmutability=1\nplugin=org.kde.plasma.icontasks",
                "[Containments][47][Applets][74]\nimmutability=1\nplugin=org.helba.plasmahud",
            )
            .replace(
                "launchers=applications:systemsettings.desktop,preferred://filemanager",
                "mode=2\nlaunchers=applications:systemsettings.desktop,preferred://filemanager",
            )
            .replace(
                "[Containments][47][Applets][66]\nimmutability=1\nplugin=org.kde.plasma.showdesktop",
                "[Containments][47][Applets][66]\nimmutability=1\nplugin=org.helba.plasmahud\n\n[Containments][47][Applets][66][Configuration][General]\nmode=1",
            );
        let (cfg, _) = run(&first);
        let d = &cfg.applets;
        let order = plasma::applet_order(d, "47");
        assert_eq!(order[1], "74", "existing tasks widget reused: {order:?}");
        assert_eq!(order[order.len() - 2], "66", "badge reused as right island: {order:?}");
        assert_eq!(plasma::applet_config(d, "47", "66", "mode").as_deref(), Some("4"));
        let hud_count = plasma::applets(d, "47").iter().filter(|a| a.plugin == HUD).count();
        assert_eq!(hud_count, 3);
    }

    #[test]
    fn second_run_changes_nothing() {
        let (mut cfg, _) = run(APPLETS);
        let before = (cfg.applets.serialize(), cfg.shell.serialize());
        let log = apply(&mut cfg);
        assert_eq!((cfg.applets.serialize(), cfg.shell.serialize()), before);
        assert!(log.iter().all(|l| l.contains("already") || l.contains("left alone")), "{log:#?}");
    }
}
