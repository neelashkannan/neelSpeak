#!/bin/bash
# Prepares NeelSpeak's own FluidAudio Parakeet model directory.
# The app downloads missing FluidAudio Parakeet files into this directory on first use.
set -euo pipefail

DEST="$HOME/Library/Application Support/NeelSpeak/Models/FluidAudio/parakeet-tdt-0.6b-v3"

mkdir -p "$DEST"
echo "==> Parakeet model directory ready: $DEST"
echo "==> NeelSpeak will download FluidAudio Parakeet files here when you press Download Parakeet."
