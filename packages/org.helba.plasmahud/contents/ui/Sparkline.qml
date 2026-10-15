import QtQuick

// Scrolling trace with a faint grid, gradient fill and glowing head.
Canvas {
    id: c

    property var values: []
    property var values2: []
    property real maxValue: 100      // <= 0 means auto-scale
    property int capacity: 90
    property color color: "#00f0ff"
    property color color2: "#ff2a6d"
    property real glow: 0.7
    readonly property real scaleMax: _max()

    renderTarget: Canvas.FramebufferObject
    onValuesChanged: requestPaint()
    onValues2Changed: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function _max() {
        if (maxValue > 0) return maxValue;
        let m = 1;
        for (const v of values) m = Math.max(m, v);
        for (const v of values2) m = Math.max(m, v);
        return m * 1.2;
    }

    function css(col, a) {
        return "rgba(" + Math.round(col.r * 255) + "," + Math.round(col.g * 255) + ","
            + Math.round(col.b * 255) + "," + a + ")";
    }

    function series(ctx, data, col, fillArea) {
        if (!data || data.length < 2) return;
        const w = width, h = height - 2, max = scaleMax;
        const step = w / (capacity - 1);
        const x0 = w - (data.length - 1) * step;
        const yOf = v => 1 + h - Math.min(1, Math.max(0, v / max)) * h;

        ctx.beginPath();
        ctx.moveTo(x0, yOf(data[0]));
        for (let i = 1; i < data.length; i++) ctx.lineTo(x0 + i * step, yOf(data[i]));

        if (fillArea) {
            ctx.save();
            ctx.lineTo(w, height);
            ctx.lineTo(x0, height);
            ctx.closePath();
            const grad = ctx.createLinearGradient(0, 0, 0, height);
            grad.addColorStop(0, css(col, 0.32));
            grad.addColorStop(1, css(col, 0.0));
            ctx.fillStyle = grad;
            ctx.fill();
            ctx.restore();
            ctx.beginPath();
            ctx.moveTo(x0, yOf(data[0]));
            for (let i = 1; i < data.length; i++) ctx.lineTo(x0 + i * step, yOf(data[i]));
        }

        ctx.lineWidth = 1.5;
        ctx.strokeStyle = css(col, 0.95);
        ctx.shadowColor = css(col, glow);
        ctx.shadowBlur = 8 * glow;
        ctx.stroke();
        ctx.shadowBlur = 0;

        const hx = w - 1.5, hy = yOf(data[data.length - 1]);
        ctx.fillStyle = css(col, 1);
        ctx.fillRect(hx - 2, hy - 2, 4, 4);
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width, h = height;

        ctx.lineWidth = 1;
        ctx.strokeStyle = css(color, 0.07);
        ctx.beginPath();
        for (let i = 1; i < 12; i++) {
            const x = Math.round(w * i / 12) + 0.5;
            ctx.moveTo(x, 0);
            ctx.lineTo(x, h);
        }
        for (let j = 1; j < 4; j++) {
            const y = Math.round(h * j / 4) + 0.5;
            ctx.moveTo(0, y);
            ctx.lineTo(w, y);
        }
        ctx.stroke();

        series(ctx, values2, color2, false);
        series(ctx, values, color, true);
    }
}
