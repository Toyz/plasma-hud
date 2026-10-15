pragma Singleton
import QtQuick

// The typed password, shared by every screen's lock screen (one QML engine), so
// typing on any monitor fills the field on all of them.
QtObject {
    property string text: ""
}
