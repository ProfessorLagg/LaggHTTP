// FPS
{
let fps = -1;
let dt = -1;
let lastFrameTimestamp = 0;
let showFps = false;
let lastFpsDisplayUpdate = 0;
function fpsUpdate(timestamp) {
    if (!showFps) { return }
    dt = timestamp - lastFrameTimestamp;
    fps = 1000 / dt;
    lastFrameTimestamp = timestamp;
    if ((timestamp - lastFpsDisplayUpdate) >= 1000) {
        const mul = Math.pow(10, Math.max(0, 3));
        const _fps = Math.round(fps * mul) / mul;
        document.getElementById('fps-display').innerText = _fps + " FPS";
        lastFpsDisplayUpdate = timestamp;
    }

    requestAnimationFrame(fpsUpdate);
}
function toggleFPS() {
    if (showFps) {
        document.getElementById('fps-display').remove();
        showFps = false;
        lastFpsDisplayUpdate = 0;
    } else {
        fpsElem = document.createElement("span")
        fpsElem.id = "fps-display";
        fpsElem.style = "position: absolute;left: 0;top: 0;color: rgb(0, 255, 0);font-family: monospace;font-size: 3vh;z-index: 999"
        document.body.appendChild(fpsElem);
        showFps = true;
        requestAnimationFrame(fpsUpdate);
    }
}
}