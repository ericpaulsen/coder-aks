terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.18.0"
    }
  }
}

resource "null_resource" "example1" {
  provisioner "local-exec" {
    command     = "/usr/bin/coder agent &>/dev/null &"
    interpreter = ["sh", "-c"]
    environment = {
      CODER_AGENT_TOKEN = coder_agent.main.token
      CODER_AGENT_URL   = data.coder_workspace.me.access_url
    }
  }
}

data "coder_workspace" "me" {}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"

  startup_script = <<-EOT
    set -e
 
    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337 >/dev/null 2>&1 &
 
  EOT
}

# code-server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=~/"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}
