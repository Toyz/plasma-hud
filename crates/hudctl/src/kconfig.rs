//! Lossless KConfig (INI) document.
//!
//! Plasma keeps its whole desktop layout in KConfig files. We only ever change a
//! handful of keys, so the document keeps every line it did not touch byte-for-byte:
//! comments, blank lines, `[$i]` flags, localized keys, ordering. Values we read or
//! write go through KConfig's escaping rules.

use std::fmt::Write as _;

#[derive(Debug, Clone)]
enum Line {
    Entry { key: String, raw: String },
    Other(String),
}

#[derive(Debug, Clone)]
pub struct Group {
    pub path: Vec<String>,
    header: String,
    lines: Vec<Line>,
}

#[derive(Debug, Clone, Default)]
pub struct Doc {
    head: Vec<String>,
    groups: Vec<Group>,
    trailing_newline: bool,
}

impl Doc {
    pub fn parse(text: &str) -> Self {
        let mut doc = Doc { trailing_newline: text.ends_with('\n'), ..Default::default() };
        let body = text.strip_suffix('\n').unwrap_or(text);
        if body.is_empty() && !doc.trailing_newline {
            return doc;
        }
        for line in body.split('\n') {
            if let Some(path) = parse_header(line) {
                doc.groups.push(Group { path, header: line.to_string(), lines: Vec::new() });
                continue;
            }
            let parsed = match line.split_once('=') {
                Some((k, _)) if !line.trim_start().starts_with('#') && !k.trim().is_empty() => {
                    Line::Entry { key: key_name(k).to_string(), raw: line.to_string() }
                }
                _ => Line::Other(line.to_string()),
            };
            match doc.groups.last_mut() {
                Some(g) => g.lines.push(parsed),
                None => doc.head.push(line.to_string()),
            }
        }
        doc
    }

    pub fn serialize(&self) -> String {
        let mut out: Vec<&str> = self.head.iter().map(String::as_str).collect();
        for g in &self.groups {
            out.push(&g.header);
            for l in &g.lines {
                out.push(match l {
                    Line::Entry { raw, .. } => raw,
                    Line::Other(s) => s,
                });
            }
        }
        let mut s = out.join("\n");
        if self.trailing_newline {
            s.push('\n');
        }
        s
    }

    fn find(&self, path: &[&str]) -> Option<usize> {
        self.groups.iter().position(|g| g.path.iter().map(String::as_str).eq(path.iter().copied()))
    }

    pub fn has_group(&self, path: &[&str]) -> bool {
        self.find(path).is_some()
    }

    pub fn get(&self, path: &[&str], key: &str) -> Option<String> {
        let g = &self.groups[self.find(path)?];
        g.lines.iter().rev().find_map(|l| match l {
            Line::Entry { key: k, raw } if k == key => raw.split_once('=').map(|(_, v)| unescape(v)),
            _ => None,
        })
    }

    pub fn set(&mut self, path: &[&str], key: &str, value: &str) {
        let raw = format!("{key}={}", escape(value));
        let idx = match self.find(path) {
            Some(i) => i,
            None => {
                // Keep a blank line between groups, like KConfig writes them.
                if let Some(last) = self.groups.last_mut() {
                    if !matches!(last.lines.last(), Some(Line::Other(s)) if s.is_empty()) {
                        last.lines.push(Line::Other(String::new()));
                    }
                } else if !self.head.is_empty() && self.head.last().is_some_and(|s| !s.is_empty()) {
                    self.head.push(String::new());
                }
                self.groups.push(Group {
                    path: path.iter().map(|s| s.to_string()).collect(),
                    header: path.iter().map(|s| format!("[{s}]")).collect(),
                    lines: Vec::new(),
                });
                self.trailing_newline = true;
                self.groups.len() - 1
            }
        };
        let g = &mut self.groups[idx];
        if let Some(Line::Entry { raw: r, .. }) =
            g.lines.iter_mut().rev().find(|l| matches!(l, Line::Entry { key: k, .. } if k == key))
        {
            *r = raw;
            return;
        }
        // Insert before the group's trailing blank lines.
        let at = g.lines.iter().rposition(|l| !matches!(l, Line::Other(s) if s.trim().is_empty())).map_or(0, |i| i + 1);
        g.lines.insert(at, Line::Entry { key: key.to_string(), raw });
    }

    /// Remove a group and every group nested under it.
    pub fn remove_tree(&mut self, prefix: &[&str]) {
        self.groups.retain(|g| !starts_with(&g.path, prefix));
    }

    /// Distinct names of the groups directly under `prefix`, in file order.
    pub fn children(&self, prefix: &[&str]) -> Vec<String> {
        let mut out: Vec<String> = Vec::new();
        for g in &self.groups {
            if g.path.len() > prefix.len() && starts_with(&g.path, prefix) && !out.contains(&g.path[prefix.len()]) {
                out.push(g.path[prefix.len()].clone());
            }
        }
        out
    }

    /// Largest numeric group-path component anywhere in the document.
    pub fn max_numeric_id(&self) -> u32 {
        self.groups.iter().flat_map(|g| g.path.iter()).filter_map(|s| s.parse().ok()).max().unwrap_or(0)
    }
}

fn starts_with(path: &[String], prefix: &[&str]) -> bool {
    path.len() >= prefix.len() && path.iter().zip(prefix).all(|(a, b)| a == b)
}

