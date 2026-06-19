pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: launcherMenu

    property bool visible: false
    property var activeScreen: null
    property string searchText: ""
    property string activeCategory: "Alle Apps"

    property var appList: []
    property var customEntries: []
    property var sshHosts: []

    // ==========================================
    // Kategorien aus .desktop-Kategorien ableiten
    // ==========================================
    readonly property var categoryIcons: ({
        "Alle Apps":   "view-grid",
        "Internet":    "network-wireless",
        "Entwicklung": "applications-development",
        "Grafik":      "applications-graphics",
        "Multimedia":  "applications-multimedia",
        "System":      "applications-system",
        "Spiele":      "applications-games",
        "Sonstiges":   "applications-other"
    })

    readonly property var desktopToCategory: ({
        "Network":     "Internet",
        "WebBrowser":  "Internet",
        "Development": "Entwicklung",
        "IDE":         "Entwicklung",
        "Graphics":    "Grafik",
        "Photography": "Grafik",
        "Audio":       "Multimedia",
        "Video":       "Multimedia",
        "AudioVideo":  "Multimedia",
        "Game":        "Spiele",
        "System":      "System",
        "Settings":    "System",
        "Utility":     "System"
    })

    function show(screen) {
        activeScreen = screen;
        searchText = "";
        activeCategory = "Alle Apps";
        visible = true;
    }

    function hide() {
        visible = false;
        activeScreen = null;
    }

    function categoryForDesktopCategories(cats) {
        if (!cats) return "Sonstiges";
        var parts = cats.split(";");
        for (var i = 0; i < parts.length; i++) {
            var mapped = desktopToCategory[parts[i].trim()];
            if (mapped) return mapped;
        }
        return "Sonstiges";
    }

    // ==========================================
    // .desktop-Dateien einlesen
    // ==========================================
    Process {
        id: appLoader
        command: [
            "bash", "-c",
            "find /usr/share/applications ~/.local/share/applications -name '*.desktop' 2>/dev/null | xargs grep -l '^Type=Application' | while read f; do " +
            "name=$(grep '^Name=' \"$f\" | head -1 | cut -d= -f2-); " +
            "exec=$(grep '^Exec=' \"$f\" | head -1 | cut -d= -f2- | sed 's/ %[a-zA-Z]//g'); " +
            "icon=$(grep '^Icon=' \"$f\" | head -1 | cut -d= -f2-); " +
            "cats=$(grep '^Categories=' \"$f\" | head -1 | cut -d= -f2-); " +
            "nodisplay=$(grep '^NoDisplay=' \"$f\" | head -1 | cut -d= -f2-); " +
            "[ \"$nodisplay\" = 'true' ] && continue; " +
            "[ -z \"$name\" ] && continue; " +
            "echo \"$name|$exec|$icon|$cats\"; " +
            "done | sort -u"
        ]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = data.split("|");
                if (parts.length < 3) return;
                var apps = launcherMenu.appList.slice();
                apps.push({
                    name:     parts[0],
                    exec:     parts[1],
                    icon:     parts[2] || "application-x-executable",
                    category: launcherMenu.categoryForDesktopCategories(parts[3] || "")
                });
                launcherMenu.appList = apps;
            }
        }
    }

    // ==========================================
    // custom-entries.json laden
    // ==========================================
    FileView {
        id: customFile
        path: Qt.resolvedUrl("config/custom-entries.json")
        onTextChanged: {
            try {
                launcherMenu.customEntries = JSON.parse(customFile.text);
            } catch (e) {}
        }
    }

    // ==========================================
    // ssh-hosts.json laden
    // ==========================================
    FileView {
        id: sshFile
        path: Qt.resolvedUrl("config/ssh-hosts.json")
        onTextChanged: {
            try {
                launcherMenu.sshHosts = JSON.parse(sshFile.text);
            } catch (e) {}
        }
    }

    // ==========================================
    // Gefilterte App-Liste
    // ==========================================
    property var filteredApps: {
        var _apps = appList;
        var _search = searchText.toLowerCase();
        var _cat = activeCategory;
        return _apps.filter(function(app) {
            var matchesSearch = _search === "" || app.name.toLowerCase().indexOf(_search) !== -1;
            var matchesCat = _cat === "Alle Apps" || app.category === _cat;
            return matchesSearch && matchesCat;
        });
    }
}