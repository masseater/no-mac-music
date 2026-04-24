#!/usr/bin/env bash
set -euo pipefail

NOMACMUSIC_VARIANT=dev bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build-app.sh"
