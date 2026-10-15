//! hudctl: plasma-hud's desktop layout tool.
//!
//!   hudctl layout [--dry-run] [--config DIR]   apply the command-center layout
//!   hudctl restore [BACKUP_DIR]                 put back the config saved before the last layout
//!
//! Edits Plasma's KConfig files directly while plasmashell is stopped, so panel screens,
//! widget order and panel looks stick (a running shell would overwrite them). With
//! `--config DIR` it works on the files in DIR and never touches the running session.

mod kconfig;
mod layout;
mod plasma;

use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};
use std::{env, fs};

use kconfig::Doc;
use layout::Config;

const APPLETSRC: &str = "plasma-org.kde.plasma.desktop-appletsrc";
const SHELLRC: &str = "plasmashellrc";
const SHELL_UNIT: &str = "plasma-plasmashell";

fn main() -> ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();
    let result = match args.first().map(String::as_str) {
        Some("layout") => cmd_layout(&args[1..]),
        Some("restore") => cmd_restore(args.get(1).map(PathBuf::from)),
        _ => Err(usage()),
    };
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("hudctl: {e}");
            ExitCode::FAILURE
        }
    }
}

fn usage() -> String {
    "usage: hudctl layout [--dry-run] [--config DIR] | hudctl restore [BACKUP_DIR]".into()
}

fn home() -> PathBuf {
    PathBuf::from(env::var("HOME").unwrap_or_default())
}
fn config_dir() -> PathBuf {
    env::var("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|_| home().join(".config"))
}
fn state_dir() -> PathBuf {
    env::var("XDG_STATE_HOME").map(PathBuf::from).unwrap_or_else(|_| home().join(".local/state")).join("plasma-hud")
}

fn say(s: &str) {
    println!("\x1b[36m::\x1b[0m {s}");
}

// ------------------------------------------------------------------ layout

fn cmd_layout(args: &[String]) -> Result<(), String> {
    let mut dry = false;
    let mut dir: Option<PathBuf> = None;
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--dry-run" => dry = true,
            "--config" => dir = Some(it.next().ok_or("--config needs a directory")?.into()),
            _ => return Err(usage()),
        }
    }
    let live = dir.is_none();
    let dir = dir.unwrap_or_else(config_dir);

    if dry {
        let mut cfg = load(&dir)?;
        for line in layout::apply(&mut cfg) {
            println!("   [dry] {line}");
        }
        return Ok(());
    }

    let stopped = live && shell_running();
    if stopped {
        say("stopping plasmashell (panels can only be placed while it is down)");
        systemctl(&["stop", SHELL_UNIT])?;
    }
    let result = (|| -> Result<(), String> {
        if live {
            let b = backup(&dir)?;
            say(&format!("backed up Plasma config to {}", b.display()));
        }
        let mut cfg = load(&dir)?;
        let log = layout::apply(&mut cfg);
        save(&dir, &cfg)?;
        for line in log {
            println!("   {line}");
        }
        Ok(())
    })();
    if stopped {
        // Always bring the shell back, even when an edit failed.
        say("starting plasmashell");
        systemctl(&["start", SHELL_UNIT])?;
    }
    result?;
    if live {
        say("layout applied. Undo with: hudctl restore");
    }
    Ok(())
}

fn load(dir: &Path) -> Result<Config, String> {
    let read = |name: &str| {
        let p = dir.join(name);
        fs::read_to_string(&p).map(|t| Doc::parse(&t)).map_err(|e| format!("reading {}: {e}", p.display()))
    };
    Ok(Config { applets: read(APPLETSRC)?, shell: read(SHELLRC).unwrap_or_default() })
}

fn save(dir: &Path, cfg: &Config) -> Result<(), String> {
    write_atomic(&dir.join(APPLETSRC), &cfg.applets.serialize())?;
    write_atomic(&dir.join(SHELLRC), &cfg.shell.serialize())
}

fn write_atomic(path: &Path, text: &str) -> Result<(), String> {
    let tmp = path.with_extension("hudctl-tmp");
    fs::write(&tmp, text).map_err(|e| format!("writing {}: {e}", tmp.display()))?;
    fs::rename(&tmp, path).map_err(|e| format!("replacing {}: {e}", path.display()))
}

// ------------------------------------------------------------------ backup / restore

fn backup(dir: &Path) -> Result<PathBuf, String> {
    let stamp = Command::new("date")
        .arg("+%Y%m%d-%H%M%S")
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "unknown".into());
    let to = state_dir().join(format!("backup-{stamp}"));
    fs::create_dir_all(&to).map_err(|e| format!("creating {}: {e}", to.display()))?;
    for name in [APPLETSRC, SHELLRC] {
        let from = dir.join(name);
        if from.exists() {
            fs::copy(&from, to.join(name)).map_err(|e| format!("backing up {name}: {e}"))?;
        }
    }
    let latest = state_dir().join("latest");
    let _ = fs::remove_file(&latest);
    std::os::unix::fs::symlink(&to, &latest).map_err(|e| format!("linking {}: {e}", latest.display()))?;
    Ok(to)
}

fn cmd_restore(from: Option<PathBuf>) -> Result<(), String> {
    let from = from.unwrap_or_else(|| state_dir().join("latest"));
    if !from.join(APPLETSRC).exists() {
        return Err(format!("no backup at {}", from.display()));
    }
    let from = fs::canonicalize(&from).unwrap_or(from);
    say(&format!("restoring Plasma config from {}", from.display()));
    let stopped = shell_running();
    if stopped {
        systemctl(&["stop", SHELL_UNIT])?;
    }
    let result = (|| {
        for name in [APPLETSRC, SHELLRC] {
            let src = from.join(name);
            if src.exists() {
                fs::copy(&src, config_dir().join(name)).map_err(|e| format!("restoring {name}: {e}"))?;
            }
        }
        Ok::<(), String>(())
    })();
    if stopped {
        systemctl(&["start", SHELL_UNIT])?;
    }
    result?;
    say("restored");
    Ok(())
}

// ------------------------------------------------------------------ session

fn shell_running() -> bool {
    Command::new("systemctl").args(["--user", "is-active", "--quiet", SHELL_UNIT]).status().is_ok_and(|s| s.success())
}

fn systemctl(args: &[&str]) -> Result<(), String> {
    let status = Command::new("systemctl").arg("--user").args(args).status().map_err(|e| format!("systemctl: {e}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("systemctl --user {} failed", args.join(" ")))
    }
}
