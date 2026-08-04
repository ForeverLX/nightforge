package niri

// NightForge Niri configuration schema (CUE migration).
//
// Covers the structured, operator-edited sections of the Niri config:
// spawn-at-startup, keybinds, and window rules. Static sections
// (layout, input, compositor, colors) stay as untouched KDL includes —
// see docs/CUE-MIGRATION.md for the boundary decision.
//
// This schema is the single source of truth; generated KDL must match
// the semantics of the original configs (verified by fidelity-check).

#Config: {
	spawnAtStartup: [...#Spawn]
	binds: [...#Bind]
	windowRules: [...#WindowRule]
}

// ---- spawn-at-startup -------------------------------------------------

#Spawn: {
	// argv: program + arguments, non-empty.
	argv: [string, ...string]
	comment?: string
}

// ---- keybinds ---------------------------------------------------------

#Bind: {
	// combo: niri key combination, e.g. "Mod+Shift+S".
	combo:  string
	action: #Action
	// allowWhenLocked: whether the bind works on the lock screen.
	allowWhenLocked?: bool
	// repeat: whether holding the key repeats (default true in niri).
	repeat?: bool
	// hotkeyOverlayTitle: label shown in the hotkey overlay.
	hotkeyOverlayTitle?: string
	comment?:            string
}

#Action: #SpawnAction | #BuiltinAction

#SpawnAction: {
	kind: "spawn"
	argv: [string, ...string]
}

#BuiltinAction: {
	kind: "builtin"
	// name: niri action name, e.g. "focus-column-left".
	name: string
	// arg: optional string argument, e.g. workspace name or width delta.
	arg?: string
}

// ---- window rules -----------------------------------------------------

#WindowRule: {
	// appId/title: regex matched against the window (niri "match").
	appId?:                string
	title?:                string
	opacity?:              number
	openFloating?:         bool
	openFullscreen?:       bool
	clipToGeometry?:       bool
	geometryCornerRadius?: int
	maxWidth?:             int
	maxHeight?:            int
	blockOutFrom?:         string
	defaultColumnWidth?:   #Width
	defaultWindowHeight?:  #Height
	comment?:              string
}

#Width:  #Proportion | #Fixed
#Height: #Proportion | #Fixed

#Proportion: {
	proportion: number
}

#Fixed: {
	fixed: int
}
