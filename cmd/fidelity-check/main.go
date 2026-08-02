// fidelity-check — verify generated KDL matches the source KDL semantics.
//
// Go port of scripts/fidelity-check.py (S187). Phase 3 verification: the
// CUE-generated staging config must be semantically identical to the tracked
// source config for the migrated sections. Compares canonical structures
// parsed from both trees:
//
//   - spawn-at-startup: (argv tokens)
//   - keybinds:         (combo, flags, action) where action is
//     ("spawn", tokens) or ("builtin", name, arg|None)
//   - window-rules:     (match pairs, sorted properties)
//
// Canonical entries are encoded as Python-style repr strings (the same
// strings the original script compared), so set equality is exact and any
// drift output is readable.
//
// Usage:
//
//	fidelity-check [--staging DIR]   (default: build/niri-staging/)
//
// Exits 0 when source and generated match, 1 listing any drift.
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/ForeverLX/nightforge/internal/nfutil"
)

var (
	kdlTokRe      = regexp.MustCompile(`"[^"]*"|[^\s"]+`)
	strRe         = regexp.MustCompile(`"((?:[^"\\]|\\.)*)"`)
	numRe         = regexp.MustCompile(`^-?\d+(\.\d+)?$`)
	matchClauseRe = regexp.MustCompile(`((?:app-id|title))=r#"`)
	widthLineRe   = regexp.MustCompile(`^(default-column-width|default-window-height) \{ (proportion|fixed) ([-\d.]+); \}$`)
)

var errDrift = errors.New("generated artifacts drift from source semantics")

// ---- Python-style repr helpers (canonical encodings) -------------------

// pyStr is Python's str()/repr() of a plain string: single-quoted.
func pyStr(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `'`, `\'`)
	return "'" + s + "'"
}

// pyFloat is Python's repr() of a float: shortest round-trip, integral
// values keep a trailing ".0" (repr(400.0) == '400.0').
func pyFloat(f float64) string {
	if math.Trunc(f) == f && math.Abs(f) < 1e16 {
		return strconv.FormatFloat(f, 'f', 1, 64)
	}
	return strconv.FormatFloat(f, 'g', -1, 64)
}

// tupleStr is Python's repr of a tuple: ('a', 'b'), ('a',) for one element.
func tupleStr(elems []string) string {
	switch len(elems) {
	case 0:
		return "()"
	case 1:
		return "(" + elems[0] + ",)"
	default:
		return "(" + strings.Join(elems, ", ") + ")"
	}
}

func quoteAll(ss []string) []string {
	out := make([]string, len(ss))
	for i, s := range ss {
		out[i] = pyStr(s)
	}
	return out
}

// ---- source parsing ----------------------------------------------------

// stripComments removes // line comments, but only outside double-quoted
// strings (so URLs like obsidian://daily survive).
func stripComments(text string) string {
	lines := strings.Split(text, "\n")
	out := make([]string, 0, len(lines))
	for _, line := range lines {
		inStr := false
		cut := -1
		for i := 0; i < len(line); i++ {
			switch {
			case line[i] == '"' && (i == 0 || line[i-1] != '\\'):
				inStr = !inStr
			case line[i] == '/' && !inStr && strings.HasPrefix(line[i:], "//"):
				cut = i
			}
			if cut >= 0 {
				break
			}
		}
		if cut >= 0 {
			out = append(out, line[:cut])
		} else {
			out = append(out, line)
		}
	}
	return strings.Join(out, "\n")
}

// kdlTokens whitespace-splits, keeping double-quoted segments intact.
func kdlTokens(s string) []string { return kdlTokRe.FindAllString(s, -1) }

// parseStrs extracts double-quoted string contents from a KDL statement.
func parseStrs(s string) []string {
	ms := strRe.FindAllStringSubmatch(s, -1)
	out := make([]string, 0, len(ms))
	for _, m := range ms {
		out = append(out, m[1])
	}
	return out
}

func readSource(root, rel string) (string, error) {
	b, err := os.ReadFile(filepath.Join(root, "dotfiles", "niri", ".config", "niri", rel))
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// srcSpawns: lines of config.kdl starting with "spawn-at-startup ".
func srcSpawns(root string) ([]string, error) {
	text, err := readSource(root, "config.kdl")
	if err != nil {
		return nil, err
	}
	var out []string
	for _, line := range strings.Split(stripComments(text), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "spawn-at-startup ") {
			out = append(out, tupleStr(quoteAll(parseStrs(line))))
		}
	}
	return out, nil
}