/// `[A][B][C]` -> ["A", "B", "C"]. Group flags such as `[$i]` are not part of the path.
fn parse_header(line: &str) -> Option<Vec<String>> {
    let t = line.trim_end();
    if !t.starts_with('[') || !t.ends_with(']') {
        return None;
    }
    let mut path = Vec::new();
    let mut rest = t;
    while let Some(r) = rest.strip_prefix('[') {
        let end = find_unescaped(r, ']')?;
        let seg = &r[..end];
        if !seg.starts_with('$') {
            path.push(unescape(seg));
        }
        rest = &r[end + 1..];
    }
    rest.is_empty().then_some(path)
}

fn find_unescaped(s: &str, c: char) -> Option<usize> {
    let mut esc = false;
    for (i, ch) in s.char_indices() {
        if esc {
            esc = false;
        } else if ch == '\\' {
            esc = true;
        } else if ch == c {
            return Some(i);
        }
    }
    None
}

/// `key[$e]` / `key[de]` -> `key`.
fn key_name(k: &str) -> &str {
    let k = k.trim();
    k.find('[').map_or(k, |i| &k[..i])
}

pub fn unescape(v: &str) -> String {
    let mut out = String::with_capacity(v.len());
    let mut it = v.chars().peekable();
    while let Some(c) = it.next() {
        if c != '\\' {
            out.push(c);
            continue;
        }
        match it.next() {
            Some('n') => out.push('\n'),
            Some('t') => out.push('\t'),
            Some('r') => out.push('\r'),
            Some('s') => out.push(' '),
            Some(';') => out.push(';'),
            Some(',') => out.push(','),
            Some('\\') => out.push('\\'),
            Some('x') => {
                let hex: String = (0..2).filter_map(|_| it.next()).collect();
                match u8::from_str_radix(&hex, 16) {
                    Ok(b) => out.push(b as char),
                    Err(_) => {
                        out.push_str("\\x");
                        out.push_str(&hex);
                    }
                }
            }
            Some(o) => {
                out.push('\\');
                out.push(o);
            }
            None => out.push('\\'),
        }
    }
    out
}

pub fn escape(v: &str) -> String {
    let mut out = String::with_capacity(v.len());
    for (i, c) in v.chars().enumerate() {
        match c {
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\t' => out.push_str("\\t"),
            '\r' => out.push_str("\\r"),
            ' ' if i == 0 => out.push_str("\\s"),
            c if (c as u32) < 0x20 => {
                let _ = write!(out, "\\x{:02x}", c as u32);
            }
            c => out.push(c),
        }
    }
    if out.ends_with(' ') {
        out.pop();
        out.push_str("\\s");
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = "\
# leading comment
[ActionPlugins][0]
MiddleButton;NoModifier=org.kde.paste

[Containments][47]
activityId=
plugin=org.kde.panel
Name[de]=Leiste
locked[$i]=true

[Containments][47][General]
AppletOrder=48;49;74
path=\\shome with\\ttab\\\\x\\s

[Group][$i]
k=v
";

    #[test]
    fn round_trips_byte_for_byte() {
        assert_eq!(Doc::parse(SAMPLE).serialize(), SAMPLE);
        let no_nl = SAMPLE.trim_end();
        assert_eq!(Doc::parse(no_nl).serialize(), no_nl);
    }

    #[test]
    fn reads_values_and_paths() {
        let d = Doc::parse(SAMPLE);
        assert_eq!(d.get(&["Containments", "47"], "plugin").as_deref(), Some("org.kde.panel"));
        assert_eq!(d.get(&["Containments", "47"], "Name").as_deref(), Some("Leiste"));
        assert_eq!(d.get(&["Containments", "47", "General"], "path").as_deref(), Some(" home with\ttab\\x "));
        assert_eq!(d.get(&["Group"], "k").as_deref(), Some("v"));
        assert_eq!(d.children(&["Containments", "47"]), vec!["General"]);
        assert_eq!(d.max_numeric_id(), 47);
    }

    #[test]
    fn edits_touch_only_their_lines() {
        let mut d = Doc::parse(SAMPLE);
        d.set(&["Containments", "47", "General"], "AppletOrder", "48;80;49");
        d.set(&["Containments", "47"], "lastScreen", "2");
        d.set(&["Containments", "90", "Applets", "91"], "plugin", "org.helba.plasmahud");
        let s = d.serialize();
        assert!(s.contains("AppletOrder=48;80;49\npath="));
        assert!(s.contains("locked[$i]=true\nlastScreen=2\n\n[Containments][47][General]"));
        assert!(s.ends_with("k=v\n\n[Containments][90][Applets][91]\nplugin=org.helba.plasmahud\n"));
        assert!(s.starts_with("# leading comment\n[ActionPlugins][0]\nMiddleButton;NoModifier=org.kde.paste\n"));

        d.remove_tree(&["Containments", "47"]);
        assert!(!d.has_group(&["Containments", "47"]));
        assert!(!d.has_group(&["Containments", "47", "General"]));
        assert!(d.has_group(&["Containments", "90", "Applets", "91"]));
    }

    #[test]
    fn escape_round_trip() {
        for v in [" lead", "trail ", "a\\b", "multi\nline", "tab\there", "file:///x y/z.png"] {
            assert_eq!(unescape(&escape(v)), v);
        }
    }
}
