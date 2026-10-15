//! Re-export the Qt plugin entry points that moc generated under renamed symbols
//! (see build.rs), so QPluginLoader finds them in this cdylib.

use std::ffi::c_void;

/// Mirrors `QPluginMetaData { const uchar *data; size_t size; }`.
#[repr(C)]
pub struct QPluginMetaData {
    data: *const u8,
    size: usize,
}

extern "C" {
    fn hudsock_qt_plugin_instance() -> *mut c_void;
    fn hudsock_qt_plugin_query_metadata_v2() -> QPluginMetaData;
}

#[no_mangle]
pub extern "C" fn qt_plugin_instance() -> *mut c_void {
    // SAFETY: moc-generated, takes no arguments and returns the plugin singleton.
    unsafe { hudsock_qt_plugin_instance() }
}

#[no_mangle]
pub extern "C" fn qt_plugin_query_metadata_v2() -> QPluginMetaData {
    // SAFETY: moc-generated, returns pointers into static plugin metadata.
    unsafe { hudsock_qt_plugin_query_metadata_v2() }
}
