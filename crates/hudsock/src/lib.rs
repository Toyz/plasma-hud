//! `org.helba.hud` QML module. `ProbeSocket` connects to the hudprobe daemon's unix
//! socket while `active`, and exposes each JSON line it pushes as `json`.

use std::io::{BufRead, BufReader};
use std::net::Shutdown;
use std::os::unix::net::UnixStream;
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use cxx_qt::{CxxQtType, Threading};

mod plugin;
use cxx_qt_lib::QString;

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, path)]
        #[qproperty(bool, active)]
        #[qproperty(bool, connected)]
        #[qproperty(QString, json)]
        type ProbeSocket = super::ProbeSocketRust;
    }

    impl cxx_qt::Threading for ProbeSocket {}
    impl cxx_qt::Initialize for ProbeSocket {}
}

const RETRY: Duration = Duration::from_secs(2);
const MAX_LINE: usize = 1 << 20;

/// A running reader thread; dropping it stops the thread.
struct Worker {
    stop: Arc<AtomicBool>,
    stream: Arc<Mutex<Option<UnixStream>>>,
}

impl Drop for Worker {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::SeqCst);
        // Unblock a pending read.
        if let Some(s) = self.stream.lock().unwrap().take() {
            let _ = s.shutdown(Shutdown::Both);
        }
    }
}

pub struct ProbeSocketRust {
    path: QString,
    active: bool,
    connected: bool,
    json: QString,
    worker: Option<Worker>,
}

impl Default for ProbeSocketRust {
    fn default() -> Self {
        let dir = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
        Self {
            path: QString::from(&format!("{dir}/hudprobe.sock")),
            active: false,
            connected: false,
            json: QString::default(),
            worker: None,
        }
    }
}

impl cxx_qt::Initialize for qobject::ProbeSocket {
    fn initialize(mut self: Pin<&mut Self>) {
        self.as_mut().on_active_changed(|me| me.restart()).release();
        self.on_path_changed(|me| me.restart()).release();
    }
}

impl qobject::ProbeSocket {
    /// Stop any reader and, if active, start a fresh one on the current path.
    fn restart(mut self: Pin<&mut Self>) {
        self.as_mut().rust_mut().worker = None;
        if !*self.active() {
            self.as_mut().set_connected(false);
            return;
        }
        let path = self.path().to_string();
        let qt = self.qt_thread();
        let stop = Arc::new(AtomicBool::new(false));
        let stream = Arc::new(Mutex::new(None));
        self.as_mut().rust_mut().worker = Some(Worker { stop: stop.clone(), stream: stream.clone() });

        thread::spawn(move || {
            while !stop.load(Ordering::SeqCst) {
                if let Ok(s) = UnixStream::connect(&path) {
                    if let Ok(clone) = s.try_clone() {
                        *stream.lock().unwrap() = Some(clone);
                    }
                    if qt.queue(|me| me.set_connected(true)).is_err() {
                        return;
                    }
                    for line in BufReader::new(s).lines() {
                        let Ok(line) = line else { break };
                        if stop.load(Ordering::SeqCst) {
                            return;
                        }
                        if line.len() > MAX_LINE {
                            continue;
                        }
                        // Queued onto the Qt thread; fails only once the object is gone.
                        if qt.queue(move |me| me.set_json(QString::from(&line))).is_err() {
                            return;
                        }
                    }
                    if qt.queue(|me| me.set_connected(false)).is_err() {
                        return;
                    }
                }
                // Back off before reconnecting, waking early on stop.
                for _ in 0..20 {
                    if stop.load(Ordering::SeqCst) {
                        return;
                    }
                    thread::sleep(RETRY / 20);
                }
            }
        });
    }
}
