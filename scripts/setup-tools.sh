#!/bin/bash
set -e

echo "Setting up tools..."

# Check for required system tools
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "Warning: $1 is not installed"
    return 1
  fi
  return 0
}

# jq is required
if ! check_command jq; then
  echo "Error: jq is required but not installed"
  echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
  exit 1
fi

# git is required
if ! check_command git; then
  echo "Error: git is required but not installed"
  exit 1
fi

# Install Python tools
echo "Installing Python tools..."
pip install --quiet --upgrade pip
pip install --quiet semgrep checkov pip-audit 2>/dev/null || {
  echo "Warning: Some Python tools failed to install"
}

# Check for Docker (optional, for Trivy and ZAP)
if check_command docker; then
  echo "Docker is available - Trivy and ZAP scans will be enabled"

  # Pull required images
  echo "Pulling Docker images..."
  docker pull --quiet aquasec/trivy:latest 2>/dev/null || echo "Warning: Failed to pull Trivy image"
  # ZAP image is large, only pull if not exists
  if ! docker image inspect ghcr.io/zaproxy/zaproxy:stable &> /dev/null; then
    echo "Pulling OWASP ZAP image (this may take a while)..."
    docker pull --quiet ghcr.io/zaproxy/zaproxy:stable 2>/dev/null || echo "Warning: Failed to pull ZAP image"
  fi
else
  echo "Warning: Docker is not available - Trivy and ZAP scans will be skipped"
fi

# Check for Nuclei (optional)
if ! check_command nuclei; then
  echo "Nuclei is not installed - attempting to install..."
  if check_command go; then
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest 2>/dev/null || {
      echo "Warning: Failed to install Nuclei via go"
    }
  else
    # Try downloading binary
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    case $ARCH in
      x86_64) ARCH="amd64" ;;
      arm64|aarch64) ARCH="arm64" ;;
    esac

    NUCLEI_VERSION="3.1.0"
    NUCLEI_URL="https://github.com/projectdiscovery/nuclei/releases/download/v${NUCLEI_VERSION}/nuclei_${NUCLEI_VERSION}_${OS}_${ARCH}.zip"

    if command -v curl &> /dev/null; then
      echo "Downloading Nuclei..."
      curl -sL "$NUCLEI_URL" -o /tmp/nuclei.zip && \
        unzip -q -o /tmp/nuclei.zip -d /tmp && \
        chmod +x /tmp/nuclei && \
        sudo mv /tmp/nuclei /usr/local/bin/ 2>/dev/null || {
          echo "Warning: Failed to install Nuclei"
        }
    fi
  fi
fi

# Update Nuclei templates if installed
if check_command nuclei; then
  echo "Updating Nuclei templates..."
  nuclei -update-templates -silent 2>/dev/null || true
fi

echo ""
echo "Tool setup completed!"
echo ""
echo "Installed tools:"
check_command semgrep && echo "  - semgrep: $(semgrep --version 2>/dev/null | head -1)"
check_command checkov && echo "  - checkov: $(checkov --version 2>/dev/null)"
check_command pip-audit && echo "  - pip-audit: installed"
check_command docker && echo "  - docker: $(docker --version)"
check_command nuclei && echo "  - nuclei: $(nuclei --version 2>/dev/null)"
