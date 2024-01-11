terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  cpu-limit      = "1"
  memory-limit   = "2G"
  cpu-request    = "250m"
  memory-request = "500Mi"
  home-volume    = "10Gi"
  image          = "codercom/enterprise-jupyter:ubuntu"
  repo           = "https://github.com/ericpaulsen/foodhub.git"
}

provider "coder" {

}

variable "use_kubeconfig" {
  type        = bool
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces.  A valid "~/.kube/config" must be present on the Coder host.
  EOF
  default     = false
}

data "coder_parameter" "dotfiles_url" {
  name        = "Dotfiles URL (optional)"
  description = "Personalize your workspace e.g., https://github.com/sharkymark/dotfiles.git"
  type        = "string"
  default     = ""
  mutable     = true
  icon        = "https://git-scm.com/images/logos/downloads/Git-Icon-1788C.png"
  order       = 3
}

data "coder_parameter" "jupyter" {
  name        = "Jupyter IDE type"
  type        = "string"
  description = "What type of Jupyter do you want?"
  mutable     = true
  default     = "lab"
  icon        = "/icon/jupyter.svg"
  order       = 1

  option {
    name  = "Jupyter Lab"
    value = "lab"
    icon  = "https://raw.githubusercontent.com/gist/egormkn/672764e7ce3bdaf549b62a5e70eece79/raw/559e34c690ea4765001d4ba0e715106edea7439f/jupyter-lab.svg"
  }
  option {
    name  = "Jupyter Notebook"
    value = "notebook"
    icon  = "https://codingbootcamps.io/wp-content/uploads/jupyter_notebook.png"
  }
}

data "coder_parameter" "appshare" {
  name        = "App Sharing"
  type        = "string"
  description = "What sharing level do you want for the IDEs?"
  mutable     = true
  default     = "owner"
  icon        = "/emojis/1f30e.png"

  option {
    name  = "Accessible outside the Coder deployment"
    value = "public"
    icon  = "/emojis/1f30e.png"
  }
  option {
    name  = "Accessible by authenticated users of the Coder deployment"
    value = "authenticated"
    icon  = "/emojis/1f465.png"
  }
  option {
    name  = "Only accessible by the workspace owner"
    value = "owner"
    icon  = "/emojis/1f510.png"
  }
  order = 2
}

locals {
  jupyter-type-arg = data.coder_parameter.jupyter.value == "notebook" ? "Notebook" : "Server"
}


provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}

data "coder_external_auth" "github" {
  # Matches the ID of the git auth provider in Coder.
  id = "github"
}

resource "coder_agent" "coder" {
  os   = "linux"
  arch = "amd64"

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  display_apps {
    vscode                 = false
    vscode_insiders        = false
    ssh_helper             = false
    port_forwarding_helper = false
    web_terminal           = true
  }

  dir = "/home/coder"
  env = {

  }
  startup_script_behavior = "blocking"
  startup_script_timeout  = 300
  startup_script          = <<EOF
#!/bin/sh

set -e

# start jupyter 
jupyter ${data.coder_parameter.jupyter.value} --${local.jupyter-type-arg}App.token="" --ip="*" >/dev/null 2>&1 &

# add some Python libraries
pip3 install --user pandas &
pip3 install --user numpy &
pip3 install --user matplotlib &
pip3 install --user seaborn &

# clone repo
if [ ! -d "pandas_automl" ]; then
  git clone --progress https://github.com/ericpaulsen/foodhub.git &
fi

# install and code-server, VS Code in a browser 
curl -fsSL https://code-server.dev/install.sh | sh
code-server --auth none --port 13337 >/dev/null 2>&1 &

# install VS Code extensions into code-server
SERVICE_URL=https://open-vsx.org/vscode/gallery ITEM_URL=https://open-vsx.org/vscode/item code-server --install-extension ms-toolsai.jupyter 
SERVICE_URL=https://open-vsx.org/vscode/gallery ITEM_URL=https://open-vsx.org/vscode/item code-server --install-extension ms-python.python 

# use coder CLI to clone and install dotfiles
if [ ! -z "${data.coder_parameter.dotfiles_url.value}" ]; then
  coder dotfiles -y ${data.coder_parameter.dotfiles_url.value}
fi

EOF
}

# code-server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.coder.id
  slug         = "cs"
  display_name = "code-server"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=/home/coder"
  share        = data.coder_parameter.appshare.value
  subdomain    = false

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "coder_app" "jupyter" {
  agent_id     = coder_agent.coder.id
  slug         = "j"
  display_name = "jupyter ${data.coder_parameter.jupyter.value}"
  icon         = "/icon/jupyter.svg"
  url          = "http://localhost:8888/"
  share        = data.coder_parameter.appshare.value
  subdomain    = true

  healthcheck {
    url       = "http://localhost:8888/healthz/"
    interval  = 10
    threshold = 20
  }
}

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
    namespace = "coder"
  }
  spec {
    security_context {
      run_as_user = "1000"
      fs_group    = "1000"
    }
    container {
      name              = "coder-container"
      image             = local.image
      command           = ["sh", "-c", coder_agent.coder.init_script]
      image_pull_policy = "Always"
      security_context {
        run_as_user = "1000"
      }
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.coder.token
      }
      resources {
        requests = {
          cpu    = local.cpu-request
          memory = local.memory-request
        }
        limits = {
          cpu    = local.cpu-limit
          memory = local.memory-limit
        }
      }
      volume_mount {
        mount_path = "/home/coder"
        name       = "home-directory"
      }
    }
    volume {
      name = "home-directory"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home-directory.metadata.0.name
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "home-directory" {
  metadata {
    name      = "home-coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
    namespace = "coder"
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = local.home-volume
      }
    }
  }
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_pod.main[0].id
  item {
    key   = "image"
    value = local.image
  }
  item {
    key   = "repo cloned"
    value = local.repo
  }
}




