#!/bin/bash
#
# DI boundary guardrails for the singleton refactor
# (docs/rework-singleton-pattern-currently-idempotent-turtle.md):
#
#  1. Hard ban: the model and audio layers must never reach up into UI scene
#     objects (SceneDelegate.shared / AppDelegate.shared).
#  2. Ratchet: ambient container resolution (Resolver.resolve / @Injected /
#     @LazyInjected) in those layers may only decrease. The checked-in baseline
#     holds the current count; lower it as call sites are converted.
#
# Run from anywhere; CI runs it in the unit-tests job.
set -euo pipefail
cd "$(dirname "$0")/.."

DIRS=("Classes/Models" "Classes/Audio Engine")
BASELINE_FILE="Scripts/di-ratchet-baseline.txt"

# 1. Hard ban
banned=$(grep -rn "SceneDelegate\.shared\|AppDelegate\.shared" "${DIRS[@]}" --include="*.swift" || true)
if [ -n "$banned" ]; then
    echo "ERROR: model/audio layers must not reference SceneDelegate.shared or AppDelegate.shared:"
    echo "$banned"
    exit 1
fi

# 2. Ratchet (DependencyInjection.swift is the composition root and is exempt)
count=$(grep -rEn "Resolver\.resolve|@Injected|@LazyInjected" "${DIRS[@]}" --include="*.swift" \
    | grep -v "Classes/Models/DependencyInjection.swift" \
    | wc -l | tr -d ' ')
baseline=$(tr -d ' \n' < "$BASELINE_FILE")

if [ "$count" -gt "$baseline" ]; then
    echo "ERROR: ambient DI usage under Classes/Models + Classes/Audio Engine grew from $baseline to $count."
    echo "New service-location call sites are not allowed there; inject dependencies through initializers"
    echo "or attach() back-edges instead (see the plan doc)."
    grep -rEn "Resolver\.resolve|@Injected|@LazyInjected" "${DIRS[@]}" --include="*.swift" \
        | grep -v "Classes/Models/DependencyInjection.swift"
    exit 1
fi

if [ "$count" -lt "$baseline" ]; then
    echo "NOTE: ambient DI count fell from $baseline to $count — please lower $BASELINE_FILE to $count."
fi

echo "DI boundaries OK (ambient count: $count, baseline: $baseline)"
