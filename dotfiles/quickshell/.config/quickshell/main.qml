// Quickshell - NightForge Modular Shell Entry Point
// Uses project-root services and modules
// Requires: quickshell, matugen, niri

import QtQuick
import Quickshell
import "../../../../services"
import "../../../../modules"

Scope {
    id: root

    // === BAR ===
    Bar {}
}
