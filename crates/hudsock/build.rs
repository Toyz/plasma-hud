use cxx_qt_build::{CxxQtBuilder, PluginType, QmlModule};

fn main() {
    let builder = CxxQtBuilder::new_qml_module(QmlModule::new("org.helba.hud").plugin_type(PluginType::Dynamic))
        .file("src/lib.rs");
    // A Rust cdylib only exports Rust symbols, so moc's C plugin entry points would be
    // hidden. Rename them here; src/plugin.rs re-exports the real names from Rust.
    // SAFETY: only adds preprocessor defines to the generated C++.
    let builder = unsafe {
        builder.cc_builder(|cc| {
            cc.define("qt_plugin_instance", "hudsock_qt_plugin_instance");
            cc.define("qt_plugin_query_metadata_v2", "hudsock_qt_plugin_query_metadata_v2");
        })
    };
    builder.build();
}
