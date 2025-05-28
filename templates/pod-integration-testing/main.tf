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

provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "disk_size" {
  name        = "PVC storage size"
  type        = "number"
  description = "Number of GB of storage for /home/coder and this will persist even when the workspace's Kubernetes pod and container are shutdown and deleted"
  icon        = "https://www.pngall.com/wp-content/uploads/5/Database-Storage-PNG-Clipart.png"
  validation {
    min       = 1
    max       = 20
    monotonic = "increasing"
  }
  mutable = true
  default = 10
  order   = 3
}

# Minimum vCPUs needed 
data "coder_parameter" "cpu" {
  name        = "CPU cores"
  type        = "number"
  description = "CPU cores for your individual workspace"
  icon        = "https://png.pngtree.com/png-clipart/20191122/original/pngtree-processor-icon-png-image_5165793.jpg"
  validation {
    min = 2
    max = 4
  }
  mutable = true
  default = 2
  order   = 1
}

# Minimum GB memory needed 
data "coder_parameter" "memory" {
  name        = "Memory (__ GB)"
  type        = "number"
  description = "Memory (__ GB) for your individual workspace"
  icon        = "https://www.vhv.rs/dpng/d/33-338595_random-access-memory-logo-hd-png-download.png"
  validation {
    min = 4
    max = 8
  }
  mutable = true
  default = 4
  order   = 2
}

data "coder_parameter" "image" {
  name        = "Container Image"
  type        = "string"
  description = "What container image and language do you want?"
  mutable     = true
  default     = "codercom/enterprise-base:ubuntu"
  icon        = "https://www.docker.com/wp-content/uploads/2022/03/vertical-logo-monochromatic.png"

  option {
    name  = "Node React"
    value = "codercom/enterprise-node:latest"
    icon  = "https://cdn.freebiesupply.com/logos/large/2x/nodejs-icon-logo-png-transparent.png"
  }
  option {
    name  = "Golang"
    value = "codercom/enterprise-golang:latest"
    icon  = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Go_Logo_Blue.svg/1200px-Go_Logo_Blue.svg.png"
  }
  option {
    name  = "Java"
    value = "codercom/enterprise-java:latest"
    icon  = "https://assets.stickpng.com/images/58480979cef1014c0b5e4901.png"
  }
  option {
    name  = "Base including Python"
    value = "codercom/enterprise-base:ubuntu"
    icon  = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Python-logo-notext.svg/1869px-Python-logo-notext.svg.png"
  }
  order = 4
}

# New parameter for enabling services
data "coder_parameter" "enable_services" {
  name        = "Development Services"
  type        = "string"
  description = "Enable development services (PostgreSQL, Redis, Mock APIs)"
  mutable     = true
  default     = "full"
  icon        = "https://cdn-icons-png.flaticon.com/512/1048/1048953.png"

  option {
    name  = "Full Stack (PostgreSQL + Redis + Mock APIs)"
    value = "full"
    icon  = "https://cdn-icons-png.flaticon.com/512/1048/1048953.png"
  }
  option {
    name  = "Database Only (PostgreSQL + Redis)"
    value = "database"
    icon  = "https://www.postgresql.org/media/img/about/press/elephant.png"
  }
  option {
    name  = "None"
    value = "none"
    icon  = "https://cdn-icons-png.flaticon.com/512/1828/1828843.png"
  }
  order = 7
}

data "coder_external_auth" "github" {
  id       = "github"
  optional = true
}

data "coder_external_auth" "jfrog" {
  id       = "jfrog"
  optional = true
}

module "dotfiles" {
  source   = "registry.coder.com/modules/dotfiles/coder"
  version  = "1.0.18"
  agent_id = coder_agent.coder.id
}

data "coder_parameter" "repo" {
  name        = "Source Code Repository"
  type        = "string"
  description = "What source code repository do you want to clone?"
  mutable     = true
  default     = "https://github.com/coder/coder"
  icon        = "https://avatars.githubusercontent.com/u/95932066?s=200&v=4"

  option {
    name  = "PAC-MAN"
    value = "https://github.com/coder/pacman-nodejs"
    icon  = "https://assets.stickpng.com/images/5a18871c8d421802430d2d05.png"
  }
  option {
    name  = "Coder v2 OSS project"
    value = "https://github.com/coder/coder"
    icon  = "https://avatars.githubusercontent.com/u/95932066?s=200&v=4"
  }
  option {
    name  = "Coder code-server project"
    value = "https://github.com/coder/code-server"
    icon  = "https://avatars.githubusercontent.com/u/95932066?s=200&v=4"
  }
  order = 5
}

