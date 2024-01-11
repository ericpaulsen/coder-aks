# Coder on Azure Kubernetes (K8s) Service

This repo intends to mimic an enterprise-grade Coder
deployment with configurations you'd expect from a Fortune 500 customer. These
typically include:

- Multi-cloud, multi-platform workspace provisioning
- CI/CD automation for template lifecycle and K8s deployment
- Externally hosted PostgreSQL
- TLS certificate configuration
- Single Sign-On via OpenID Connect

## Helm

`/helm` contains the `values.yaml` file used to configure the Coder K8s deployment and
application. It includes in-line comments with context on the sections
and environment variables. A few things to note:

- Primary endpoint is `eric-aks.demo.coder.com`, pointing to an Azure Load Balancer
- Deployment image is `ericpaulsen/coder-{latest-version}:az`, which includes `az` CLI
- GitHub, GitLab, and JFrog Artifactory integrations, accessible from Coder workspaces
- Terraform authenticates to Azure via a managed identity set in `coder.podLabels`
- Application state is stored in Azure Postgres Single Server

`/cert-manager` stores YAML configuration for the `cert-manager`, responsible
for issuing, rotating TLS certificates for Coder. The certificate is
created as a K8s TLS secret, and mounted into Coder using the `coder.tls.secretNames` value.

For more information on `cert-manager`, [see here](https://cert-manager.io/).

## Templates

Templates are a Coder construct represented as Terraform files, used to
provision infrastructure for the cloud development environment (Coder workspace).
Each template in `/templates` corresponds to a unique development workflow or
use-case, spelled out in the `README.md` file.

Templates are pushed into Coder on each commit via GitHub Actions configured in `.github/workflows/`.
The basic premise for this workflow is to push the template changes into Coder
via the below commands:

```fish
coder login https://eric-aks.demo.coder.com
coder templates push <template-name>
```
