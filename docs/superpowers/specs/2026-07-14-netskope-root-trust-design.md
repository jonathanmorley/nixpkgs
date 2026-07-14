# Netskope Root Trust Design

## Goal

Make the Cvent macOS configuration trust Netskope correctly for system TLS,
Nix fetchers, Node.js, Python, Requests, and Bundler without disabling peer
verification or trusting an issuing intermediate as a root.

## Problem

The Cvent Darwin module currently embeds the `ca.cvt.goskope.com` intermediate
certificate in its custom Mozilla CA bundle. OpenSSL cannot build the observed
Netskope chain from that intermediate because the self-signed `certadmin` root
is absent. Bundler consequently fails to verify `rubygems.org` even though the
macOS trust store allows SecureTransport clients such as the system `curl` to
connect.

## Design

Store the self-signed Netskope root as
`modules/cvent/netskope-root.pem`. Its expected SHA-256 fingerprint is:

```text
EA:0D:60:91:E2:A2:B9:50:9F:DF:9E:91:45:51:7B:E4:DB:EE:6A:91:51:69:C3:EF:2D:F0:D1:02:16:5F:7E:37
```

The Cvent Darwin module will read that PEM and append it to the standard Mozilla
CA bundle. The intermediate will be removed from the configuration: TLS peers
must supply intermediates, while the local trust store supplies only the trust
anchor.

The resulting bundle will remain the source for Nix fetch overrides,
`NODE_EXTRA_CA_CERTS`, `SSL_CERT_FILE`, and `REQUESTS_CA_BUNDLE`. The same path
will also be exported as `BUNDLE_SSL_CA_CERT`, because Bundler supports a
dedicated PEM trust-bundle setting and its Ruby/OpenSSL path did not reliably
consume `SSL_CERT_FILE` in the reproduced environment. `security.pki.certificates`
will install the root in the macOS system trust store.

## Data Flow

```text
netskope-root.pem
  -> custom Mozilla CA bundle
  -> Nix fetchers
  -> macOS system trust
  -> Node.js, Python, Requests, and Bundler environment variables
```

## Verification

Add a flake check that validates the stored PEM before any machine is switched:

- it parses as an X.509 certificate;
- it is currently valid;
- its subject and issuer are equal;
- it verifies against itself;
- its SHA-256 fingerprint matches the expected Netskope root.

Extend the runtime certificate test to require `BUNDLE_SSL_CA_CERT` to reference
an existing file and to run `bundle doctor ssl --host rubygems.org` when Bundler
is available. The test passes only when the diagnostic reports
`Bundler: success`; RubyGems and raw `net/http` results are outside this
Bundler-specific assertion.

Verification before publication will include formatting, the complete flake
check, evaluation or build of the Cvent Darwin configuration, and a diff review.

## Rollout and Safety

The repository change will not switch the current machine automatically. After
the PR is merged, the normal Darwin switch applies the new trust anchor and
environment variable machine-wide. TLS peer verification remains enabled; no
`ssl_verify_mode` exception or insecure HTTP fallback is introduced.

## Out of Scope

- Compensating for a TLS peer that omits its intermediate certificate.
- Changing the Maven package's Ruby or Bundler versions.
- Adding the Netskope intermediate as a second trust anchor.
