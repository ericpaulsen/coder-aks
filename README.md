# [Coder](https://coder.com) on Azure Kubernetes (K8s) Service

This repo intends to mimic an enterprise-grade Coder
deployment with configurations you'd expect from a Fortune 500 customer. These
typically include:

- Multi-cloud, multi-platform workspace provisioning ([see my webinar on this topic here](https://coder.com/webinars/multi-platform-multi-cloud-development-environments-with-coder/register))
- CI/CD automation for template lifecycle and K8s deployment
- Microsoft Entra ID Single Sign-On
- Microsoft Entra Workload ID for keyless Terraform authentication to Azure
- Managed PostgreSQL
- TLS certificates

## Install Coder on AKS

These steps reproduce the deployment in this repo. Replace the example names
and the `<placeholders>` in [`helm/values.yaml`](./helm/values.yaml) with your
own values.

1. Create an AKS cluster with the OIDC issuer and workload identity enabled:

   ```sh
   az group create --name coder-rg --location eastus2
   az aks create --resource-group coder-rg --name coder-aks \
     --enable-oidc-issuer --enable-workload-identity \
     --generate-ssh-keys
   az aks get-credentials --resource-group coder-rg --name coder-aks
   kubectl create namespace coder
   ```

1. Create a user-assigned managed identity for Terraform, grant it access to
   the subscription, and federate it with the `coder` service account:

   ```sh
   az identity create --resource-group coder-rg --name coder-provisioner
   CLIENT_ID=$(az identity show -g coder-rg -n coder-provisioner --query clientId -o tsv)
   PRINCIPAL_ID=$(az identity show -g coder-rg -n coder-provisioner --query principalId -o tsv)
   az role assignment create --assignee-object-id "$PRINCIPAL_ID" \
     --assignee-principal-type ServicePrincipal --role Contributor \
     --scope "/subscriptions/$(az account show --query id -o tsv)"
   az identity federated-credential create --resource-group coder-rg \
     --identity-name coder-provisioner --name coder \
     --issuer "$(az aks show -g coder-rg -n coder-aks --query oidcIssuerProfile.issuerUrl -o tsv)" \
     --subject system:serviceaccount:coder:coder \
     --audience api://AzureADTokenExchange
   ```

   Set `coder.serviceAccount.annotations` to `$CLIENT_ID` and
   `ARM_SUBSCRIPTION_ID` to your subscription ID in `helm/values.yaml`.
   Scope the role assignment down from `Contributor` if your templates need
   fewer permissions.

1. Create an [Azure Database for PostgreSQL Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/quickstart-create-server)
   that the cluster can reach, and store its connection URL as a secret.
   Flexible Server requires TLS, so keep `sslmode=require`:

   ```sh
   kubectl create secret generic azure-db-url -n coder \
     --from-literal=url="postgres://<user>:<password>@<server>.postgres.database.azure.com:5432/coder?sslmode=require"
   ```

1. Install [cert-manager](https://cert-manager.io/docs/installation/helm/),
   then apply the issuer and certificate in [`helm/cert-manager`](./helm/cert-manager).
   The example issuer solves DNS-01 challenges with Google Cloud DNS. If your
   zone is in Azure DNS, use the cert-manager
   [Azure DNS solver](https://cert-manager.io/docs/configuration/acme/dns01/azuredns/) instead.

1. Create the secrets that `helm/values.yaml` references for OIDC
   (`azure-ad-secret`) and external auth (`github-secret`, `gitlab-secret`,
   `jfrog-secret`). Remove the env vars for any integration you don't use.

1. Install Coder:

   ```sh
   helm repo add coder-v2 https://helm.coder.com/v2
   helm repo update
   helm install coder coder-v2/coder --namespace coder \
     --values helm/values.yaml --version <coder-version>
   ```

1. Point DNS for the access URL and wildcard access URL at the load balancer
   IP from `kubectl get svc coder -n coder`.

1. Optionally, install [coder-logstream-kube](https://github.com/coder/coder-logstream-kube)
   to stream Kubernetes pod events into workspace startup logs:

   ```sh
   helm repo add coder-logstream-kube https://helm.coder.com/logstream-kube
   helm install coder-logstream-kube coder-logstream-kube/coder-logstream-kube \
     --namespace coder --values helm/coder-logstream-kube/values.yaml
   ```

For a smaller proof of concept behind an Azure Application Gateway, see
[Deploy Coder on Azure with an Application Gateway](https://coder.com/docs/install/server/kubernetes/kubernetes-azure-app-gateway).

## Helm

`/helm` contains the `values.yaml` file used to configure the Coder K8s deployment and
application. In-line comments provide context on the various sections
and environment variables. A few things to note:

- Primary endpoint is `eric-aks.demo.coder.com`, pointing to an Azure Load Balancer
- Coder image is `ericpaulsen/coder-multi-cloud:<coder-version>`, which includes `az` & `gcloud` CLIs
- GCP, GKE service account key and `kubeconfig` is mounted into the Coder pod
- GitHub, GitLab, and JFrog Artifactory integrations enable access from Coder workspaces
- Terraform authenticates to Azure with Microsoft Entra Workload ID, configured
  by the `azure.workload.identity/use` pod label and the
  `azure.workload.identity/client-id` service account annotation
- Application state is stored in Azure Database for PostgreSQL Flexible Server

`/cert-manager` stores YAML configuration for the `cert-manager`, responsible
for issuing, rotating TLS certificates for Coder. The certificate is created as
a K8s TLS secret, and mounted into Coder using the `coder.tls.secretNames` value.

For more information on `cert-manager`, [see here](https://cert-manager.io/).

## Templates

Templates are a Coder construct represented as Terraform files, used to
provision infrastructure for the cloud development environment (Coder workspace).
Each template in `/templates` corresponds to a unique development workflow or
use-case, spelled out in the `README.md` file.

## CI/CD Automation

Templates are pushed into Coder on each commit via GitHub Actions configured in
`.github/workflows/`. The basic premise for this workflow is to push the template
changes into Coder via the below commands:

```fish
coder login https://eric-aks.demo.coder.com
coder templates push <template-name>
```
