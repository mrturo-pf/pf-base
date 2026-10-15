#!/usr/bin/env bash
# Reset the local GitHub CLI TLS/proxy environment and verify gh access.
#
# Usage:
#   scripts/github/gh-healthcheck.sh

set -euo pipefail

unset SSL_CERT_FILE _SSL_CERT_FILE
source "$HOME/Documents/scripts/unset_proxies.sh"

env | grep -iE 'ssl_cert|http_proxy|https_proxy' || true
gh run list --repo mrturo-pf/pf-base --limit 5
