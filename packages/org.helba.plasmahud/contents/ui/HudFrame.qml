import QtQuick
import QtQuick.Shapes

// Chamfered rectangle: the base shape of every surface in the HUD.
// Cut corners get a diagonal; uncut corners can carry short accent brackets.
Item {
    id: f

    property real cut: 10
    property bool cutTL: true
    property bool cutTR: false
    property bool cutBR: true
    property bool cutBL: false
    property color fill: "transparent"
    property color stroke: "white"
    property real strokeWidth: 1
    property real bracket: 0
    property color bracketColor: stroke
    property real bracketWidth: 2

    readonly property real _i: strokeWidth / 2
    readonly property real _w: width - _i
    readonly property real _h: height - _i

    readonly property var _outline: {
        const i = _i, w = _w, h = _h, c = cut;
        const p = [];
        p.push(Qt.point(cutTL ? i + c : i, i));
        p.push(Qt.point(cutTR ? w - c : w, i));
        if (cutTR) p.push(Qt.point(w, i + c));
        p.push(Qt.point(w, cutBR ? h - c : h));
        if (cutBR) p.push(Qt.point(w - c, h));
        p.push(Qt.point(cutBL ? i + c : i, h));
        if (cutBL) p.push(Qt.point(i, h - c));
        p.push(Qt.point(i, cutTL ? i + c : i));
        if (cutTL) p.push(Qt.point(i + c, i));
        return p;
    }

    readonly property var _brackets: {
        if (bracket <= 0) return [];
        const b = bracket, o = bracketWidth / 2, w = width - o, h = height - o;
        const out = [];
        if (!cutTL) out.push([Qt.point(o, b), Qt.point(o, o), Qt.point(b, o)]);
        if (!cutTR) out.push([Qt.point(w - b, o), Qt.point(w, o), Qt.point(w, b)]);
        if (!cutBR) out.push([Qt.point(w, h - b), Qt.point(w, h), Qt.point(w - b, h)]);
        if (!cutBL) out.push([Qt.point(b, h), Qt.point(o, h), Qt.point(o, h - b)]);
        return out;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: f.fill
            strokeColor: f.strokeWidth > 0 ? f.stroke : "transparent"
            strokeWidth: f.strokeWidth
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: f._outline }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: f.bracket > 0 ? f.bracketColor : "transparent"
            strokeWidth: f.bracketWidth
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            PathMultiline { paths: f._brackets }
        }
    }
}
