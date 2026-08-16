// Command m3tid runs the CTID M3TID maturity assessment against the current
// CR1MS0N stack (C4 + Lantern + Veil) and writes the machine-readable result
// to data/tid/m3tid.json, which the harnessd "TID Maturity" tab serves.
//
// The assessment encodes the satisfied maturity levels per component (official
// scoring: L1/L2 = 1pt, L3/L4 = 2pt, cumulative, max 6). Re-run after the
// stack changes to refresh the score:
//
//	go run ./cmd/m3tid
//
// Env:
//
//	NIGHTFORGE_ROOT   override the output root (default ~/Github/nightforge)
package main

import (
	"fmt"
	"log"

	"github.com/ForeverLX/nightforge/internal/m3tid"
)

func main() {
	a := m3tid.Assessment{
		Framework:        "M3TID",
		FrameworkVersion: "1.0.0",
		FrameworkRef:     "https://ctid.mitre.org/projects/measure-maximize-and-mature-threat-informed-defense-m3tid/",
		AssessedDate:     "2026-08-08",
		AssessedBy:       "harness",
		Scope:            []string{"c4", "lantern", "veil"},
		Dimensions: []m3tid.Dimension{
			{
				ID: "CTI", Name: "Cyber Threat Intelligence", Weight: 0.3,
				Components: []m3tid.Component{
					{
						ID: "I.1", Name: "Depth of Threat Data", LevelsMet: []int{1, 2, 3},
						Evidence: []string{
							"veil:README.md (Internet Threat Hunting — IOC-level tracking via Suricata/Cowrie)",
							"veil:docs/nightforge-shield.md (scoring weights: suricata_exploit/c2/scan, cowrie_login)",
							"lantern:README.md (MITRE ATT&CK mapping per finding: T1078.002, T1098, T1484, T1558.003, T1552)",
							"nightforge:README.md (operator terminal: `mitre log T1059.004` technique logging)",
						},
						Note: "IOC/tool/technique-level tracking; no low-variance-behavior (Summit the Pyramid) depth.",
					},
					{
						ID: "I.2", Name: "Breadth of Threat Information", LevelsMet: []int{1, 2},
						Evidence: []string{
							"lantern:README.md (MITRE ATT&CK Mapping table — 6+ techniques across T10xx/T14xx/T15xx)",
							"veil:README.md (Tairn course work: CRTA/CRT-ID technique work with ATT&CK mapping)",
						},
						Note: "Broad technique awareness but no industry/region/infrastructure-tailored prioritization.",
					},
					{
						ID: "I.3", Name: "Relevance of Threat Data", LevelsMet: []int{1, 3},
						Evidence: []string{
							"veil:README.md (self-collected attacker telemetry: Cowrie sessions, Suricata EVE JSON, Shield)",
							"veil:README.md (NOC dashboard threat-intel widgets; scan queue from real internet attacks)",
						},
						Note: "In-house threat data from own edge (honeypot/IDS); no subscription or external briefing feeds.",
					},
					{
						ID: "I.4", Name: "Utilization of Threat Information", LevelsMet: []int{1, 2},
						Evidence: []string{
							"veil:docs/nightforge-shield.md (automated scoring of Suricata+Cowrie events -> nftables blackhole)",
							"veil:README.md (blocked IPs enqueued to scan queue for Nuclei recon)",
						},
						Note: "Telemetry regularly ingested and acted on; not disseminated to non-security stakeholders.",
					},
					{
						ID: "I.5", Name: "Dissemination of Threat Reporting", LevelsMet: []int{1, 2},
						Evidence: []string{
							"veil:README.md (NOC dashboard: suricata.json, cowrie.json, nftables.json status files)",
							"lantern:README.md (ATT&CK-mapped findings exported for detection engineers/purple teams)",
						},
						Note: "Tactical IOC/TTP reporting; no operational campaign or strategic business-risk reporting.",
					},
				},
			},
			{
				ID: "DM", Name: "Defensive Measures", Weight: 0.5,
				Components: []m3tid.Component{
					{
						ID: "D.1", Name: "Foundational Security", LevelsMet: []int{1, 2, 3},
						Evidence: []string{
							"veil:README.md (Security Posture table: WG mesh, default-deny nftables, key-only SSH, rootless Podman, Caddy TLS)",
							"veil:README.md (weekly automated maintenance: pacman -Syu, Suricata rule update)",
							"veil:docs/infra.md (node registry, key paths, port map)",
						},
						Note: "Automated patching + full asset registry; no formal threat-informed risk management process (L4).",
					},
					{
						ID: "D.2", Name: "Data Collection", LevelsMet: []int{1, 2},
						Evidence: []string{
							"veil:README.md (Suricata EVE JSON, Cowrie JSON sessions, auditd, Netdata, beszel agents)",
							"veil:README.md (NOC scripts: wg-status.sh, cowrie-status.sh, suricata-status.sh, nftables-status.sh)",
						},
						Note: "Multiple sensor types, structured JSON; no central index/search (known gap: centralized log aggregation).",
					},
					{
						ID: "D.3", Name: "Detection Engineering", LevelsMet: []int{1, 2, 3},
						Evidence: []string{
							"veil:README.md (Suricata 8.0.3 with live rule updates — imported rules)",
							"veil:configs/threshold.config (Suricata threshold tuning)",
							"veil:docs/nightforge-shield.md (custom scoring engine with tuned weights + block threshold)",
						},
						Note: "Custom detection logic (Shield) tested/tuned in production; no low-variance-behavior rule development (L4).",
					},
					{
						ID: "D.4", Name: "Incident Response", LevelsMet: []int{1, 2},
						Evidence: []string{
							"veil:docs/nightforge-shield.md (automated containment: score >= 4 -> 1hr nftables blackhole)",
							"veil:docs/ops.md (operations runbook), veil:docs/troubleshooting.md (issue catalog)",
						},
						Note: "Alert-driven automated response with runbooks; no proactive threat-actor-informed hunt program (L3).",
					},
					{
						ID: "D.5", Name: "Deception Operations", LevelsMet: []int{1, 2, 3},
						Evidence: []string{
							"veil:README.md (Cowrie 2.9.13 SSH honeypot on port 22, production)",
							"veil:configs/cowrie (logrotate config)",
							"veil:README.md (controlled malware/lab execution: libvirt lab targets, Podman RE profile)",
						},
						Note: "Production honeypot feeding intel + blocking; no honeynet (L4).",
					},
				},
			},
			{
				ID: "T&E", Name: "Testing & Evaluation", Weight: 0.2,
				Components: []m3tid.Component{
					{
						ID: "T.1", Name: "Type of Testing", LevelsMet: []int{1, 2, 3},
						Evidence: []string{
							"c4:README.md (C2 orchestration: deploy Mythic/Sliver, callbacks, payloads — adversary emulation)",
							"veil:README.md (Mythic C2, Poseidon agent, HTTP C2 profile, Operation CR1MS0N)",
							"lantern:README.md (AD permission auditing for purple teams; CI/CD security gates)",
						},
						Note: "Adversary emulation is the core type; no formal collaborative purple-team exercise (L4).",
					},
					{
						ID: "T.2", Name: "Frequency of Testing", LevelsMet: []int{1, 2, 3},
						Evidence: []string{
							"lantern:README.md (weekly CI/CD audit example — recurring cadence)",
							"nightforge:README.md (harness pipeline: failure-miner/proposal-engine/gate-check recurring runs)",
							"veil:README.md (continuous passive validation: Suricata/Cowrie/Shield 24x7)",
						},
						Note: "Recurring scheduled testing + continuous passive validation; active emulation is not continuous (L4).",
					},
					{
						ID: "T.3", Name: "Test Planning", LevelsMet: []int{1, 2},
						Evidence: []string{
							"c4:README.md (scoped C2 lifecycle: listeners, payloads, callbacks per operation)",
							"lantern:README.md (deliberately scoped audits: LDAP URI, base DN, CI gates)",
						},
						Note: "Planned and scoped per engagement, threat-informed; no defender-collaborative planning (L3) or KPI linkage (L4).",
					},
					{
						ID: "T.4", Name: "Test Execution", LevelsMet: []int{1, 2, 3, 4},
						Evidence: []string{
							"c4:README.md + c4:cmd/ (custom Go tooling: listener/callback/payload/detect orchestration)",
							"lantern:scripts/simulate_kerberoasting.py (multi-procedure credential-access testing)",
							"nightforge:README.md (ad container profile: Impacket, krb5, RustHound-CE — custom TTP tooling)",
						},
						Note: "TTP-focused execution with custom tooling and multi-technique flows (e.g. AD attack chains).",
					},
					{
						ID: "T.5", Name: "Test Results", LevelsMet: []int{1, 2, 3},
						Evidence: []string{
							"veil:docs/known-gaps.md (active + resolved gaps — findings formally tracked)",
							"veil:README.md (deployments driven by findings: honeypot, Shield blocking, Quadlet migration)",
							"nightforge:README.md (L4 failure mining, L5 proposals, L6 gates — results drive changes)",
						},
						Note: "Findings tracked and driving detection/architecture changes; no org-program-level investment loop (L4).",
					},
				},
			},
		},
		Notes: []string{
			"Scope: C4 (Mythic/Sliver C2 orchestration), Lantern (ACLGuard AD permission auditor), Veil (infra mesh + Shield/Suricata/Cowrie).",
			"Operational status 2026-08-08: Cerberus up; Tairn (Mythic C2) and Hermes (redirector) parked — active emulation paused, capability intact.",
			"Single-operator program: components requiring cross-team collaboration (CTI I.4 L3, T&E T.1 L4, T.3 L3) are capped accordingly.",
			"No external CTI feeds (MISP/STIX/TAXII) — the CTI dimension is the weakest and the primary improvement lever.",
		},
	}

	a.Overall = m3tid.ComputeOverall(a.Dimensions)

	path, err := m3tid.Write(a)
	if err != nil {
		log.Fatalf("[m3tid] %v", err)
	}
	fmt.Printf("M3TID assessment %s: overall=%.1f%% (%.2f/%.0f)\n",
		a.AssessedDate, a.Overall.Percent, a.Overall.WeightedScore, a.Overall.Max)
	for _, d := range a.Dimensions {
		fmt.Printf("  %-4s %-32s %.2f/%.0f (weight %.1f)\n", d.ID, d.Name, d.Score(), m3tid.ComponentMax, d.Weight)
	}
	fmt.Printf("  assessment file: %s\n", path)
}