// flag is one normalized bind flag: (key, value) or (key, bare=true).
type flag struct {
	k, v string
	bare bool
}

func (f flag) key() string {
	if f.bare {
		return "(" + pyStr(f.k) + ", True)"
	}
	return "(" + pyStr(f.k) + ", " + pyStr(f.v) + ")"
}

func flagsKey(flags []flag) string {
	if len(flags) == 0 {
		return "frozenset()"
	}
	ss := make([]string, len(flags))
	for i, f := range flags {
		ss[i] = f.key()
	}
	sort.Strings(ss)
	return "frozenset({" + strings.Join(ss, ", ") + "})"
}

// normFlags canonicalizes tokens after the combo: merges `key=` + `"value"`
// pairs (Python's frozenset of (key, value) tuples).
func normFlags(tokens []string) []flag {
	var flags []flag
	for i := 0; i < len(tokens); {
		t := tokens[i]
		switch {
		case strings.HasSuffix(t, "=") && i+1 < len(tokens) && strings.HasPrefix(tokens[i+1], `"`):
			flags = append(flags, flag{k: t[:len(t)-1], v: tokens[i+1][1 : len(tokens[i+1])-1]})
			i += 2
		case strings.Contains(t, "="):
			kv := strings.SplitN(t, "=", 2)
			flags = append(flags, flag{k: kv[0], v: strings.Trim(kv[1], `"`)})
			i++
		default:
			flags = append(flags, flag{k: t, bare: true})
			i++
		}
	}
	return flags
}

// parseBind parses one binds-block line -> canonical (combo, flags, action).
func parseBind(line string) (string, error) {
	open := strings.Index(line, "{")
	close := strings.LastIndex(line, "}")
	if open < 0 || close < 0 {
		return "", fmt.Errorf("malformed binds line: %q", line)
	}
	head := line[:open]
	rest := line[open+1:]
	combos := kdlTokens(head)
	if len(combos) == 0 {
		return "", fmt.Errorf("malformed binds line: %q", line)
	}
	combo := combos[0]
	flags := normFlags(combos[1:])

	body := strings.TrimSpace(rest[:close-open-1])
	actionBody := strings.TrimSpace(strings.TrimRight(body, ";"))
	var action string
	if strings.HasPrefix(actionBody, "spawn") {
		action = "('spawn', " + tupleStr(quoteAll(parseStrs(actionBody))) + ")"
	} else {
		parts := strings.SplitN(actionBody, " ", 2)
		if len(parts) == 0 || parts[0] == "" {
			return "", fmt.Errorf("malformed binds line: %q", line)
		}
		arg := "None"
		if len(parts) > 1 {
			ps := parseStrs(parts[1])
			if len(ps) == 0 {
				return "", fmt.Errorf("builtin arg not quoted in: %q", line)
			}
			arg = pyStr(ps[0])
		}
		action = "('builtin', " + pyStr(parts[0]) + ", " + arg + ")"
	}
	return "(" + pyStr(combo) + ", " + flagsKey(flags) + ", " + action + ")", nil
}

// srcBinds: the binds { ... } block of includes/keybinds.kdl.
func srcBinds(root string) ([]string, error) {
	text, err := readSource(root, "includes/keybinds.kdl")
	if err != nil {
		return nil, err
	}
	var out []string
	inBinds := false
	for _, line := range strings.Split(stripComments(text), "\n") {
		s := strings.TrimSpace(line)
		if s == "" {
			continue
		}
		if s == "binds {" {
			inBinds = true
			continue
		}
		if !inBinds {
			continue
		}
		if s == "}" {
			break
		}
		key, err := parseBind(s)
		if err != nil {
			return nil, err
		}
		out = append(out, key)
	}
	return out, nil
}

// normValue canonicalizes a property value: numbers numerically, strings
// unquoted (Python norm_value).
func normValue(v string) string {
	v = strings.TrimSpace(v)
	if numRe.MatchString(v) {
		f, _ := strconv.ParseFloat(v, 64)
		return pyFloat(f)
	}
	if strings.HasPrefix(v, `"`) && strings.HasSuffix(v, `"`) && len(v) >= 2 {
		return pyStr(v[1 : len(v)-1])
	}
	return pyStr(v)
}

