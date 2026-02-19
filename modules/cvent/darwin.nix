# See https://daiderd.com/nix-darwin/manual/index.html#sec-options
{
  pkgs,
  lib,
  config,
  ...
}: let
  netskopeCert = ''
    -----BEGIN CERTIFICATE-----
    MIIEXDCCA0SgAwIBAgIUEiG7Zru2Uzu2s5iMw638xzylDFIwDQYJKoZIhvcNAQEL
    BQAwgZcxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJDQTEUMBIGA1UEBxMLU2FudGEg
    Q2xhcmExFjAUBgNVBAoTDU5ldHNrb3BlIEluYy4xEjAQBgNVBAsTCWNlcnRhZG1p
    bjESMBAGA1UEAxMJY2VydGFkbWluMSUwIwYJKoZIhvcNAQkBFhZjZXJ0YWRtaW5A
    bmV0c2tvcGUuY29tMB4XDTI2MDEwNTA1MjAzMVoXDTM2MDEwMzA1MjAzMVowgbEx
    JTAjBgkqhkiG9w0BCQEMFmNlcnRhZG1pbkBuZXRza29wZS5jb20xGzAZBgNVBAMM
    EmNhLmN2dC5nb3Nrb3BlLmNvbTEpMCcGA1UECwwgOGRkZmMzZjI2NGJjODgwZGM4
    NzVhNjZlYzYxYWVmM2YxFDASBgNVBAoMC0N2ZW50IGluZGlhMRAwDgYDVQQHDAdH
    dXJnYW9uMQswCQYDVQQIDAJIUjELMAkGA1UEBgwCSU4wggEiMA0GCSqGSIb3DQEB
    AQUAA4IBDwAwggEKAoIBAQDbB2638iODWFfbQe+YJpANLE855+h3zWpS85ut9z/i
    p9uY6i8WhFVjVfByAPaxzSX/Vkwh3P09thm7tPGcTYjsR1Hz4LqM06Vg2Wr3X6s/
    nUP/WhjCCfI9Nyf5WyszNsT00Mj8uydIGfjcRfzHshZn2uG/F2HHMNjSuU7LUjeG
    uz09aKC2SDgwJnN+CymWNvwITiSUL31CZabXK4q86oRA2akWbJIfzNQNMdPPUmpW
    8aMqn6YnbKXElxqrfx+p3Ih/a61iS7cVlt62t+oKGzeWeofX8ulj7cKEbX670ggp
    Y49t7eeKjnsd2/2pBAM5iZwgLHJVyuk4/VjnNlZY/BTRAgMBAAGjgYMwgYAwEgYD
    VR0TAQH/BAgwBgEB/wIBATALBgNVHQ8EBAMCAaYwHQYDVR0lBBYwFAYIKwYBBQUH
    AwEGCCsGAQUFBwMCMB0GA1UdDgQWBBRYsv+iuCXYi++86pzkWvIyJtfgQjAfBgNV
    HSMEGDAWgBSvIpNrMIV6Lcujo5SCGWw3AGl7VDANBgkqhkiG9w0BAQsFAAOCAQEA
    gmtSgF+VWRa3lPgtDnjiVhoi5etcAm/3uUfZ6Ngh1nxIzyB36q7LGByHJaVXjlLY
    6C02ycElROYl183jwuKMwba1Z8h3YKuR876J33J4WyY6ybFgXlP2YxRNOpagBEJg
    a6sP9E/iBvRuOUKTsfTWxrdrglenKy104UmXg6Db47E9Z2XuUpKUddof7PxxF8xr
    0op3HDcI44ig4mryKrgmxCnx8ySU8gP9ervuYU9XILblU8XzK+80IP6lcIuWtUMj
    wJDyCQUfBX+FsZxB0bBu8tj8N33JdZp7DE1jWdHPQbELJAEL0Yl6lmB5vpMlT45M
    T/noKStI+zeCvbtHu9g1xA==
    -----END CERTIFICATE-----
  '';
  customCacert = pkgs.cacert.override {
    extraCertificateStrings = [netskopeCert];
  };

  certBundle = "${customCacert}/etc/ssl/certs/ca-bundle.crt";
in {
  # Override custom packages so their source fetches use a cert bundle that
  # includes the Netskope proxy cert. Explicit .override chains replace
  # cacert → fetchurl → fetchzip → fetchFromGitHub for just these packages,
  # keeping binary cache hits for everything else.
  nixpkgs.overlays = lib.mkAfter [
    (final: prev: let
      corpoFetchurl = prev.fetchurl.override { cacert = customCacert; };
      corpoFetchzip = prev.fetchzip.override { fetchurl = corpoFetchurl; };
      corpoFetchFromGitHub = prev.fetchFromGitHub.override { fetchzip = corpoFetchzip; };
    in {
      fnox = prev.fnox.override { fetchFromGitHub = corpoFetchFromGitHub; };
      gig = prev.gig.override { fetchFromGitHub = corpoFetchFromGitHub; };
      rtk = prev.rtk.override { fetchFromGitHub = corpoFetchFromGitHub; };
    })
  ];

  # Netskope proxy certificate for macOS system trust
  security.pki.certificates = [netskopeCert];
  # Point CLI tools at the custom bundle (includes Netskope cert)
  environment.variables.NODE_EXTRA_CA_CERTS = "${customCacert}/etc/ssl/certs/ca-bundle.crt";
  environment.variables.AWS_CA_BUNDLE = "${customCacert}/etc/ssl/certs/ca-bundle.crt";
  environment.variables.CURL_CA_BUNDLE = "${customCacert}/etc/ssl/certs/ca-bundle.crt";
  environment.variables.REQUESTS_CA_BUNDLE = "${customCacert}/etc/ssl/certs/ca-bundle.crt";

  # Any brews/casks MUST be justified as to why they are
  # not being installed as a nix package.
  homebrew = {
    casks = [
      # Not available in nixpkgs
      "microsoft-outlook"
      # Not available in nixpkgs
      "microsoft-excel"
      "okta-verify"
    ];
    masApps = {
      # The firefox extension doesnt unlock with biometrics if bitwarden is installed any other way
      "bitwarden" = 1352778147;
    };
  };

  system.defaults.dock.persistent-apps = [
    "${pkgs.slack}/Applications/Slack.app"
    "/Applications/Microsoft Outlook.app"
  ];

  environment.variables.SSH_AUTH_SOCK = "/Users/${config.system.primaryUser}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";
  home-manager.users.${config.system.primaryUser}.programs.ssh.matchBlocks."*".extraOptions.IdentityAgent = "\"/Users/${config.system.primaryUser}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock\"";
}
