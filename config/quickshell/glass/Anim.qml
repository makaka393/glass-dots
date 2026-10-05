import QtQuick

// NumberAnimation с кривыми M3 Expressive.
// kind: "spatial" (пружинка, 500мс), "fast" (резкая пружинка, 350мс), "effects" (без отскока, 220мс)
NumberAnimation {
    property string kind: "spatial"
    duration: kind === "fast" ? Theme.durFast : kind === "effects" ? Theme.durEffects : Theme.durSpatial
    easing.type: Easing.BezierSpline
    easing.bezierCurve: kind === "fast" ? Theme.spatialFast : kind === "effects" ? Theme.effects : Theme.spatial
}