// extractMatches finds (app-id|title)=r#"..."# clauses anywhere in a line
// (a generated rule may carry two match clauses on one line). A clause ends
// at the first `"#` after r#" — the RE2-safe equivalent of the original
// lookahead-based regex.
func extractMatches(s string) ([]string, bool) {
	idxs := matchClauseRe.FindAllStringSubmatchIndex(s, -1)
	var pairs []string
	for _, ix := range idxs {
		name := s[ix[2]:ix[3]]
		end := -1
		for j := ix[1]; j+1 < len(s); j++ {
			if s[j] == '"' && s[j+1] == '#' {
				end = j
				break
			}
		}
		if end < 0 {
			continue
		}
		pairs = append(pairs, "("+pyStr(name)+", "+pyStr(s[ix[1]:end])+")")
	}
	return pairs, len(pairs) > 0
}

// parseRuleBlock canonicalizes one window-rule block body. Sorted match
// pairs, then properties sorted by their canonical (Python str) form.
func parseRuleBlock(lines []string) string {
	var matchPairs, props []string
	for _, line := range lines {
		s := strings.TrimSpace(line)
		if s == "" {
			continue
		}
		if pairs, ok := extractMatches(s); ok {
			matchPairs = append(matchPairs, pairs...)
			continue
		}
		if m := widthLineRe.FindStringSubmatch(s); m != nil {
			f, _ := strconv.ParseFloat(m[3], 64)
			props = append(props, "("+pyStr(m[1])+", ("+pyStr(m[2])+", "+pyFloat(f)+"))")
			continue
		}
		parts := strings.SplitN(s, " ", 2)
		if len(parts) == 2 {
			props = append(props, "("+pyStr(parts[0])+", "+normValue(parts[1])+")")
		} else {
			props = append(props, "("+pyStr(parts[0])+", True)")
		}
	}
	sort.Strings(matchPairs)
	sort.Strings(props)
	return tupleStr([]string{tupleStr(matchPairs), tupleStr(props)})
}

// parseRulesFile splits includes/window-rules.kdl into rule blocks.
func parseRulesFile(text string) []string {
	var out []string
	depth := 0
	var buf []string
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if line == "window-rule {" {
			depth, buf = 1, nil
			continue
		}
		if depth > 0 {
			if line == "}" {
				out = append(out, parseRuleBlock(buf))
				depth = 0
			} else {
				buf = append(buf, line)
			}
		}
	}
	return out
}

func srcRules(root string) ([]string, error) {
	text, err := readSource(root, "includes/window-rules.kdl")
	if err != nil {
		return nil, err
	}
	return parseRulesFile(stripComments(text)), nil
}

// ---- generated (same canonical forms) ----------------------------------

func genSpawns(cfg nfutil.Config) []string {
	out := make([]string, 0, len(cfg.SpawnAtStartup))
	for _, s := range cfg.SpawnAtStartup {
		out = append(out, tupleStr(quoteAll(s.Argv)))
	}
	return out
}

func genBinds(cfg nfutil.Config) []string {
	out := make([]string, 0, len(cfg.Binds))
	for _, b := range cfg.Binds {
		var flags []flag
		if b.AllowWhenLocked != nil && *b.AllowWhenLocked {
			flags = append(flags, flag{k: "allow-when-locked", v: "true"})
		}
		if b.Repeat != nil && !*b.Repeat {
			flags = append(flags, flag{k: "repeat", v: "false"})
		}
		if b.HotkeyOverlayTitle != nil {
			flags = append(flags, flag{k: "hotkey-overlay-title", v: *b.HotkeyOverlayTitle})
		}
		var action string
		if b.Action.Kind == "spawn" {
			action = "('spawn', " + tupleStr(quoteAll(b.Action.Argv)) + ")"
		} else {
			arg := "None"
			if b.Action.Arg != nil {
				arg = pyStr(*b.Action.Arg)
			}
			action = "('builtin', " + pyStr(b.Action.Name) + ", " + arg + ")"
		}
		out = append(out, "("+pyStr(b.Combo)+", "+flagsKey(flags)+", "+action+")")
	}
	return out
}

