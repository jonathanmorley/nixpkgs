# Netskope Root Trust Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the trusted Netskope intermediate with its self-signed root and configure every Cvent-machine TLS consumer, including Bundler, to use the corrected CA bundle.

**Architecture:** Keep the Netskope root in a standalone PEM file, append it to nixpkgs' Mozilla CA bundle, and route the resulting bundle to system trust, Nix fetchers, Node.js, Python, Requests, and Bundler. A flake check validates the trust anchor before deployment, while the existing runtime certificate suite verifies the post-switch environment and Bundler connection.

**Tech Stack:** Nix, nix-darwin, Bash, OpenSSL, Bundler 4

## Global Constraints

- Trust only the self-signed Netskope root; do not retain the issuing intermediate as a trust anchor.
- Preserve TLS peer verification; do not set `ssl_verify_mode` or use insecure HTTP.
- Expected root SHA-256 fingerprint: `EA:0D:60:91:E2:A2:B9:50:9F:DF:9E:91:45:51:7B:E4:DB:EE:6A:91:51:69:C3:EF:2D:F0:D1:02:16:5F:7E:37`.
- Do not switch the current machine as part of this repository change.
- Run the repository formatter and complete flake checks before publication.

## Review Amendments

Independent review of the first implementation confirmed that the pinned
nix-darwin `security.pki.certificates` option manages only the PEM bundle and
does not import certificates into the macOS System Keychain. The implementation
therefore extends the original steps in two ways:

- the flake check evaluates the Cvent Darwin configuration and verifies the
  generated bundle, system certificate list, every CA consumer variable, and
  activation script rather than relying only on source greps;
- an idempotent activation step verifies the exact root fingerprint and trust
  state, then imports it into the System Keychain as `trustRoot` for the TLS
  policy when needed;
- the certificate derivation is exposed only for `aarch64-darwin`, matching the
  evaluated Cvent configuration and avoiding foreign-system dependencies.

These amendments supersede the simplified static-test and system-trust snippets
below while preserving the root-only and peer-verification constraints.

______________________________________________________________________

### Task 1: Add Failing Trust-Anchor Regression Checks

**Files:**

- Create: `tests/certs-static.sh`
- Modify: `cert-check.nix`
- Modify: `tests/certs.sh`

**Interfaces:**

- Consumes: `modules/cvent` as the source directory under test.

- Produces: flake check `checks.<system>.certificates` and post-switch Bundler assertions.

- [ ] **Step 1: Create the static certificate regression test**

Create `tests/certs-static.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

module_dir="$1"
module_file="$module_dir/darwin.nix"
root_cert="$module_dir/netskope-root.pem"
expected_fingerprint="EA:0D:60:91:E2:A2:B9:50:9F:DF:9E:91:45:51:7B:E4:DB:EE:6A:91:51:69:C3:EF:2D:F0:D1:02:16:5F:7E:37"

if [[ ! -f "$root_cert" ]]; then
  echo "missing Netskope root certificate: $root_cert" >&2
  exit 1
fi

actual_fingerprint=$(openssl x509 -in "$root_cert" -noout -fingerprint -sha256 | cut -d= -f2)
[[ "$actual_fingerprint" == "$expected_fingerprint" ]]
openssl x509 -in "$root_cert" -noout -checkend 0

subject=$(openssl x509 -in "$root_cert" -noout -subject -nameopt RFC2253 | sed 's/^subject=//')
issuer=$(openssl x509 -in "$root_cert" -noout -issuer -nameopt RFC2253 | sed 's/^issuer=//')
[[ "$subject" == "$issuer" ]]
openssl verify -CAfile "$root_cert" "$root_cert"

grep -Fq 'netskopeRootCert = builtins.readFile ./netskope-root.pem;' "$module_file"
grep -Fq 'environment.variables.BUNDLE_SSL_CA_CERT = certBundle;' "$module_file"
```

- [ ] **Step 2: Expose the regression test as a flake check**

Add this sibling to `checks.trajectory` in `cert-check.nix`:

```nix
checks.certificates = pkgs.runCommand "certificate-tests" {nativeBuildInputs = [pkgs.openssl];} ''
  ${./tests/certs-static.sh} ${./modules/cvent}
  touch "$out"
'';
```

- [ ] **Step 3: Extend the runtime certificate test**

Add `BUNDLE_SSL_CA_CERT` to the environment display and `check_file_env_var` calls in `tests/certs.sh`. Before the macOS Security Framework section, add:

```bash
echo "BUNDLE_SSL_CA_CERT: ${BUNDLE_SSL_CA_CERT:-not set}"
check_file_env_var "BUNDLE_SSL_CA_CERT"
```

Before the macOS Security Framework section, add:

