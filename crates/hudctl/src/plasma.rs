//! Typed view over `plasma-org.kde.plasma.desktop-appletsrc`.
//!
//! Layout as Plasma 6 stores it:
//!   [Containments][C]                              plugin, lastScreen, location, wallpaperplugin, ...
//!   [Containments][C][General]                     AppletOrder=a;b;c (panels)
//!   [Containments][C][Applets][A]                  plugin, immutability
//!   [Containments][C][Applets][A][Configuration][General]   the widget's own config
//!   [Containments][C][Wallpaper][<plugin>][General]         the wallpaper's config

use crate::kconfig::Doc;

pub const PANEL: &str = "org.kde.panel";

#[derive(Debug, Clone)]
pub struct Containment {
    pub id: String,
    pub plugin: String,
    pub screen: i32,
    pub wallpaper: String,
}

impl Containment {
    pub fn is_panel(&self) -> bool {
        self.plugin == PANEL
    }
}

#[derive(Debug, Clone)]
pub struct Applet {
    pub id: String,
    pub plugin: String,
}

pub fn containments(doc: &Doc) -> Vec<Containment> {
    doc.children(&["Containments"])
        .into_iter()
        .filter(|id| doc.has_group(&["Containments", id]))
        .map(|id| {
            let get = |k: &str| doc.get(&["Containments", &id], k).unwrap_or_default();
            Containment {
                plugin: get("plugin"),
                screen: get("lastScreen").parse().unwrap_or(-1),
                wallpaper: get("wallpaperplugin"),
                id,
            }
        })
        .collect()
}

pub fn applets(doc: &Doc, containment: &str) -> Vec<Applet> {
    doc.children(&["Containments", containment, "Applets"])
        .into_iter()
        .filter_map(|id| {
            let plugin = doc.get(&["Containments", containment, "Applets", &id], "plugin")?;
            Some(Applet { id, plugin })
        })
        .collect()
}

pub fn applet_config(doc: &Doc, containment: &str, applet: &str, key: &str) -> Option<String> {
    doc.get(&["Containments", containment, "Applets", applet, "Configuration", "General"], key)
}

pub fn set_applet_config(doc: &mut Doc, containment: &str, applet: &str, key: &str, value: &str) {
    doc.set(&["Containments", containment, "Applets", applet, "Configuration", "General"], key, value);
}

pub fn applet_order(doc: &Doc, containment: &str) -> Vec<String> {
    doc.get(&["Containments", containment, "General"], "AppletOrder")
        .unwrap_or_default()
        .split(';')
        .filter(|s| !s.is_empty())
        .map(String::from)
        .collect()
}

pub fn set_applet_order(doc: &mut Doc, containment: &str, order: &[String]) {
    doc.set(&["Containments", containment, "General"], "AppletOrder", &order.join(";"));
}

/// Hands out ids above everything already in the file (applet ids are not unique
/// across containments, so stay clear of all of them).
pub struct Ids(u32);

impl Ids {
    pub fn new(doc: &Doc) -> Self {
        Ids(doc.max_numeric_id())
    }
    pub fn next(&mut self) -> String {
        self.0 += 1;
        self.0.to_string()
    }
}

pub fn add_applet(doc: &mut Doc, ids: &mut Ids, containment: &str, plugin: &str) -> String {
    let id = ids.next();
    let path = ["Containments", containment, "Applets", &id];
    doc.set(&path, "immutability", "1");
    doc.set(&path, "plugin", plugin);
    id
}

/// A bottom panel on `screen`, like the ones Plasma's "Add Panel" creates.
pub fn add_panel(doc: &mut Doc, ids: &mut Ids, screen: i32) -> String {
    let id = ids.next();
    let path = ["Containments", &id];
    doc.set(&path, "activityId", "");
    doc.set(&path, "formfactor", "2");
    doc.set(&path, "immutability", "1");
    doc.set(&path, "lastScreen", &screen.to_string());
    doc.set(&path, "location", "4");
    doc.set(&path, "plugin", PANEL);
    doc.set(&path, "wallpaperplugin", "org.kde.image");
    id
}