func genRules(cfg nfutil.Config) []string {
	out := make([]string, 0, len(cfg.WindowRules))
	for _, r := range cfg.WindowRules {
		var matchPairs []string
		if r.AppID != nil {
			matchPairs = append(matchPairs, "("+pyStr("app-id")+", "+pyStr(*r.AppID)+")")
		}
		if r.Title != nil {
			matchPairs = append(matchPairs, "("+pyStr("title")+", "+pyStr(*r.Title)+")")
		}
		sort.Strings(matchPairs)

		var props []string
		addNum := func(name string, v *json.Number) {
			if v != nil {
				f, _ := v.Float64()
				props = append(props, "("+pyStr(name)+", "+pyFloat(f)+")")
			}
		}
		addBool := func(name string, v *bool) {
			if v != nil {
				s := "false"
				if *v {
					s = "true"
				}
				props = append(props, "("+pyStr(name)+", "+pyStr(s)+")")
			}
		}
		addStr := func(name string, v *string) {
			if v != nil {
				props = append(props, "("+pyStr(name)+", "+pyStr(*v)+")")
			}
		}
		addNum("geometry-corner-radius", r.GeometryCornerRadius)
		addBool("clip-to-geometry", r.ClipToGeometry)
		addBool("open-floating", r.OpenFloating)
		addBool("open-fullscreen", r.OpenFullscreen)
		addNum("opacity", r.Opacity)
		addNum("max-width", r.MaxWidth)
		addNum("max-height", r.MaxHeight)
		addStr("block-out-from", r.BlockOutFrom)
		for _, w := range []struct {
			name string
			w    *nfutil.Width
		}{
			{"default-column-width", r.DefaultColumnWidth},
			{"default-window-height", r.DefaultWindowHeight},
		} {
			if w.w == nil {
				continue
			}
			kind := "proportion"
			val := w.w.Proportion
			if val == nil {
				kind, val = "fixed", w.w.Fixed
			}
			f, _ := val.Float64()
			props = append(props, "("+pyStr(w.name)+", ("+pyStr(kind)+", "+pyFloat(f)+"))")
		}
		sort.Strings(props)
		out = append(out, tupleStr([]string{tupleStr(matchPairs), tupleStr(props)}))
	}
	return out
}

// diff prints the per-section comparison; returns false on any drift.
func diff(label string, src, gen []string) bool {
	srcSet := make(map[string]struct{}, len(src))
	genSet := make(map[string]struct{}, len(gen))
	for _, k := range src {
		srcSet[k] = struct{}{}
	}
	for _, k := range gen {
		genSet[k] = struct{}{}
	}
	fmt.Printf("== %s: source=%d generated=%d\n", label, len(src), len(gen))
	var missing, extra []string
	for k := range srcSet {
		if _, ok := genSet[k]; !ok {
			missing = append(missing, k)
		}
	}
	for k := range genSet {
		if _, ok := srcSet[k]; !ok {
			extra = append(extra, k)
		}
	}
	sort.Strings(missing)
	sort.Strings(extra)
	ok := true
	if len(missing) > 0 {
		ok = false
		fmt.Printf("  MISSING from generated (%d):\n", len(missing))
		for _, item := range missing {
			fmt.Printf("    - %s\n", item)
		}
	}
	if len(extra) > 0 {
		ok = false
		fmt.Printf("  EXTRA in generated (%d):\n", len(extra))
		for _, item := range extra {
			fmt.Printf("    + %s\n", item)
		}
	}
	return ok
}

func run() error {
	root, err := nfutil.RepoRoot()
	if err != nil {
		return err
	}

	staging := filepath.Join(root, "build", "niri-staging")
	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		if args[i] == "--staging" {
			if i+1 >= len(args) {
				return fmt.Errorf("--staging requires a directory argument")
			}
			abs, err := filepath.Abs(args[i+1])
			if err != nil {
				return err
			}
			staging = abs
			i++
		}
	}
	_ = staging // source of truth for fidelity is dotfiles/, not staging.

	cfg, err := nfutil.ExportConfig(root)
	if err != nil {
		return err
	}

	srcS, err := srcSpawns(root)
	if err != nil {
		return err
	}
	srcB, err := srcBinds(root)
	if err != nil {
		return err
	}
	srcR, err := srcRules(root)
	if err != nil {
		return err
	}

	pairs := []struct {
		label   string
		src, gen []string
	}{
		{"spawn-at-startup", srcS, genSpawns(cfg)},
		{"keybinds", srcB, genBinds(cfg)},
		{"window-rules", srcR, genRules(cfg)},
	}

	ok := true
	for _, p := range pairs {
		if !diff(p.label, p.src, p.gen) {
			ok = false
		}
	}
	if !ok {
		fmt.Fprintln(os.Stderr, "\nERROR: generated artifacts drift from source semantics.")
		return errDrift
	}
	total := 0
	for _, p := range pairs {
		total += len(p.src)
	}
	fmt.Printf("\nOK: %d canonical entries match source semantics exactly.\n", total)
	return nil
}

func main() {
	if err := run(); err != nil {
		if !errors.Is(err, errDrift) {
			fmt.Fprintln(os.Stderr, "fidelity-check:", err)
		}
		os.Exit(1)
	}
}
