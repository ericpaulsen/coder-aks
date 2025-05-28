module "vscode-web" {
  source         = "registry.coder.com/modules/vscode-web/coder"
  version        = "1.0.14"
  agent_id       = coder_agent.coder.id
  extensions     = ["github.copilot", "ms-python.python", "ms-toolsai.jupyter", "redhat.vscode-yaml"]
  accept_license = true
}

module "vscode" {
  source   = "registry.coder.com/modules/vscode-desktop/coder"
  version  = "1.0.15"
  agent_id = coder_agent.coder.id
}

module "jetbrains_gateway" {
  source         = "https://registry.coder.com/modules/jetbrains-gateway"
  agent_id       = coder_agent.coder.id
  agent_name     = "coder"
  folder         = "/home/coder"
  jetbrains_ides = ["GO", "WS", "IU", "PY"]
  default        = "PY"
}

data "coder_parameter" "jupyter" {
  name        = "Jupyter IDE type"
  type        = "string"
  description = "What type of Jupyter do you want?"
  mutable     = true
  default     = ""
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
  option {
    name  = "None"
    value = ""
  }
}

module "jupyterlab" {
  count = data.coder_parameter.jupyter.value == "lab" ? 1 : 0

  source   = "registry.coder.com/modules/jupyterlab/coder"
  version  = "1.0.19"
  agent_id = coder_agent.coder.id
}

module "jupyterlab-notebook" {
  count = data.coder_parameter.jupyter.value == "notebook" ? 1 : 0

  source   = "registry.coder.com/modules/jupyter-notebook/coder"
  version  = "1.0.19"
  agent_id = coder_agent.coder.id
}