locals {
  folder_name     = try(element(split("/", data.coder_parameter.repo.value), length(split("/", data.coder_parameter.repo.value)) - 1), "")
  repo_owner_name = try(element(split("/", data.coder_parameter.repo.value), length(split("/", data.coder_parameter.repo.value)) - 2), "")
}

module "git-clone" {
  source   = "registry.coder.com/modules/git-clone/coder"
  version  = "1.0.18"
  agent_id = coder_agent.coder.id
  url      = data.coder_parameter.repo.value
}

data "coder_parameter" "location" {
  name         = "location"
  display_name = "Workspace Location"
  description  = "Location to deploy workspace into."
  default      = "central"
  icon         = "/icon/desktop.svg"
  mutable      = true
  option {
    icon  = "/icon/azure.png"
    name  = "Azure West"
    value = "west"
  }
  option {
    icon  = "/icon/gcp.png"
    name  = "GCP East"
    value = "east"
  }
  option {
    icon  = "/icon/aws.png"
    name  = "AWS Central"
    value = "central"
  }
  option {
    icon  = "/icon/aws.png"
    name  = "AWS EU-London"
    value = "eu"
  }
  order = 6
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

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  # Add database connection metadata when services are enabled
  dynamic "metadata" {
    for_each = data.coder_parameter.enable_services.value != "none" ? [1] : []
    content {
      display_name = "Database Status"
      key          = "7_database_status"
      script       = <<EOT
        if nc -z localhost 5432 2>/dev/null; then
          echo "✅ PostgreSQL: Connected"
        else
          echo "❌ PostgreSQL: Disconnected"
        fi
      EOT
      interval     = 30
      timeout      = 5
    }
  }

  dynamic "metadata" {
    for_each = data.coder_parameter.enable_services.value != "none" ? [1] : []
    content {
      display_name = "Cache Status"
      key          = "8_redis_status"
      script       = <<EOT
        if nc -z localhost 6379 2>/dev/null; then
          echo "✅ Redis: Connected"
        else
          echo "❌ Redis: Disconnected"
        fi
      EOT
      interval     = 30
      timeout      = 5
    }
  }

  display_apps {
    vscode                 = false
    vscode_insiders        = false
    ssh_helper             = true
    port_forwarding_helper = true
    web_terminal           = true
  }

  dir                     = "/home/coder"
  startup_script_behavior = "blocking"
  startup_script          = <<EOT
# install and code-server, VS Code in a browser 
curl -fsSL https://code-server.dev/install.sh | sh
code-server --auth none --port 13337 >/dev/null 2>&1 &

# Install database clients if services are enabled
if [ "${data.coder_parameter.enable_services.value}" != "none" ]; then
  # Install PostgreSQL client
  sudo apt-get update -qq
  sudo apt-get install -y postgresql-client redis-tools netcat-openbsd curl
  
  # Wait for services to be ready
  echo "Waiting for services to start..."
  sleep 10
  
  # Create development database and user
  export PGPASSWORD=devpassword
  until pg_isready -h localhost -p 5432 -U postgres; do
    echo "Waiting for PostgreSQL..."
    sleep 2
  done
  
  # Create development database
  createdb -h localhost -U postgres -O postgres devdb 2>/dev/null || echo "Database 'devdb' already exists"
  
  # Test Redis connection
  redis-cli -h localhost -p 6379 ping
  
  echo "✅ Development services are ready!"
  echo "📊 PostgreSQL: localhost:5432 (user: postgres, password: devpassword, db: devdb)"
  echo "🔴 Redis: localhost:6379"
  if [ "${data.coder_parameter.enable_services.value}" = "full" ]; then
    # Wait for mock API services
    echo "Waiting for Mock API services..."
    for i in {1..30}; do
      if nc -z localhost 3001 2>/dev/null; then
        echo "✅ Mock API: http://localhost:3001"
        break
      fi
      echo "Waiting for Mock API... ($i/30)"
      sleep 2
    done
    
    for i in {1..30}; do
      if nc -z localhost 3002 2>/dev/null; then
        echo "✅ JSON Server: http://localhost:3002"
        break
      fi
      echo "Waiting for JSON Server... ($i/30)"
      sleep 2
    done
  fi
fi

coder login ${data.coder_workspace.me.access_url} --token ${data.coder_workspace_owner.me.session_token}
  EOT  
}