```bash
# 8. Ruby Bundler Test
print_section "8. Ruby Bundler"

if command -v mise &>/dev/null; then
  BUNDLER_OUTPUT=$(mise exec ruby@4 -- bundle doctor ssl --host rubygems.org 2>&1)
  if echo "$BUNDLER_OUTPUT" | grep -Fq "Bundler:       success"; then
    print_result 0 "Bundler - RubyGems TLS"
  else
    print_result 1 "Bundler - RubyGems TLS"
    echo "$BUNDLER_OUTPUT"
  fi
else
  echo -e "${YELLOW}⊘ SKIP${NC}: mise not available"
fi
```

Renumber the macOS Security Framework section to 9 and change its Keychain query from `ca.cvt.goskope.com` to `certadmin`.

- [ ] **Step 4: Run the new check and verify RED**

Stage the new test so Nix includes it in the flake source:

```bash
git add cert-check.nix tests/certs-static.sh tests/certs.sh
```

Run:

```bash
nix build .#checks.aarch64-darwin.certificates --print-build-logs --no-link
```

Expected: FAIL with `missing Netskope root certificate` because production still embeds only the intermediate.

______________________________________________________________________

### Task 2: Install and Route the Netskope Root

**Files:**

- Create: `modules/cvent/netskope-root.pem`
- Modify: `modules/cvent/darwin.nix`
- Modify: `treefmt.nix`

**Interfaces:**

- Consumes: standalone PEM trust anchor.

- Produces: `certBundle` and machine-wide `BUNDLE_SSL_CA_CERT`, `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, and `NODE_EXTRA_CA_CERTS` values.

- [ ] **Step 1: Add the verified self-signed root PEM**

Create `modules/cvent/netskope-root.pem` using the `certadmin` certificate whose fingerprint matches the global constraint.

```pem
-----BEGIN CERTIFICATE-----
MIID/DCCAuSgAwIBAgICATgwDQYJKoZIhvcNAQELBQAwgZcxCzAJBgNVBAYTAlVT
MQswCQYDVQQIEwJDQTEUMBIGA1UEBxMLU2FudGEgQ2xhcmExFjAUBgNVBAoTDU5l
dHNrb3BlIEluYy4xEjAQBgNVBAsTCWNlcnRhZG1pbjESMBAGA1UEAxMJY2VydGFk
bWluMSUwIwYJKoZIhvcNAQkBFhZjZXJ0YWRtaW5AbmV0c2tvcGUuY29tMB4XDTE5
MTAyNTE4MTg1MFoXDTI5MTAyMjE4MTg1MFowgZcxCzAJBgNVBAYTAlVTMQswCQYD
VQQIEwJDQTEUMBIGA1UEBxMLU2FudGEgQ2xhcmExFjAUBgNVBAoTDU5ldHNrb3Bl
IEluYy4xEjAQBgNVBAsTCWNlcnRhZG1pbjESMBAGA1UEAxMJY2VydGFkbWluMSUw
IwYJKoZIhvcNAQkBFhZjZXJ0YWRtaW5AbmV0c2tvcGUuY29tMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuYamgJifcWI3j9zv6OHI0hCQnZHj8uuzZ6sw
nfbediwij9X7MTbQZmswXZt4EgJ58uPN8Opt3+eh+XGP1wbQemUIm9ZkL5WzMVxP
3xW/twL5hBBQOXvn6JX5HS8N53fiDDU8LCuc0xj0Kpdl3TiDDpebtJe6UPiwebyz
jtOwD3ddpiIlArvRzUU1Hi9RIey2clf//3NChyvteQ3TIhciwxbViOxPHxXTRI7w
znFlwuDxvx7X5wwDkI2vzV2jpn23uIROjpCYC7kLvGInEKrgVAzoKauaC+tJmiJY
91m2KGN6xGc94JMRawH6Q+wv/7cBsOGVOUVIpxcM1XS5UqngTwIDAQABo1AwTjAM
BgNVHRMEBTADAQH/MB0GA1UdDgQWBBSvIpNrMIV6Lcujo5SCGWw3AGl7VDAfBgNV
HSMEGDAWgBSvIpNrMIV6Lcujo5SCGWw3AGl7VDANBgkqhkiG9w0BAQsFAAOCAQEA
pKVWEFpG7/d0kAhre2eYLwYEf6tVVP2to9Cp8RgBFSG/ScmEqt2/TXXcpMjRI5eG
nOUbPJIQJi2TQEiI/BG/g6CJZWJiE3fR3NTCksbLbcbdl7exkKT/tItebf4qXlca
ASSd0hBTygE7QqOPSENnSrj7r9P0gv0Z2Bf5jKdirhr/clz/ev88O3KYuxqwwl31
vyLDT0hd/Dzka2/ZKMXL5uFAtsYqpU4hz5NeGgNntKAkwcfFgsTh/NZaYjyRhvUp
jRBt2Mt8OwtxJ+vPM4mvpwFMzvfzhdJfKX/p6IWOJjDFHHFRqdFaHvW3zzarzFt6
tLom62fi7946+fyBmEPu5w==
-----END CERTIFICATE-----
```

- [ ] **Step 2: Replace the inline intermediate**

Replace the inline `netskopeCert` string in `modules/cvent/darwin.nix` with:

```nix
netskopeRootCert = builtins.readFile ./netskope-root.pem;
```

Append `netskopeRootCert` to both generated CA bundle files, and configure system trust with:

```nix
security.pki.certificates = [netskopeRootCert];
```

Add Bundler beside the other file-based CA consumers:

```nix
environment.variables.BUNDLE_SSL_CA_CERT = certBundle;
```

Update nearby comments to say `Netskope root certificate` or `trust anchor` rather than proxy intermediate.

- [ ] **Step 3: Exclude the PEM from formatter matching**

Add to `treefmt.settings` in `treefmt.nix`:

```nix
global.excludes = ["modules/cvent/netskope-root.pem"];
```

- [ ] **Step 4: Run the targeted check and verify GREEN**

Stage the production files so Nix includes the PEM in the flake source:

```bash
git add modules/cvent/darwin.nix modules/cvent/netskope-root.pem treefmt.nix
```

Run:

```bash
nix build .#checks.aarch64-darwin.certificates --print-build-logs --no-link
```

Expected: PASS and produce the `certificate-tests` store path.

- [ ] **Step 5: Commit the tested implementation**

```bash
git add cert-check.nix modules/cvent/darwin.nix modules/cvent/netskope-root.pem tests/certs-static.sh tests/certs.sh treefmt.nix
git commit -m "fix: trust Netskope root certificate"
```

______________________________________________________________________

### Task 3: Document and Verify the Machine-Wide Change

**Files:**

- Modify: `README.md`

**Interfaces:**

- Consumes: completed certificate configuration and checks.

- Produces: operator-facing verification and rollout instructions.

- [ ] **Step 1: Document certificate verification**

Add a `Certificate Trust` section to `README.md` explaining that Cvent machines trust the Netskope root through the generated CA bundle, Bundler uses `BUNDLE_SSL_CA_CERT`, `nix flake check` validates the stored root, and `nix run .#test-certs` performs post-switch network checks.

