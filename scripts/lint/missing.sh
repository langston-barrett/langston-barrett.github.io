#!/usr/bin/env bash

set -euo pipefail

grep "$(basename "${1}")" SUMMARY.md
