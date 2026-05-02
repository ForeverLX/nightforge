.pragma library

function getScale(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }

    if (mw <= 0 || mh <= 0) return 1.0;

    let rw = mw / 1920.0;
    let rh = mh / 1080.0;
    let r = Math.min(rw, rh);

    let baseScale = 1.0;

    if (r <= 1.0) {
        baseScale = Math.max(0.35, Math.pow(r, 0.85));
    } else {
        baseScale = Math.pow(r, 0.5);
    }

    return baseScale * (userScale !== undefined ? userScale : 1.0);
}

function s(val, scale) {
    return Math.round(val * scale);
}

function getLayout(name, mx, my, mw, mh, userScale) {
    let scale = getScale(mw, mh, userScale);

    let base = {
        "controlcenter":   { w: s(450, scale), h: mh, rx: mw - s(450, scale), ry: 0, comp: "modules/ControlCenter.qml" },
        "music":     { w: s(700, scale), h: s(650, scale), rx: s(5, scale), ry: s(60, scale), comp: "modules/MusicPopup.qml" },
        "wallpaper": { w: mw, h: s(650, scale), rx: 0, ry: Math.floor((mh/2)-(s(650, scale)/2)), comp: "modules/WallpaperPicker.qml" },
        "hidden":    { w: 1, h: 1, rx: -5000 - mx, ry: -5000 - my, comp: "" }
    };

    if (!base[name]) return null;

    let t = base[name];
    t.x = mx + t.rx;
    t.y = my + t.ry;

    return t;
}