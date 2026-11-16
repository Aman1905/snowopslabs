#!/usr/bin/env bats
# SPDX-License-Identifier: Apache-2.0
#
# chaos-engineering's inject.sh renders the experiments for the bound app and
# applies one by label. The network experiments have to reach the namespace
# 'labctl traffic start' runs k6 in, or the scenario's own load never crosses
# the fault and the client-side panels stay flat.

load 'helpers/stub'

setup() {
  stub_setup
  ROOT="$(project_root)"
  SCRIPT="$ROOT/scenarios/chaos-engineering/scripts/inject.sh"
  export WORKLOAD_NAME=cart WORKLOAD_NAMESPACE=shop
  stub_script kubectl <<'EOF'
case "$*" in
  *"apply -f -"*) cat >"$STUB_DIR/applied.yaml" ;;
esac
exit 0
EOF
}

teardown() { stub_teardown; }

# target_namespaces <experiment>: the namespaces under spec.target of that
# experiment as inject.sh rendered it, one per line.
target_namespaces() {
  awk -v want="$1" '
    function flush() {
      if (found) printf "%s", out
      out = ""; found = 0; in_target = 0; in_ns = 0
    }
    /^---/ { flush(); next }
    $0 ~ "^ +experiment: " want "$" { found = 1 }
    /^  target:/ { in_target = 1; next }
    in_target && /^  [a-z]/ { in_target = 0; in_ns = 0 }
    in_target && /namespaces:/ { in_ns = 1; next }
    in_ns && /^ *- / { v = $0; sub(/^ *- */, "", v); gsub(/"/, "", v); out = out v "\n"; next }
    in_ns { in_ns = 0 }
    END { flush() }
  ' "$STUB_DIR/applied.yaml"
}

@test "network-delay reaches k6 in the traffic namespace as well as the ingress" {
  run bash "$SCRIPT" network-delay
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_called kubectl "apply -f - -l experiment=network-delay"
  [ "$(target_namespaces network-delay)" = "$(printf 'traefik\ntraffic')" ]
}

@test "network-partition reaches k6 in the traffic namespace as well as the ingress" {
  run bash "$SCRIPT" network-partition
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_called kubectl "apply -f - -l experiment=network-partition"
  [ "$(target_namespaces network-partition)" = "$(printf 'traefik\ntraffic')" ]
}

@test "the experiments are rendered for the bound app" {
  run bash "$SCRIPT" network-delay --app go-api --namespace go-api
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  run grep -c '{{' "$STUB_DIR/applied.yaml"
  [ "$output" = 0 ]
  grep -q 'name: "network-delay-go-api"' "$STUB_DIR/applied.yaml"
}
