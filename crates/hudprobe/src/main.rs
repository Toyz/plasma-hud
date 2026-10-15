//! hudprobe: telemetry for the plasmahud plasmoid.
//!
//! The plasmoid gets CPU/GPU/RAM/net from ksystemstats. This fills the gaps
//! ksystemstats does not cover (top processes, load, ip, pacman state):
//!
//!   hudprobe            print one JSON snapshot and exit (fallback path)
//!   hudprobe updates    pending pacman updates via checkupdates (slow, network)
//!   hudprobe serve      daemon: push a JSON line per sample to unix-socket clients
//!
//! Zero dependencies on purpose.

mod serve;

use std::collections::HashMap;
use std::fmt::Write as _;
use std::fs;
use std::io::{Read, Seek, SeekFrom};
use std::net::UdpSocket;
use std::process::Command;
use std::thread::sleep;
use std::time::{Duration, Instant};

const CLK_TCK: f64 = 100.0; // USER_HZ, fixed at 100 on every Linux arch we care about
const PAGE_SIZE: u64 = 4096;
const SAMPLE: Duration = Duration::from_millis(350);
const TOP_N: usize = 8;

fn main() {
    let mode = std::env::args().nth(1).unwrap_or_default();
    let out = match mode.as_str() {
        "updates" => updates(),
        "serve" => return serve::run(),
        _ => snapshot(),
    };
    println!("{out}");
}

// ---------------------------------------------------------------- snapshot

pub(crate) struct ProcSample {
    name: String,
    ticks: u64,
    rss: u64,
}

pub(crate) fn read_procs() -> HashMap<u32, ProcSample> {
    let mut map = HashMap::new();
    let Ok(dir) = fs::read_dir("/proc") else { return map };
    for entry in dir.flatten() {
        let Some(pid) = entry.file_name().to_str().and_then(|s| s.parse::<u32>().ok()) else {
            continue;
        };
        let Ok(stat) = fs::read_to_string(format!("/proc/{pid}/stat")) else { continue };
        // comm is wrapped in parens and may itself contain spaces or parens.
        let (Some(open), Some(close)) = (stat.find('('), stat.rfind(')')) else { continue };
        let name = stat[open + 1..close].to_string();
        let rest: Vec<&str> = stat[close + 2..].split_whitespace().collect();
        // rest[0] is field 3 (state); utime/stime are fields 14/15; rss is 24.
        if rest.len() < 22 {
            continue;
        }
        let utime: u64 = rest[11].parse().unwrap_or(0);
        let stime: u64 = rest[12].parse().unwrap_or(0);
        let rss: u64 = rest[21].parse().unwrap_or(0);
        map.insert(pid, ProcSample { name, ticks: utime + stime, rss: rss * PAGE_SIZE });
    }
    map
}

pub(crate) struct Top {
    name: String,
    cpu: f64,
    rss: u64,
    count: u32,
}

fn top_processes() -> (Vec<Top>, usize) {
    let t0 = Instant::now();
    let a = read_procs();
    sleep(SAMPLE);
    let b = read_procs();
    let secs = t0.elapsed().as_secs_f64().max(0.001);
    (rank(&a, &b, secs), b.len())
}

/// Per-command CPU% (100 = one core) between two samples `secs` apart, top N first.
pub(crate) fn rank(a: &HashMap<u32, ProcSample>, b: &HashMap<u32, ProcSample>, secs: f64) -> Vec<Top> {
    // Group by command name so multi-process apps (browsers, electron) read as one line.
    let mut groups: HashMap<String, Top> = HashMap::new();
    for (pid, s) in b {
        let prev = a.get(pid).map(|p| p.ticks).unwrap_or(s.ticks);
        let cpu = s.ticks.saturating_sub(prev) as f64 / CLK_TCK / secs * 100.0;
        let g = groups.entry(s.name.clone()).or_insert_with(|| Top {
            name: s.name.clone(),
            cpu: 0.0,
            rss: 0,
            count: 0,
        });
        g.cpu += cpu;
        g.rss += s.rss;
        g.count += 1;
    }
    let mut list: Vec<Top> = groups.into_values().collect();
    list.sort_by(|x, y| {
        y.cpu
            .partial_cmp(&x.cpu)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then(y.rss.cmp(&x.rss))
    });
    list.truncate(TOP_N);
    list
}

fn loadavg() -> (String, u32) {
    let s = fs::read_to_string("/proc/loadavg").unwrap_or_default();
    let f: Vec<&str> = s.split_whitespace().collect();
    let load = if f.len() >= 3 { format!("[{},{},{}]", f[0], f[1], f[2]) } else { "[0,0,0]".into() };
    let threads = f
        .get(3)
        .and_then(|t| t.split('/').nth(1))
        .and_then(|n| n.parse().ok())
        .unwrap_or(0);
    (load, threads)
}

fn default_iface() -> String {
    let s = fs::read_to_string("/proc/net/route").unwrap_or_default();
    s.lines()
        .skip(1)
        .filter_map(|l| {
            let f: Vec<&str> = l.split_whitespace().collect();
            (f.len() > 2 && f[1] == "00000000").then(|| f[0].to_string())
        })
        .next()
        .unwrap_or_default()
}

