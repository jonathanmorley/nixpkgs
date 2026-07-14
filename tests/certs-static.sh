#!/usr/bin/env bash
set -euo pipefail

module_dir="$1"
bundle="$2"
system_certificates="$3"
activation_script="$4"
shift 4

module_file="$module_dir/darwin.nix"
root_cert="$module_dir/netskope-root.pem"
expected_fingerprint="EA:0D:60:91:E2:A2:B9:50:9F:DF:9E:91:45:51:7B:E4:DB:EE:6A:91:51:69:C3:EF:2D:F0:D1:02:16:5F:7E:37"
expected_keychain_fingerprint="EA0D6091E2A2B9509FDF9E9145517BE4DBEE6A915169C3EF2DF0D102165F7E37"
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

fail() {
  echo "$1" >&2
  exit 1
}

assert_exact_netskope_root() {
  local certificates="$1"
  local label="$2"
  local cert_dir="$temp_dir/$label"
  local netskope_count=0

  mkdir -p "$cert_dir"
  awk -v dir="$cert_dir" '
    /-----BEGIN CERTIFICATE-----/ {
      count++
      output = sprintf("%s/cert-%03d.pem", dir, count)
    }
    output { print > output }
    /-----END CERTIFICATE-----/ {
      close(output)
      output = ""
    }
  ' "$certificates"

  for certificate in "$cert_dir"/*.pem; do
    local subject
    local issuer
    local identity
    local fingerprint

    subject=$(openssl x509 -in "$certificate" -noout -subject)
    issuer=$(openssl x509 -in "$certificate" -noout -issuer)
    identity=$(printf '%s\n%s\n' "$subject" "$issuer" | tr '[:upper:]' '[:lower:]')

    if [[ $identity == *netskope* || $identity == *goskope* || $identity == *certadmin* || $identity == *cvent* ]]; then
      netskope_count=$((netskope_count + 1))
      fingerprint=$(openssl x509 -in "$certificate" -noout -fingerprint -sha256 | cut -d= -f2)
      [[ $fingerprint == "$expected_fingerprint" ]] || fail "$label contains an unexpected Netskope certificate: $fingerprint"
    fi
  done

  [[ $netskope_count -eq 1 ]] || fail "$label contains $netskope_count Netskope certificates; expected exactly one root"
}

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
openssl verify -check_ss_sig -CAfile "$root_cert" "$root_cert"

assert_exact_netskope_root "$bundle" "generated-bundle"
assert_exact_netskope_root "$system_certificates" "system-certificates"

for consumer_bundle in "$@"; do
  [[ $consumer_bundle == "$bundle" ]] || fail "CA consumer does not use the generated bundle: $consumer_bundle"
done

grep -Eq '^ +/usr/bin/security add-trusted-cert -d -r trustRoot -p ssl -k /Library/Keychains/System\.keychain /nix/store/.+-netskope-root\.pem$' "$activation_script" || fail "activation does not install the pinned Netskope trust root in the System Keychain for TLS"
grep -Fq "/usr/bin/security verify-cert -c" "$activation_script" || fail "activation does not verify the Netskope trust root"
grep -Fq -- "-p ssl -L -l -k /Library/Keychains/System.keychain" "$activation_script" || fail "activation does not verify the Netskope trust root for TLS"
grep -Fq "$expected_keychain_fingerprint" "$activation_script" || fail "activation does not verify the expected Netskope fingerprint"

grep -Fq 'netskopeRootCert = builtins.readFile ./netskope-root.pem;' "$module_file"
grep -Fq 'environment.variables.BUNDLE_SSL_CA_CERT = certBundle;' "$module_file"
