import QtQuick
import qs.Common

Canvas {
    id: root

    property real amplitudeMultiplier: 0.5
    property real frequency: 6
    property color color: Appearance.colors.colPrimary
    property real lineWidth: 4
    property real fullLength: width

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const amplitude = root.lineWidth * root.amplitudeMultiplier;
        const phase = Date.now() / 400.0;
        const centerY = height / 2;

        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.beginPath();

        for (let x = ctx.lineWidth / 2; x <= root.width - ctx.lineWidth / 2; x += 1) {
            const waveY = centerY + amplitude * Math.sin(root.frequency * 2 * Math.PI * x / root.fullLength + phase);
            if (x === ctx.lineWidth / 2)
                ctx.moveTo(x, waveY);
            else
                ctx.lineTo(x, waveY);
        }

        ctx.stroke();
    }
}