variable "workspace_namespace" {
  description = <<-EOF
  Kubernetes namespace to deploy the workspace into

  EOF
  default     = ""
}

locals {
  # This is the init script for the main workspace container that runs before the
  # agent starts to configure workspace process logging.
  exectrace_init_script = <<EOT
    set -eu
    pidns_inum=$(readlink /proc/self/ns/pid | sed 's/[^0-9]//g')
    if [ -z "$pidns_inum" ]; then
      echo "Could not determine process ID namespace inum"
      exit 1
    fi

    # Before we start the script, does curl exist?
    if ! command -v curl >/dev/null 2>&1; then
      echo "curl is required to download the Coder binary"
      echo "Please install curl to your image and try again"
      # 127 is command not found.
      exit 127
    fi

    echo "Sending process ID namespace inum to exectrace sidecar"
    rc=0
    max_retry=5
    counter=0
    until [ $counter -ge $max_retry ]; do
      set +e
      curl \
        --fail \
        --silent \
        --connect-timeout 5 \
        -X POST \
        -H "Content-Type: text/plain" \
        --data "$pidns_inum" \
        http://127.0.0.1:56123
      rc=$?
      set -e
      if [ $rc -eq 0 ]; then
        break
      fi

      counter=$((counter+1))
      echo "Curl failed with exit code $${rc}, attempt $${counter}/$${max_retry}; Retrying in 3 seconds..."
      sleep 3
    done
    if [ $rc -ne 0 ]; then
      echo "Failed to send process ID namespace inum to exectrace sidecar"
      exit $rc
    fi

  EOT 
}

# All services now run as sidecar containers in the main deployment

