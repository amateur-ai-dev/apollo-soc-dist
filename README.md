# Apollo SOC

Agentic Compliance Harness for Multi-Framework Security Verification.

Apollo SOC orchestrates open-source security scanners, normalizes their output into a universal schema, maps findings to compliance controls across 25+ frameworks, and emits auditor-grade OSCAL evidence.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/amateur-ai-dev/apollo-soc-dist/main/bootstrap.sh | bash
```

### Prerequisites

- **GitHub CLI** (`gh`) — [install](https://cli.github.com)
- **Collaborator access** to the private repo (request from owner)
- macOS or Linux

### Options

```bash
# Install specific version
APOLLO_VERSION=v0.1.0 curl -fsSL https://raw.githubusercontent.com/amateur-ai-dev/apollo-soc-dist/main/bootstrap.sh | bash
```

## What It Does

| Capability | Details |
|---|---|
| **16 scanners** | SAST, DAST, SCA, IaC, containers, cloud, secrets, K8s, API fuzzing |
| **25+ frameworks** | NIST 800-53, PCI DSS v4, ISO 27001, SOC 2, HIPAA, CMMC, FedRAMP, OWASP ASVS, CIS |
| **OSCAL output** | Assessment Results, POA&M, SSP, Component Definitions |
| **Remediation** | CWE/OWASP mitigation DB, priority scoring, IaC patches |
| **Evidence** | Sigstore signing, transparency log, WORM storage |
| **Dashboard** | Real-time findings, compliance coverage, evidence timeline |

## Usage

```bash
# Start dashboard
apollo serve

# Scan a project
apollo scan /path/to/project

# Check scanner status
apollo scanners
```

## License

Proprietary. Access granted per-user.
