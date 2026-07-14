#!/usr/bin/env bash
set -euo pipefail

module_dir="$1"
module_file="$module_dir/darwin.nix"
root_cert="$module_dir/netskope-root.pem"
expected_fingerprint="EA:0D:60:91:E2:A2:B9:50:9F:DF:9E:91:45:51:7B:E4:DB:EE:6A:91:51:69:C3:EF:2D:F0:D1:02:16:5F:7E:37"

if [[ ! -f $root_cert ]]; then
  echo "missing Netskope root certificate: $root_cert" >&2
  exit 1
fi

actual_fingerprint=$(openssl x509 -in "$root_cert" -noout -fingerprint -sha256 | cut -d= -f2)
[[ $actual_fingerprint == "$expected_fingerprint" ]]
openssl x509 -in "$root_cert" -noout -checkend 0

subject=$(openssl x509 -in "$root_cert" -noout -subject -nameopt RFC2253 | sed 's/^subject=//')
issuer=$(openssl x509 -in "$root_cert" -noout -issuer -nameopt RFC2253 | sed 's/^issuer=//')
[[ $subject == "$issuer" ]]
openssl verify -CAfile "$root_cert" "$root_cert"

grep -Fq 'netskopeRootCert = builtins.readFile ./netskope-root.pem;' "$module_file"
grep -Fq 'environment.variables.BUNDLE_SSL_CA_CERT = certBundle;' "$module_file"