resource "kubernetes_deployment" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim.home-directory
  ]
  wait_for_rollout = false
  metadata {
    name      = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    namespace = var.workspace_namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
        "app.kubernetes.io/part-of"  = "coder"
        "com.coder.resource"         = "true"
        "com.coder.workspace.id"     = data.coder_workspace.me.id
        "com.coder.workspace.name"   = data.coder_workspace.me.name
        "com.coder.user.id"          = data.coder_workspace_owner.me.id
        "com.coder.user.username"    = data.coder_workspace_owner.me.name
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "coder-workspace"
          "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
          "app.kubernetes.io/part-of"  = "coder"
          "com.coder.resource"         = "true"
          "com.coder.workspace.id"     = data.coder_workspace.me.id
          "com.coder.workspace.name"   = data.coder_workspace.me.name
          "com.coder.user.id"          = data.coder_workspace_owner.me.id
          "com.coder.user.username"    = data.coder_workspace_owner.me.name
        }
      }
      spec {
        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        container {
          name              = "coder-container"
          image             = data.coder_parameter.image.value
          image_pull_policy = "Always"
          command = [
            "sh",
            "-c",
            "${local.exectrace_init_script}\n\n${coder_agent.coder.init_script}"
          ]
          security_context {
            run_as_user = "1000"
          }
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.coder.token
          }

          # Add database connection environment variables
          dynamic "env" {
            for_each = data.coder_parameter.enable_services.value != "none" ? [1] : []
            content {
              name  = "DATABASE_URL"
              value = "postgresql://postgres:devpassword@localhost:5432/devdb"
            }
          }

          dynamic "env" {
            for_each = data.coder_parameter.enable_services.value != "none" ? [1] : []
            content {
              name  = "REDIS_URL"
              value = "redis://localhost:6379"
            }
          }

          dynamic "env" {
            for_each = data.coder_parameter.enable_services.value == "full" ? [1] : []
            content {
              name  = "MOCK_API_URL"
              value = "http://localhost:3001"
            }
          }

          dynamic "env" {
            for_each = data.coder_parameter.enable_services.value == "full" ? [1] : []
            content {
              name  = "JSON_SERVER_URL"
              value = "http://localhost:3002"
            }
          }

          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home-directory"
            read_only  = false
          }
        }

        # PostgreSQL sidecar container
        dynamic "container" {
          for_each = data.coder_parameter.enable_services.value != "none" ? [1] : []
          content {
            name  = "postgresql"
            image = "postgres:15"

            env {
              name  = "POSTGRES_PASSWORD"
              value = "devpassword"
            }
            env {
              name  = "POSTGRES_USER"
              value = "postgres"
            }
            env {
              name  = "POSTGRES_DB"
              value = "devdb"
            }
            env {
              name  = "PGDATA"
              value = "/var/lib/postgresql/data/pgdata"
            }

            resources {
              requests = {
                memory = "256Mi"
                cpu    = "100m"
              }
              limits = {
                memory = "512Mi"
                cpu    = "500m"
              }
            }

            volume_mount {
              name       = "postgres-data"
              mount_path = "/var/lib/postgresql/data"
            }
          }
        }

        # Redis sidecar container
        dynamic "container" {
          for_each = data.coder_parameter.enable_services.value != "none" ? [1] : []
          content {
            name  = "redis"
            image = "redis:7-alpine"

            resources {
              requests = {
                memory = "128Mi"
                cpu    = "50m"
              }
              limits = {
                memory = "256Mi"
                cpu    = "200m"
              }
            }
          }
        }

        # Mock API sidecar container
        dynamic "container" {
          for_each = data.coder_parameter.enable_services.value == "full" ? [1] : []
          content {
            name  = "mock-api"
            image = "node:18-alpine"

            working_dir = "/tmp"

            command = ["/bin/sh"]
            args = ["-c", <<-EOT
              cd /tmp
              echo "Starting Mock API server setup..."
              npm init -y > /dev/null 2>&1
              echo "Installing dependencies..."
              npm install express cors body-parser > /dev/null 2>&1
              echo "Creating server file..."
              cat > server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Sample data
const users = [
  { id: 1, name: 'John Doe', email: 'john@example.com' },
  { id: 2, name: 'Jane Smith', email: 'jane@example.com' }
];

const products = [
  { id: 1, name: 'Laptop', price: 999.99, category: 'Electronics' },
  { id: 2, name: 'Book', price: 19.99, category: 'Education' }
];

// Routes
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.get('/api/users', (req, res) => {
  res.json(users);
});

app.get('/api/users/:id', (req, res) => {
  const user = users.find(u => u.id === parseInt(req.params.id));
  user ? res.json(user) : res.status(404).json({ error: 'User not found' });
});

app.get('/api/products', (req, res) => {
  res.json(products);
});

app.post('/api/users', (req, res) => {
  const newUser = { id: users.length + 1, ...req.body };
  users.push(newUser);
  res.status(201).json(newUser);
});

app.get('/', (req, res) => {
  res.json({
    message: 'Mock API Server',
    endpoints: [
      'GET /api/health',
      'GET /api/users',
      'GET /api/users/:id',
      'POST /api/users',
      'GET /api/products'
    ]
  });
});

const PORT = 3001;
app.listen(PORT, '0.0.0.0', () => {
  console.log('Mock API server running on port ' + PORT);
});
EOF
              echo "Starting Mock API server..."
              node server.js
            EOT
            ]

            resources {
              requests = {
                memory = "128Mi"
                cpu    = "50m"
              }
              limits = {
                memory = "256Mi"
                cpu    = "200m"
              }
            }
          }
        }

        # JSON Server sidecar container
        dynamic "container" {
          for_each = data.coder_parameter.enable_services.value == "full" ? [1] : []
          content {
            name  = "json-server"
            image = "node:18-alpine"

            working_dir = "/tmp"

            command = ["/bin/sh"]
            args = ["-c", <<-EOT
              cd /tmp
              echo "Installing JSON Server..."
              npm install -g json-server > /dev/null 2>&1
              echo "Checking npm global path..."
              NPM_GLOBAL_PATH=$(npm root -g)
              echo "NPM global path: $NPM_GLOBAL_PATH"
              echo "Creating database file..."
              cat > db.json << 'EOF'
{
  "posts": [
    { "id": 1, "title": "Hello World", "content": "This is a sample post", "author": "John Doe" },
    { "id": 2, "title": "Second Post", "content": "Another sample post", "author": "Jane Smith" }
  ],
  "comments": [
    { "id": 1, "postId": 1, "body": "Great post!", "author": "Alice" },
    { "id": 2, "postId": 1, "body": "Thanks for sharing", "author": "Bob" }
  ],
  "profile": {
    "name": "Mock API Profile",
    "version": "1.0.0"
  }
}
EOF
              echo "Starting JSON Server..."
              # Try different paths for json-server
              if command -v json-server >/dev/null 2>&1; then
                json-server --watch db.json --host 0.0.0.0 --port 3002
              elif [ -f "/usr/local/bin/json-server" ]; then
                /usr/local/bin/json-server --watch db.json --host 0.0.0.0 --port 3002
              elif [ -f "$NPM_GLOBAL_PATH/.bin/json-server" ]; then
                $NPM_GLOBAL_PATH/.bin/json-server --watch db.json --host 0.0.0.0 --port 3002
              else
                echo "json-server not found in expected locations"
                echo "Available files in /usr/local/bin:"
                ls -la /usr/local/bin/ | grep json || echo "No json-server found"
                echo "Available files in npm global .bin:"
                ls -la $NPM_GLOBAL_PATH/.bin/ | grep json || echo "No json-server found in npm global"
                # Try to run it with npx as fallback
                npx json-server --watch db.json --host 0.0.0.0 --port 3002
              fi
            EOT
            ]

            resources {
              requests = {
                memory = "128Mi"
                cpu    = "50m"
              }
              limits = {
                memory = "256Mi"
                cpu    = "200m"
              }
            }
          }
        }
        container {
          name              = "exectrace"
          image             = "ghcr.io/coder/exectrace:latest"
          image_pull_policy = "Always"
          command = [
            "/opt/exectrace",
            "--init-address", "127.0.0.1:56123",
            "--label", "workspace_id=${data.coder_workspace.me.id}",
            "--label", "workspace_name=${data.coder_workspace.me.name}",
            "--label", "user_id=${data.coder_workspace_owner.me.id}",
            "--label", "username=${data.coder_workspace_owner.me.name}",
            "--label", "user_email=${data.coder_workspace_owner.me.email}",
          ]
          security_context {
            run_as_user  = "0"
            run_as_group = "0"
            privileged   = true
          }
          #Process logging env variables
          env {
            name  = "CODER_AGENT_SUBSYSTEM"
            value = "exectrace"
          }
        }

        # Add postgres data volume
        dynamic "volume" {
          for_each = data.coder_parameter.enable_services.value != "none" ? [1] : []
          content {
            name = "postgres-data"
            empty_dir {}
          }
        }

        volume {
          name = "home-directory"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home-directory.metadata.0.name
          }
        }

        # Sidecar process logging container

        affinity {
          // This affinity attempts to spread out all workspace pods evenly across
          // nodes.
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "home-directory" {
  metadata {
    name      = lower("home-coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}")
    namespace = var.workspace_namespace
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.disk_size.value}Gi"
      }
    }
  }
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_deployment.main[0].id
  item {
    key   = "image"
    value = data.coder_parameter.image.value
  }
  item {
    key   = "repo cloned"
    value = "${local.repo_owner_name}/${local.folder_name}"
  }
  item {
    key   = "services"
    value = data.coder_parameter.enable_services.value
  }

  # Add service connection info
  dynamic "item" {
    for_each = data.coder_parameter.enable_services.value != "none" ? [1] : []
    content {
      key   = "database"
      value = "PostgreSQL on localhost:5432 (user: postgres, db: devdb)"
    }
  }

  dynamic "item" {
    for_each = data.coder_parameter.enable_services.value != "none" ? [1] : []
    content {
      key   = "cache"
      value = "Redis on localhost:6379"
    }
  }

  dynamic "item" {
    for_each = data.coder_parameter.enable_services.value == "full" ? [1] : []
    content {
      key   = "mock_apis"
      value = "Mock API: :3001, JSON Server: :3002"
    }
  }
}
