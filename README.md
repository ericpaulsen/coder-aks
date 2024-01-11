# Coder on Azure Kubernetes (K8s) Service

This repo is a deployment of Coder running on Azure AKS. The intention is to represent
an enterprise-grade deployment with configurations you'd expect from a Fortune 500 customer.
These may include:

- Multi-cloud, multi-platform workspace provisioning from a single control plane
- CI/CD pipeline to automate Terraform template lifecycle (coming soon)
- Externally hosted PostgreSQL
- TLS certificate configuration
- Single Sign-On via OpenID Connect

## Helm

`/helm` contains the `values.yaml` file used to configure the Coder K8s deployment and
application. I've included in-line comments to provide context for each of the sections
and environment variables. A few things to note:

- Primary endpoint is `eric-aks.demo.coder.com`, which points to an Azure Load Balancer service
- Deployment image is `ericpaulsen/coder-{latest-version}:az`, which includes `az` for remote execution
- GitHub, GitLab, and JFrog Artifactory are integrated to enable access from Coder workspaces
- Terraform authenticates to Azure via a managed identity set in `coder.podLabels`
- Application state is stored in Azure Postgres Single Server

`/cert-manager` stores YAML configuration for the `cert-manager` application, and is
responsible for issuing, rotating TLS certificates for Coder. The certificate is
created as a K8s TLS secret, and mounted into Coder via the `coder.tls.secretNames` value.

For more information on `cert-manager`, [see here](https://cert-manager.io/).

## Templates

Templates are a Coder construct constituted as Terraform files, which are used to
provision infrastructure for the cloud development environment (Coder workspace). They
are pushed into Coder via the following commands:

```console
coder login https://eric-aks.demo.coder.com
coder templates push <template-name>
```

Each template in `/templates` corresponds to a particular development workflow or use-case, spelled
out in the `README.md` file. Most templates are built as Kubernetes pods in the
AKS cluster where Coder is running.
