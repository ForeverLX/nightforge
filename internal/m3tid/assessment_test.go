package m3tid

import "testing"

// TestScoreComputesCumulativePoints verifies the official point ladder:
// L1=1, L2=1, L3=2, L4=2, cumulative; max 6.
func TestScoreComputesCumulativePoints(t *testing.T) {
	cases := []struct {
		levels []int
		want   float64
	}{
		{nil, 0},
		{[]int{1}, 1},
		{[]int{1, 2}, 2},
		{[]int{1, 3}, 3}, // skipping L2 still earns L1+L3
		{[]int{1, 2, 3}, 4},
		{[]int{1, 2, 3, 4}, 6},
	}
	for _, tc := range cases {
		got := (Component{LevelsMet: tc.levels}).Score()
		if got != tc.want {
			t.Errorf("levels %v: got %.1f want %.1f", tc.levels, got, tc.want)
		}
	}
}

// TestComputeOverall verifies the official weighting formula
// (DM 0.5, CTI 0.3, T&E 0.2, normalized by the weighted max).
func TestComputeOverall(t *testing.T) {
	// Component scores 4,2,3,2,2 -> CTI 2.6 (weight 0.3)
	//                  4,2,4,2,4 -> DM  3.2 (weight 0.5)
	//                  4,4,2,6,4 -> T&E 4.0 (weight 0.2)
	// overall = (0.3*2.6 + 0.5*3.2 + 0.2*4.0) / 6 = 3.18/6 = 0.53
	dims := []Dimension{
		{ID: "CTI", Weight: 0.3, Components: comps(4, 2, 3, 2, 2)},
		{ID: "DM", Weight: 0.5, Components: comps(4, 2, 4, 2, 4)},
		{ID: "T&E", Weight: 0.2, Components: comps(4, 4, 2, 6, 4)},
	}
	if o.WeightedScore != 3.18 {
		t.Errorf("weighted score: got %v want 3.18", o.WeightedScore)
	}
	if o.Percent != 53.0 {
		t.Errorf("percent: got %v want 53.0", o.Percent)
	}
}

func comps(scores ...float64) []Component {
	var out []Component
	// Reconstruct the level sets that produce each score; the exact shape
	// only matters for the dimension mean, so derive from known combos.
	for _, s := range scores {
		out = append(out, Component{LevelsMet: levelsFor(s)})
	}
	return out
}

func levelsFor(score float64) []int {
	switch score {
	case 1:
		return []int{1}
	case 2:
		return []int{1, 2}
	case 3:
		return []int{1, 3}
	case 4:
		return []int{1, 2, 3}
	case 6:
		return []int{1, 2, 3, 4}
	default:
		return nil
	}
}