fn local_ip() -> String {
    // A connected UDP socket picks the outbound address without sending anything.
    UdpSocket::bind("0.0.0.0:0")
        .and_then(|s| s.connect("1.1.1.1:53").map(|_| s))
        .and_then(|s| s.local_addr())
        .map(|a| a.ip().to_string())
        .unwrap_or_default()
}

fn cpu_model() -> String {
    fs::read_to_string("/proc/cpuinfo")
        .unwrap_or_default()
        .lines()
        .find(|l| l.starts_with("model name"))
        .and_then(|l| l.split(':').nth(1))
        .map(|s| s.trim().to_string())
        .unwrap_or_default()
}

fn package_count() -> usize {
    fs::read_dir("/var/lib/pacman/local")
        .map(|d| d.flatten().filter(|e| e.path().is_dir()).count())
        .unwrap_or(0)
}

/// Timestamp of the most recent `pacman -Syu`, read from the tail of pacman.log.
fn last_upgrade() -> String {
    let Ok(mut f) = fs::File::open("/var/log/pacman.log") else { return String::new() };
    let len = f.metadata().map(|m| m.len()).unwrap_or(0);
    let mut window: u64 = 256 * 1024;
    loop {
        let start = len.saturating_sub(window);
        let mut buf = String::new();
        if f.seek(SeekFrom::Start(start)).is_err() {
            return String::new();
        }
        let mut bytes = Vec::new();
        if f.read_to_end(&mut bytes).is_err() {
            return String::new();
        }
        buf.push_str(&String::from_utf8_lossy(&bytes));
        if let Some(line) = buf.lines().rev().find(|l| l.contains("starting full system upgrade")) {
            return line
                .strip_prefix('[')
                .and_then(|l| l.split(']').next())
                .unwrap_or_default()
                .to_string();
        }
        if start == 0 {
            return String::new();
        }
        window *= 4;
    }
}

fn snapshot() -> String {
    let (top, procs) = top_processes();
    build_snapshot(&top, procs, None)
}

/// The JSON snapshot; `updates` is an already-serialized updates object, if known.
pub(crate) fn build_snapshot(top: &[Top], procs: usize, updates: Option<&str>) -> String {
    let (load, threads) = loadavg();

    let mut s = String::with_capacity(1024);
    s.push('{');
    let _ = write!(s, "\"load\":{load},\"procs\":{procs},\"threads\":{threads},");
    let _ = write!(s, "\"iface\":{},\"ip\":{},", jstr(&default_iface()), jstr(&local_ip()));
    let _ = write!(s, "\"cpuModel\":{},", jstr(&cpu_model()));
    let _ = write!(s, "\"user\":{},", jstr(&std::env::var("USER").unwrap_or_default()));
    let _ = write!(s, "\"pkgs\":{},\"lastUpgrade\":{},", package_count(), jstr(&last_upgrade()));
    s.push_str("\"top\":[");
    for (i, t) in top.iter().enumerate() {
        if i > 0 {
            s.push(',');
        }
        let _ = write!(
            s,
            "{{\"name\":{},\"cpu\":{:.1},\"rss\":{},\"count\":{}}}",
            jstr(&t.name),
            t.cpu,
            t.rss,
            t.count
        );
    }
    s.push(']');
    if let Some(u) = updates {
        let _ = write!(s, ",\"updates\":{u}");
    }
    s.push('}');
    s
}

// ----------------------------------------------------------------- updates

pub(crate) fn updates() -> String {
    // checkupdates (pacman-contrib) syncs into a private db copy, so it is safe to call unprivileged.
    // Exit 0 = updates listed, 2 = none, anything else = failure.
    let out = Command::new("checkupdates").arg("--nocolor").output();
    let Ok(out) = out else { return "{\"updates\":-1,\"list\":[]}".into() };
    let code = out.status.code().unwrap_or(1);
    if code == 2 {
        return "{\"updates\":0,\"list\":[]}".into();
    }
    if code != 0 {
        return "{\"updates\":-1,\"list\":[]}".into();
    }
    let text = String::from_utf8_lossy(&out.stdout);
    let names: Vec<&str> = text.lines().filter_map(|l| l.split_whitespace().next()).collect();
    let mut s = format!("{{\"updates\":{},\"list\":[", names.len());
    for (i, n) in names.iter().take(12).enumerate() {
        if i > 0 {
            s.push(',');
        }
        s.push_str(&jstr(n));
    }
    s.push_str("]}");
    s
}

// ------------------------------------------------------------------- json

fn jstr(v: &str) -> String {
    let mut s = String::with_capacity(v.len() + 2);
    s.push('"');
    for c in v.chars() {
        match c {
            '"' => s.push_str("\\\""),
            '\\' => s.push_str("\\\\"),
            '\n' => s.push_str("\\n"),
            '\r' => s.push_str("\\r"),
            '\t' => s.push_str("\\t"),
            c if (c as u32) < 0x20 => {
                let _ = write!(s, "\\u{:04x}", c as u32);
            }
            c => s.push(c),
        }
    }
    s.push('"');
    s
}
