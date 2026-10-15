//! `hudprobe serve`: push telemetry to unix-socket clients.
//!
//! Each connected client receives one JSON line per sample (the same object the
//! one-shot mode prints, plus `updates`). Nothing is sampled while no client is
//! connected. Under systemd socket activation the listening socket arrives as fd 3
//! and the daemon exits after a quiet spell; systemd starts it again on the next
//! connection. Run by hand, it binds `$XDG_RUNTIME_DIR/hudprobe.sock` itself.

use std::fs;
use std::io::Write;
use std::os::fd::FromRawFd;
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::sync::{Arc, Condvar, Mutex};
use std::thread;
use std::time::{Duration, Instant};

const INTERVAL: Duration = Duration::from_secs(2);
const FIRST_SAMPLE: Duration = Duration::from_millis(300);
const IDLE_EXIT: Duration = Duration::from_secs(300);
const UPDATES_EVERY: Duration = Duration::from_secs(30 * 60);
const WRITE_TIMEOUT: Duration = Duration::from_secs(1);
const SD_LISTEN_FDS_START: i32 = 3;

#[derive(Default)]
struct State {
    clients: Vec<UnixStream>,
    last: Option<String>,
    updates: Option<String>,
}

type Shared = Arc<(Mutex<State>, Condvar)>;

pub fn run() {
    let (listener, activated) = match systemd_listener() {
        Some(l) => (l, true),
        None => (bind_own(), false),
    };
    let shared: Shared = Arc::default();

    spawn_acceptor(listener, shared.clone());
    spawn_updates(shared.clone());
    sample_loop(&shared, activated);
}

/// The socket systemd passed us, if we were socket-activated.
fn systemd_listener() -> Option<UnixListener> {
    let pid: u32 = std::env::var("LISTEN_PID").ok()?.parse().ok()?;
    let fds: i32 = std::env::var("LISTEN_FDS").ok()?.parse().ok()?;
    if pid != std::process::id() || fds < 1 {
        return None;
    }
    // SAFETY: systemd guarantees fd 3 is an open listening socket owned by this process.
    Some(unsafe { UnixListener::from_raw_fd(SD_LISTEN_FDS_START) })
}

fn bind_own() -> UnixListener {
    let dir = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    let path = format!("{dir}/hudprobe.sock");
    if UnixStream::connect(&path).is_ok() {
        eprintln!("hudprobe: already serving on {path}");
        std::process::exit(0);
    }
    let _ = fs::remove_file(&path);
    let listener = UnixListener::bind(&path).unwrap_or_else(|e| {
        eprintln!("hudprobe: cannot bind {path}: {e}");
        std::process::exit(1);
    });
    // Process lists are nobody else's business.
    let _ = fs::set_permissions(&path, fs::Permissions::from_mode(0o600));
    listener
}

fn spawn_acceptor(listener: UnixListener, shared: Shared) {
    thread::spawn(move || {
        for conn in listener.incoming() {
            let Ok(mut client) = conn else { continue };
            let _ = client.set_write_timeout(Some(WRITE_TIMEOUT));
            let (lock, cv) = &*shared;
            let mut st = lock.lock().unwrap();
            if let Some(line) = &st.last {
                if client.write_all(line.as_bytes()).is_err() {
                    continue;
                }
            }
            st.clients.push(client);
            cv.notify_all();
        }
    });
}

/// checkupdates is slow and hits the network: run it at most every 30 minutes,
/// and only once someone is actually watching.
fn spawn_updates(shared: Shared) {
    thread::spawn(move || loop {
        {
            let (lock, cv) = &*shared;
            let _st = cv.wait_while(lock.lock().unwrap(), |st| st.clients.is_empty()).unwrap();
        }
        let u = crate::updates();
        shared.0.lock().unwrap().updates = Some(u);
        thread::sleep(UPDATES_EVERY);
    });
}

fn sample_loop(shared: &Shared, activated: bool) {
    let (lock, cv) = &**shared;
    loop {
        // Idle until a client shows up.
        {
            let st = lock.lock().unwrap();
            let (st, timeout) = cv.wait_timeout_while(st, IDLE_EXIT, |st| st.clients.is_empty()).unwrap();
            if timeout.timed_out() && st.clients.is_empty() {
                if activated {
                    return;
                }
                continue;
            }
        }

        // Fresh baseline, then a quick first sample so a new client is not left waiting.
        let mut prev = crate::read_procs();
        let mut t_prev = Instant::now();
        let mut wait = FIRST_SAMPLE;
        loop {
            thread::sleep(wait);
            wait = INTERVAL;
            let cur = crate::read_procs();
            let secs = t_prev.elapsed().as_secs_f64().max(0.001);
            t_prev = Instant::now();
            let top = crate::rank(&prev, &cur, secs);
            let procs = cur.len();
            prev = cur;

            let mut st = lock.lock().unwrap();
            let mut line = crate::build_snapshot(&top, procs, st.updates.as_deref());
            line.push('\n');
            st.clients.retain_mut(|c| c.write_all(line.as_bytes()).is_ok());
            if st.clients.is_empty() {
                st.last = None;
                break;
            }
            st.last = Some(line);
        }
    }
}
