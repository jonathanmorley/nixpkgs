{pkgs, ...}: let
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
  netskopeCertFile = pkgs.writeText "netskope.crt" netskopeCert;
  netskopeCombined = builtins.readFile "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" + "\n" + netskopeCert;
  netskopeCombinedFile = pkgs.writeText "netskope-combined.crt" netskopeCombined;
in {
  security.pki.certificates = [netskopeCert];
  environment.variables.NODE_EXTRA_CA_CERTS = "${netskopeCombinedFile}";
  environment.variables.AWS_CA_BUNDLE = "${netskopeCombinedFile}";
  environment.variables.CURL_CA_BUNDLE = "${netskopeCombinedFile}";
  environment.variables.REQUESTS_CA_BUNDLE = "${netskopeCombinedFile}";
  environment.variables.SSL_CERT_FILE = "${netskopeCombinedFile}";
}