```markdown
## Certificate Trust

Cvent machines add the Netskope root certificate to the standard Mozilla CA
bundle and use that bundle for system trust, Nix fetchers, Node.js, Python,
Requests, and Bundler. Bundler reads the bundle through
`BUNDLE_SSL_CA_CERT`.

`nix flake check` validates the stored root certificate and its fingerprint.
After switching a Cvent machine, run `nix run .#test-certs` to exercise the
configured TLS clients against live endpoints.
```

- [ ] **Step 2: Format the repository**

Run:

```bash
nix fmt
```

Expected: exit 0 with no unformatted files remaining.

- [ ] **Step 3: Run all flake checks**

Run:

```bash
nix flake check --print-build-logs --no-update-lock-file
```

Expected: exit 0, including `checks.aarch64-darwin.certificates` and `checks.aarch64-darwin.treefmt`.

- [ ] **Step 4: Build the Cvent Darwin configuration**

Run:

```bash
nix build .#darwinConfigurations.D3W27G1QW9.system --no-link --print-build-logs
```

Expected: exit 0 without switching the current machine.

- [ ] **Step 5: Review and commit documentation**

Review `git diff HEAD~1` for trust broadening, certificate mistakes, insecure verification settings, unintended formatting, and unrelated changes. Then run:

```bash
git add README.md
git commit -m "docs: explain Netskope certificate checks"
```

______________________________________________________________________

### Task 4: Publish the Required Pull Request

**Files:** None.

**Interfaces:**

- Consumes: verified commits on `codex/fix-netskope-root`.

- Produces: labeled pull request with automatic squash merge enabled.

- [ ] **Step 1: Push the branch**

```bash
git push -u origin codex/fix-netskope-root
```

- [ ] **Step 2: Open and label the pull request**

Open a pull request summarizing the root/intermediate correction and verification evidence, then add the required label:

```bash
gh pr create \
  --title "Trust Netskope root certificate" \
  --body "$(printf '%s\n' '## Summary' '- replace the Netskope intermediate trust anchor with its self-signed root' '- configure Bundler to use the machine-wide CA bundle' '- add static and runtime certificate verification' '' '## Verification' '- nix fmt' '- nix flake check --print-build-logs --no-update-lock-file' '- nix build .#darwinConfigurations.D3W27G1QW9.system --no-link --print-build-logs')"
gh pr edit --add-label "ai:autofix"
```

- [ ] **Step 3: Enable automatic squash merge**

```bash
gh pr merge --auto --squash
```

Expected: GitHub reports that auto-merge is enabled for the pull request.
