pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Выбирает «текущий» плеер: тот, что играет; иначе последний игравший.
// Обложку скачивает curl'ом в ~/.cache/qs-art (Qt иногда не может достучаться до CDN сам).
Singleton {
    id: root

    property var active: null
    function pick() {
        const list = Mpris.players.values;
        let p = null;
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying) { p = list[i]; break; }
        if (!p && active && list.indexOf(active) >= 0) p = active;
        if (!p && list.length > 0) p = list[0];
        if (p !== active) active = p;
    }
    Timer { interval: 500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.pick() }

    // ── обложка
    readonly property string artUrl: active?.trackArtUrl ?? ""
    property string artFile: ""
    onArtUrlChanged: fetchArt()

    function normalize(u) {
        if (u.startsWith("spotify:image:")) u = "https://i.scdn.co/image/" + u.slice(14);
        u = u.replace("://open.spotify.com/image/", "://i.scdn.co/image/");
        if (u.startsWith("http://")) u = "https://" + u.slice(7);
        return u;
    }
    function fetchArt() {
        const u = normalize(artUrl);
        if (u === "") { artFile = ""; return; }
        if (u.startsWith("file://")) { artFile = u; return; }
        artProc.running = false;
        artProc.command = ["sh", "-c",
            'f="$HOME/.cache/qs-art/$(printf %s "$1" | md5sum | cut -c1-16)"; mkdir -p "$HOME/.cache/qs-art"; '
            + '[ -s "$f" ] || curl -fsSL --max-time 10 -o "$f" "$1"; [ -s "$f" ] && printf %s "$f"',
            "_", u];
        artProc.running = true;
    }
    Process {
        id: artProc
        stdout: StdioCollector {
            onStreamFinished: root.artFile = text.trim() !== "" ? "file://" + text.trim() : ""
        }
    }
    function art(p) { return p === active ? artFile : ""; }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0;
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
