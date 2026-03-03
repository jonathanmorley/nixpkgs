#!/usr/bin/env bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track failures
FAILED_TESTS=0
TOTAL_TESTS=0

echo "=========================================="
echo "Certificate Handling Test Suite"
echo "=========================================="
echo ""

# Test URLs
HTTPS_URL="https://www.google.com"
AWS_URL="https://s3.amazonaws.com"

# Function to print test results
print_result() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [ "$1" -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: $2"
  else
    echo -e "${RED}✗ FAIL${NC}: $2"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

# Function to print section header
print_section() {
  echo ""
  echo "=========================================="
  echo "$1"
  echo "=========================================="
}

# 1. Environment Variables Check
print_section "1. Environment Variables"
echo "NODE_EXTRA_CA_CERTS: ${NODE_EXTRA_CA_CERTS:-not set}"
echo "NODE_USE_SYSTEM_CA: ${NODE_USE_SYSTEM_CA:-not set}"
echo "AWS_CA_BUNDLE: ${AWS_CA_BUNDLE:-not set}"
echo "CURL_CA_BUNDLE: ${CURL_CA_BUNDLE:-not set}"
echo "REQUESTS_CA_BUNDLE: ${REQUESTS_CA_BUNDLE:-not set}"

# 2. Curl Tests
print_section "2. cURL Tests"

echo "Testing HTTPS to Google..."
if curl -s -o /dev/null -w "%{http_code}" "$HTTPS_URL" >/dev/null 2>&1; then
  print_result 0 "curl - HTTPS to Google"
else
  print_result 1 "curl - HTTPS to Google"
fi

echo ""
echo "Testing HTTPS to AWS..."
if curl -s -o /dev/null -w "%{http_code}" "$AWS_URL" >/dev/null 2>&1; then
  print_result 0 "curl - HTTPS to AWS"
else
  print_result 1 "curl - HTTPS to AWS"
fi

# 3. Node.js Tests
print_section "3. Node.js Tests"

# Create temporary Node.js test script
cat >/tmp/test-node-certs.js <<'EOF'
const https = require('https');

function testUrl(url, name) {
    return new Promise((resolve, reject) => {
        https.get(url, (res) => {
            console.log(`${name}: ${res.statusCode}`);
            resolve(res.statusCode >= 200 && res.statusCode < 400);
        }).on('error', (err) => {
            console.error(`${name} error: ${err.message}`);
            reject(err);
        });
    });
}

(async () => {
    try {
        await testUrl('https://www.google.com', 'Google');
        await testUrl('https://s3.amazonaws.com', 'AWS S3');
        process.exit(0);
    } catch (err) {
        process.exit(1);
    }
})();
EOF

if node /tmp/test-node-certs.js 2>&1; then
  print_result 0 "Node.js HTTPS requests"
else
  print_result 1 "Node.js HTTPS requests"
fi

echo ""
echo "Testing with Node.js 22 (via mise)..."
if command -v mise &>/dev/null; then
  NODE22_VERSION=$(mise exec node@22 -- node --version 2>&1)
  echo "  Node version: $NODE22_VERSION"

  if mise exec node@22 -- node /tmp/test-node-certs.js 2>&1; then
    print_result 0 "Node.js 22 HTTPS requests"
  else
    print_result 1 "Node.js 22 HTTPS requests"
  fi
else
  echo -e "${YELLOW}⊘ SKIP${NC}: mise not available"
fi

rm -f /tmp/test-node-certs.js

# 4. Python Tests
print_section "4. Python Tests"

# Create temporary venv for requests testing
PYTHON_VENV_DIR=$(mktemp -d)
echo "Creating temporary Python venv for requests testing..."
if python3 -m venv "$PYTHON_VENV_DIR" >/dev/null 2>&1; then
  # Install requests in the venv
  if "$PYTHON_VENV_DIR/bin/pip" install --quiet requests 2>&1 | grep -v "WARNING"; then
    # Create temporary Python test script
    cat >/tmp/test-python-certs.py <<'EOF'
import sys
try:
    import requests

    print("Testing with requests library...")
    response = requests.get('https://www.google.com', timeout=10)
    print(f"Google: {response.status_code}")

    response = requests.get('https://s3.amazonaws.com', timeout=10)
    print(f"AWS S3: {response.status_code}")

    sys.exit(0)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
EOF

    if "$PYTHON_VENV_DIR/bin/python" /tmp/test-python-certs.py 2>&1; then
      print_result 0 "Python requests library"
    else
      print_result 1 "Python requests library"
    fi
  else
    echo -e "${YELLOW}⊘ SKIP${NC}: Failed to install Python requests module"
  fi

  # Clean up venv
  rm -rf "$PYTHON_VENV_DIR"
else
  echo -e "${YELLOW}⊘ SKIP${NC}: Failed to create Python virtual environment"
fi

# Also test with urllib
cat >/tmp/test-python-urllib.py <<'EOF'
import sys
import urllib.request
import socket

success_count = 0
print("Testing with urllib...")

# Test Google
try:
    with urllib.request.urlopen('https://www.google.com', timeout=10) as response:
        print(f"Google: {response.status}")
        success_count += 1
except socket.timeout:
    print("Google: timeout (network issue)")
except Exception as e:
    print(f"Google error: {e}")

# Test AWS S3
try:
    with urllib.request.urlopen('https://s3.amazonaws.com', timeout=10) as response:
        print(f"AWS S3: {response.status}")
        success_count += 1
except socket.timeout:
    print("AWS S3: timeout (network issue)")
except Exception as e:
    print(f"AWS S3 error: {e}")

# Pass if at least one HTTPS connection succeeded (proves cert validation works)
if success_count > 0:
    sys.exit(0)
else:
    sys.exit(1)
EOF

echo ""
if python3 /tmp/test-python-urllib.py 2>&1; then
  print_result 0 "Python urllib"
else
  print_result 1 "Python urllib (all connections failed)"
fi

# 5. AWS CLI Tests
print_section "5. AWS CLI Tests"

if command -v aws &>/dev/null; then
  echo "Testing AWS CLI with public S3 bucket (no credentials required)..."
  if AWS_S3_OUTPUT=$(aws s3 ls s3://commoncrawl/ --no-sign-request 2>&1 | head -5); then
    print_result 0 "AWS CLI - public S3 access"
    echo "  Successfully listed objects in public bucket"
  else
    # Check if it's a certificate error
    if echo "$AWS_S3_OUTPUT" | grep -qi "certificate\|ssl\|tls"; then
      print_result 1 "AWS CLI - public S3 (certificate error)"
      echo "  Error: Certificate validation failed"
    else
      print_result 1 "AWS CLI - public S3 access"
      echo "  Error: ${AWS_S3_OUTPUT:0:100}"
    fi
  fi
else
  echo -e "${YELLOW}⊘ SKIP${NC}: AWS CLI not installed"
fi

# 6. pnpm GitHub tarball fetch test
print_section "6. pnpm - GitHub Tarball Dependency"

# Standalone pnpm (installed via mise/asdf, not corepack) bundles its own Node
# runtime that ignores NODE_USE_SYSTEM_CA. It needs NODE_EXTRA_CA_CERTS to trust
# the Netskope proxy cert when fetching GitHub tarballs.
# Reproduces: cvent-internal/sourcegraph `pnpm install` failing with
# "FetchError: self-signed certificate in certificate chain"

if command -v mise &>/dev/null; then
  PNPM_TEST_DIR=$(mktemp -d)
  cat >"$PNPM_TEST_DIR/package.json" <<'PKGJSON'
{
  "private": true,
  "dependencies": {
    "prettier-plugin-packagejson": "github:cvent/prettier-plugin-packagejson#f7d8ea1c1bf9b8bcf0dd8119575241f615ebe507"
  }
}
PKGJSON

  # Test with standalone pnpm via mise (not corepack), which is how projects
  # like sourcegraph actually run pnpm
  echo "Testing standalone pnpm (via mise) with GitHub-hosted tarball..."
  PNPM_OUTPUT=$(mise exec pnpm@latest -- pnpm install --dir "$PNPM_TEST_DIR" 2>&1)
  PNPM_EXIT=$?

  if [ $PNPM_EXIT -eq 0 ]; then
    print_result 0 "pnpm install - GitHub tarball (cvent/prettier-plugin-packagejson)"
  else
    if echo "$PNPM_OUTPUT" | command grep -qi "self-signed certificate\|certificate"; then
      print_result 1 "pnpm install - GitHub tarball (certificate error)"
      echo "  Error: self-signed certificate in certificate chain"
      echo "  Hint: NODE_EXTRA_CA_CERTS must point to a CA bundle that includes the Netskope cert"
    else
      print_result 1 "pnpm install - GitHub tarball"
      echo "  Error: ${PNPM_OUTPUT:0:200}"
    fi
  fi

  rm -rf "$PNPM_TEST_DIR"
else
  echo -e "${YELLOW}⊘ SKIP${NC}: mise not available"
fi

# 7. Additional fetch methods
print_section "7. Additional Fetch Methods"

# git test (uses certificates for https operations)
echo "Testing git with HTTPS..."
if git ls-remote https://github.com/octocat/Hello-World.git HEAD >/dev/null 2>&1; then
  print_result 0 "git ls-remote over HTTPS"
else
  print_result 1 "git ls-remote over HTTPS"
fi

echo ""
echo "Testing Claude CLI (Native - Homebrew)..."
if [ -n "$CLAUDECODE" ]; then
  echo -e "${YELLOW}⊘ SKIP${NC}: Cannot test Claude CLI from within Claude Code session"
  echo "  Run this test from a regular terminal to verify Claude CLI certificate handling"
elif [ -f "/opt/homebrew/bin/claude" ]; then
  CLAUDE_VERSION=$(/opt/homebrew/bin/claude --version 2>&1)
  echo "  Native Claude version: $CLAUDE_VERSION"

  # Create MCP config for testing
  MCP_CONFIG="{\"mcpServers\":{\"github\":{\"type\":\"http\",\"url\":\"https://api.githubcopilot.com/mcp\",\"headers\":{\"Authorization\":\"Bearer ${GITHUB_MCP_TOKEN}\"}}}}"

  # Test 1: GitHub MCP connectivity
  if [ -n "$GITHUB_MCP_TOKEN" ]; then
    echo ""
    echo "  Testing GitHub MCP connection (streaming output)..."
    echo "  ---"
    /opt/homebrew/bin/claude --strict-mcp-config --mcp-config "$MCP_CONFIG" --print "Is the GitHub MCP server connected? Respond with SUCCESS or FAILURE" 2>&1 | tee /tmp/claude-mcp-test.log
    echo "  ---"

    # Check for positive indicators of successful GitHub MCP connection
    if grep -qi "SUCCESS" /tmp/claude-mcp-test.log; then
      print_result 0 "Native Claude - GitHub MCP connection"
    elif grep -qi "certificate\|ssl.*error\|unable to verify" /tmp/claude-mcp-test.log; then
      print_result 1 "Native Claude - GitHub MCP (certificate error)"
    else
      print_result 1 "Native Claude - GitHub MCP (no successful connection)"
      echo "  Did not detect SUCCESS response"
    fi

    rm -f /tmp/claude-mcp-test.log
  else
    echo -e "${YELLOW}⊘ SKIP${NC}: GITHUB_MCP_TOKEN not set for MCP test"
  fi

  # Test 2: Web fetch with restricted tools
  echo ""
  echo "  Testing web fetch capability (streaming output)..."
  echo "  ---"
  /opt/homebrew/bin/claude --tools WebFetch --allowedTools WebFetch --print "Fetch https://www.google.com and tell me if it succeeded. Reply with just SUCCESS or FAILED." 2>&1 | tee /tmp/claude-fetch-test.log
  echo "  ---"

  # Positive test: only pass if we see SUCCESS
  if grep -qi "SUCCESS" /tmp/claude-fetch-test.log; then
    print_result 0 "Native Claude - web fetch"
  elif grep -qi "certificate\|ssl.*error\|unable to verify" /tmp/claude-fetch-test.log; then
    print_result 1 "Native Claude - web fetch (certificate error)"
  else
    print_result 1 "Native Claude - web fetch (did not succeed)"
    echo "  Did not detect successful web fetch"
  fi

  rm -f /tmp/claude-fetch-test.log
else
  echo -e "${YELLOW}⊘ SKIP${NC}: Native Claude not installed at /opt/homebrew/bin/claude"
fi

echo ""
echo "Testing Claude CLI (Node-based)..."
if [ -n "$CLAUDECODE" ]; then
  echo -e "${YELLOW}⊘ SKIP${NC}: Cannot test Claude CLI from within Claude Code session"
  echo "  Run this test from a regular terminal to verify Claude CLI certificate handling"
elif command -v npm &>/dev/null; then
  CLAUDE_VERSION=$(npm exec --package=@anthropic-ai/claude-code --yes -- claude --version 2>&1)
  echo "  Node Claude version: $CLAUDE_VERSION"

  # Create MCP config for testing
  MCP_CONFIG="{\"mcpServers\":{\"github\":{\"type\":\"http\",\"url\":\"https://api.githubcopilot.com/mcp\",\"headers\":{\"Authorization\":\"Bearer ${GITHUB_MCP_TOKEN}\"}}}}"

  # Test 1: GitHub MCP connectivity
  if [ -n "$GITHUB_MCP_TOKEN" ]; then
    echo ""
    echo "  Testing GitHub MCP connection (streaming output)..."
    echo "  ---"
    npm exec --package=@anthropic-ai/claude-code --yes -- claude --strict-mcp-config --mcp-config "$MCP_CONFIG" --print "Is the GitHub MCP server connected? Respond with SUCCESS or FAILURE" 2>&1 | tee /tmp/claude-node-mcp-test.log
    echo "  ---"

    # Check for positive indicators of successful GitHub MCP connection
    if grep -qi "SUCCESS" /tmp/claude-node-mcp-test.log; then
      print_result 0 "Node Claude - GitHub MCP connection"
    elif grep -qi "certificate\|ssl.*error\|unable to verify" /tmp/claude-node-mcp-test.log; then
      print_result 1 "Node Claude - GitHub MCP (certificate error)"
    else
      print_result 1 "Node Claude - GitHub MCP (no successful connection)"
      echo "  Did not detect SUCCESS response"
    fi

    rm -f /tmp/claude-node-mcp-test.log
  else
    echo -e "${YELLOW}⊘ SKIP${NC}: GITHUB_MCP_TOKEN not set for MCP test"
  fi

  # Test 2: Web fetch with restricted tools
  echo ""
  echo "  Testing web fetch capability (streaming output)..."
  echo "  ---"
  npm exec --package=@anthropic-ai/claude-code --yes -- claude --tools WebFetch --allowedTools WebFetch --print "Fetch https://www.google.com and tell me if it succeeded. Reply with just SUCCESS or FAILED." 2>&1 | tee /tmp/claude-node-fetch-test.log
  echo "  ---"

  # Positive test: only pass if we see SUCCESS
  if grep -qi "SUCCESS" /tmp/claude-node-fetch-test.log; then
    print_result 0 "Node Claude - web fetch"
  elif grep -qi "certificate\|ssl.*error\|unable to verify" /tmp/claude-node-fetch-test.log; then
    print_result 1 "Node Claude - web fetch (certificate error)"
  else
    print_result 1 "Node Claude - web fetch (did not succeed)"
    echo "  Did not detect successful web fetch"
  fi

  rm -f /tmp/claude-node-fetch-test.log
else
  echo -e "${YELLOW}⊘ SKIP${NC}: npx not available"
fi

# 8. macOS Security Framework Test
print_section "8. macOS System Certificate Store"

echo "Checking if Netskope cert is in system keychain..."
if security find-certificate -c "ca.cvt.goskope.com" -a /Library/Keychains/System.keychain >/dev/null 2>&1; then
  print_result 0 "Netskope cert in system keychain"
else
  print_result 1 "Netskope cert not in system keychain"
fi

# Clean up
rm -f /tmp/test-python-certs.py /tmp/test-python-urllib.py

print_section "Test Suite Complete"
echo ""
echo "Total tests: $TOTAL_TESTS"
echo "Failed tests: $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -gt 0 ]; then
  echo -e "${RED}FAILED${NC}: $FAILED_TESTS test(s) failed"
  exit 1
else
  echo -e "${GREEN}SUCCESS${NC}: All tests passed"
  exit 0
fi
