#!/bin/sh
# graphify-merge.sh - rebuild the harvey and r9 knowledge graphs and merge them
# into one cross-repo graph published to .planning/graphs/ for /gsd-graphify.
#
# graphify's cluster-only always writes its outputs to <path>/graphify-out/, so
# the merged graph lives in its own subdir. Merging over harvey's own
# graphify-out/graph.json would leave a 84k-node graph there and trip update's
# shrink guard (#479) on the next plain `graphify update .`.
#
#   graphify-out/graph.json               harvey-only graph
#   $R9/graphify-out/graph.json           r9-only graph
#   graphify-out/merged/graphify-out/     merged + clustered outputs (published)
#
# If `graphify update` ever refuses to shrink after code deletions, re-run with
# GRAPHIFY_FORCE=1 (read natively by graphify).
set -eu

HARVEY=$(cd "$(dirname "$0")/../.." && pwd)
R9=${R9_REPO:-"$HARVEY/../r9"}
[ -d "$R9" ] || { echo "r9 repo not found at $R9 (set R9_REPO to override)" >&2; exit 1; }

echo "== r9 graph =="
(cd "$R9" && graphify update .)

echo "== harvey graph =="
(cd "$HARVEY" && graphify update .)

echo "== merge =="
MERGED_DIR="$HARVEY/graphify-out/merged"
mkdir -p "$MERGED_DIR"
PREV=""
[ -f "$MERGED_DIR/graphify-out/graph.json" ] && PREV="--previous $MERGED_DIR/graphify-out/graph.json"
# shellcheck disable=SC2086
(cd "$HARVEY" && graphify merge-graphs \
	graphify-out/graph.json "$R9/graphify-out/graph.json" \
	--out "$MERGED_DIR/graph.json" $PREV)

echo "== re-cluster merged graph =="
(cd "$MERGED_DIR" && graphify cluster-only . --graph graph.json)

echo "== publish to .planning/graphs =="
GRAPHS="$HARVEY/.planning/graphs"
mkdir -p "$GRAPHS"
cp "$MERGED_DIR/graphify-out/graph.json" "$GRAPHS/graph.json"
cp "$MERGED_DIR/graphify-out/graph.html" "$GRAPHS/graph.html"
cp "$MERGED_DIR/graphify-out/GRAPH_REPORT.md" "$GRAPHS/GRAPH_REPORT.md"

echo "== diff snapshot =="
GSD_TOOLS="${ZCODE_CONFIG_DIR:-$HOME/.zcode}/gsd-core/bin/gsd-tools.cjs"
if command -v node >/dev/null 2>&1 && [ -f "$GSD_TOOLS" ]; then
	(cd "$HARVEY" && node "$GSD_TOOLS" graphify build snapshot) || true
else
	echo "gsd-tools not found at $GSD_TOOLS - skipping snapshot"
fi

echo "done - merged graph published to .planning/graphs/graph.json"
