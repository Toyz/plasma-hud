import QtQuick

// Live system pulse instead of numbers: CPU is an EKG trace whose color heats with the
// CPU temperature, GPU load is a glowing band underneath, memory is a waterline.
// Hovering swaps the trace for the numbers.
Item {
    id: pulse

    required property QtObject hud
    property real size: 26
    property int samples: 48
    signal clicked

    implicitWidth: Math.round(size * 5.6)
    implicitHeight: size

    readonly property color heat: hud.cpuTemp >= 85 ? hud.crit : hud.cpuTemp >= 72 ? hud.warn : hud.cyan

    Canvas {
        id: trace
        anchors.fill: parent
        opacity: ma.containsMouse ? 0.12 : 1
        Behavior on opacity { NumberAnimation { duration: 160 } }
        renderTarget: Canvas.FramebufferObject

        property var cpu: pulse.hud.cpuHist
        onCpuChanged: requestPaint()
        onWidthChanged: requestPaint()

        function tail(a) { return a.slice(Math.max(0, a.length - pulse.samples)); }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, pad = 2;
            const H = pulse.hud;
            const cpu = tail(H.cpuHist), gpu = tail(H.gpuHist), mem = tail(H.memHist);
            const step = w / (pulse.samples - 1);
            const x0 = w - (cpu.length - 1) * step;
            // Adaptive range: follow recent peaks (floor 20%) so idle still has texture.
            let peak = 20;
            for (const v of cpu) peak = Math.max(peak, v * 1.25);
            for (const v of gpu) peak = Math.max(peak, v * 1.25);
            peak = Math.min(100, peak);
            const y = v => pad + (h - pad * 2) * (1 - Math.max(0, Math.min(peak, v)) / peak);
            const yAbs = v => pad + (h - pad * 2) * (1 - Math.max(0, Math.min(100, v)) / 100);

            // Memory waterline.
            if (mem.length) {
                const my = Math.round(yAbs(mem[mem.length - 1])) + 0.5;
                ctx.strokeStyle = H.css(H.inkDim, 0.6);
                ctx.lineWidth = 1;
                ctx.setLineDash([2, 3]);
                ctx.beginPath(); ctx.moveTo(0, my); ctx.lineTo(w, my); ctx.stroke();
                ctx.setLineDash([]);
            }

            // GPU band.
            if (gpu.length > 1) {
                const gx0 = w - (gpu.length - 1) * step;
                ctx.beginPath();
                ctx.moveTo(gx0, h);
                for (let i = 0; i < gpu.length; i++) ctx.lineTo(gx0 + i * step, y(gpu[i]));
                ctx.lineTo(w, h);
                ctx.closePath();
                const g = ctx.createLinearGradient(0, 0, 0, h);
                g.addColorStop(0, H.css(H.gold, 0.4));
                g.addColorStop(1, H.css(H.gold, 0.02));
                ctx.fillStyle = g;
                ctx.fill();
            }

            // CPU trace, EKG style: sharp segments, glowing head.
            if (cpu.length > 1) {
                ctx.beginPath();
                ctx.moveTo(x0, y(cpu[0]));
                for (let i = 1; i < cpu.length; i++) ctx.lineTo(x0 + i * step, y(cpu[i]));
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = H.css(pulse.heat, 0.95);
                ctx.shadowColor = H.css(pulse.heat, 0.9);
                ctx.shadowBlur = 6;
                ctx.stroke();
                ctx.shadowBlur = 0;
                const hy = y(cpu[cpu.length - 1]);
                ctx.fillStyle = H.css(pulse.heat, 1);
                ctx.beginPath(); ctx.arc(w - 2, hy, 2, 0, Math.PI * 2); ctx.fill();
            }
        }
    }

    // Numbers on hover.
    Row {
        anchors.centerIn: parent
        spacing: 8
        opacity: ma.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        component Num: Text {
            property string tag
            property real v
            property color tone: pulse.hud.text
            text: tag + " " + pulse.hud.pad3(v)
            color: tone
            font.family: pulse.hud.serifFont
            font.pixelSize: Math.round(pulse.size * 0.46)
            font.weight: Font.Medium
        }
        Num { tag: "C"; v: pulse.hud.cpu; tone: pulse.heat }
        Num { tag: "G"; v: pulse.hud.gpu; tone: pulse.hud.gold }
        Num { tag: "M"; v: pulse.hud.mem }
        Text {
            anchors.baseline: parent.children[0].baseline
            text: Math.round(pulse.hud.cpuTemp) + "°"
            color: pulse.heat
            font.family: pulse.hud.monoFont
            font.pixelSize: Math.round(pulse.size * 0.36)
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pulse.clicked()
    }
}
