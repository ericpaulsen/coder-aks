# Coder Full Stack Development Template

## Overview

This Terraform template provides a comprehensive cloud development environment for full stack projects using Coder. It creates containerized workspaces with integrated development services including PostgreSQL, Redis, and mock APIs for seamless development and testing workflows.

## Architecture

### Core Components

- **Main Workspace Container**: Primary development environment with your chosen language stack
- **PostgreSQL Sidecar**: Database service for data persistence and testing
- **Redis Sidecar**: Caching layer for performance optimization
- **Mock API Services**: RESTful APIs for integration testing and prototyping
- **Code Server**: VS Code in the browser for remote development

### Service Communication

All services communicate via `localhost` within the shared pod network:
- **Database**: `localhost:5432`
- **Cache**: `localhost:6379`
- **Mock API**: `localhost:3001`
- **JSON Server**: `localhost:3002`
- **Code Server**: `localhost:13337`

## Features

### 🎛️ Configurable Service Stack

Choose from three deployment options:

| Option | PostgreSQL | Redis | Mock APIs | Use Case |
|--------|------------|-------|-----------|----------|
| **Full Stack** | ✅ | ✅ | ✅ | Complete development environment |
| **Database Only** | ✅ | ✅ | ❌ | Backend development focus |
| **None** | ❌ | ❌ | ❌ | Minimal development setup |

### 🐳 Multi-Language Support

Pre-configured container images for various technology stacks:

- **Node.js + React**: `codercom/enterprise-node:latest`
- **Go**: `codercom/enterprise-golang:latest`
- **Java**: `codercom/enterprise-java:latest`
- **Python + Base Tools**: `codercom/enterprise-base:ubuntu`

### 🌍 Multi-Region Deployment

Deploy workspaces across different cloud regions:

- **Azure West**: For Asia-Pacific proximity
- **GCP East**: For Americas coverage
- **AWS Central**: Primary deployment region
- **AWS EU-London**: For European compliance

### 📊 Real-Time Monitoring

Built-in workspace monitoring includes:

- CPU usage (workspace and host)
- Memory utilization
- Disk space monitoring
- Database connection status
- Cache connectivity health
- Load average tracking

## Quick Start

### Prerequisites

- Coder platform access with workspace creation permissions
- Kubernetes cluster with appropriate RBAC (deployment permissions required)
- Container registry access for pulling base images

### Deployment Steps

1. **Create New Template**
   ```bash
   coder templates create hkjc-dev-template
   ```

2. **Configure Parameters**
   - **CPU Cores**: 2-4 cores (default: 2)
   - **Memory**: 4-8 GB (default: 4GB)
   - **Storage**: 1-20 GB persistent disk (default: 10GB)
   - **Container Image**: Choose your development stack
   - **Services**: Select service configuration
   - **Repository**: Git repository to clone
   - **Location**: Deployment region

3. **Launch Workspace**
   ```bash
   coder create my-hkjc-workspace --template hkjc-dev-template
   ```

## Service Details

### PostgreSQL Database

**Configuration:**
```yaml
Version: PostgreSQL 15
Host: localhost
Port: 5432
Username: postgres
Password: devpassword
Database: devdb
```

**Connection Examples:**
```bash
# CLI Connection
psql -h localhost -U postgres -d devdb

# Environment Variable
DATABASE_URL=postgresql://postgres:devpassword@localhost:5432/devdb
```

### Redis Cache

**Configuration:**
```yaml
Version: Redis 7 Alpine
Host: localhost
Port: 6379
Authentication: None (development setup)
```

**Connection Examples:**
```bash
# CLI Connection
redis-cli -h localhost -p 6379

# Environment Variable
REDIS_URL=redis://localhost:6379
```

### Mock API Services

#### Custom Express API (Port 3001)

**Available Endpoints:**
```
GET  /                    # API information
GET  /api/health         # Health check
GET  /api/users          # List all users
GET  /api/users/:id      # Get user by ID
POST /api/users          # Create new user
GET  /api/products       # List all products
```

**Sample Data:**
```json
{
  "users": [
    { "id": 1, "name": "John Doe", "email": "john@hkjc.org.hk" },
    { "id": 2, "name": "Jane Smith", "email": "jane@hkjc.org.hk" }
  ],
  "products": [
    { "id": 1, "name": "Racing Analytics", "price": 999.99, "category": "Software" },
    { "id": 2, "name": "Betting Platform", "price": 1999.99, "category": "Platform" }
  ]
}
```

#### JSON Server (Port 3002)

**RESTful Endpoints:**
```
GET    /posts           # List posts
GET    /posts/:id       # Get post
POST   /posts           # Create post
PUT    /posts/:id       # Update post
DELETE /posts/:id       # Delete post
GET    /comments        # List comments
GET    /profile         # Get profile
```

## Development Workflow

### Environment Setup

1. **Access Your Workspace**
   ```bash
   coder ssh my-hkjc-workspace
   ```

2. **Verify Services**
   ```bash
   # Check all services
   check-services

   # Individual service checks
   curl http://localhost:3001/api/health
   curl http://localhost:3002/posts
   psql -h localhost -U postgres -c "SELECT version();"
   redis-cli ping
   ```

3. **Access Code Server**
   ```
   http://your-workspace-url:13337
   ```

### Database Operations

**Create Tables:**
```sql
-- Connect to database
psql -h localhost -U postgres -d devdb

-- Create sample table
CREATE TABLE hkjc_members (
    id SERIAL PRIMARY KEY,
    member_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    membership_type VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO hkjc_members (member_id, name, email, membership_type) VALUES
('HK001', 'Michael Chan', 'michael.chan@hkjc.org.hk', 'Premium'),
('HK002', 'Sarah Wong', 'sarah.wong@hkjc.org.hk', 'Standard');
```

**Connection in Application:**
```javascript
// Node.js example
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // or explicit configuration:
  host: 'localhost',
  port: 5432,
  database: 'devdb',
  user: 'postgres',
  password: 'devpassword'
});
```

### Cache Operations

**Redis Usage Examples:**
```javascript
// Node.js with redis client
const redis = require('redis');
const client = redis.createClient({
  url: process.env.REDIS_URL
});

await client.connect();

// Store HKJC session data
await client.setEx('session:hk001', 3600, JSON.stringify({
  userId: 'HK001',
  membershipType: 'Premium',
  lastLogin: new Date()
}));

// Retrieve session
const session = await client.get('session:hk001');
```

### API Integration Testing

**Mock API Usage:**
```javascript
// Test user management
const response = await fetch('http://localhost:3001/api/users');
const users = await response.json();

// Create new member
const newUser = await fetch('http://localhost:3001/api/users', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    name: 'David Lee',
    email: 'david.lee@hkjc.org.hk'
  })
});
```

## Troubleshooting

### Common Issues

#### Services Not Starting

**Check Service Status:**
```bash
# View container logs
kubectl logs $(hostname) -c postgresql -n coder-workspaces
kubectl logs $(hostname) -c redis -n coder-workspaces
kubectl logs $(hostname) -c mock-api -n coder-workspaces

# Check port bindings
netstat -tulpn | grep -E ':(5432|6379|3001|3002)'
```

**Manual Service Recovery:**
```bash
# Restart PostgreSQL (if needed)
sudo -u postgres pg_ctl restart -D /var/lib/postgresql/data

# Restart Redis (if needed)
redis-server --daemonize yes

# Manual Mock API startup
cd /tmp && node server.js &
```

#### Database Connection Issues

**Check PostgreSQL Status:**
```bash
# Test connection
pg_isready -h localhost -p 5432 -U postgres

# Check logs
tail -f /var/log/postgresql/postgresql*.log
```

**Reset Database:**
```sql
-- Drop and recreate database
DROP DATABASE IF EXISTS devdb;
CREATE DATABASE devdb OWNER postgres;
```

#### Performance Issues

**Monitor Resource Usage:**
```bash
# Check memory usage
free -h

# Check CPU usage
top -p $(pgrep -d',' postgres,redis-server,node)

# Check disk space
df -h
```

### Support Resources

- **Internal Documentation**: Confluence HKJC Dev Portal
- **Container Issues**: IT Infrastructure Team
- **Database Support**: Data Engineering Team
- **Platform Issues**: DevOps Team

## Security Considerations

### Development Environment Security

⚠️ **Important**: This template is designed for development environments only.

**Security Features:**
- Isolated pod networking
- No external service exposure
- Development-only credentials
- Ephemeral data storage (except home directory)

**Production Considerations:**
- Replace default passwords
- Enable TLS/SSL encryption
- Implement proper authentication
- Use production-grade persistence
- Configure backup strategies

### HKJC Compliance

**Data Handling:**
- No production data should be used in development environments
- Use anonymized or synthetic test data
- Follow HKJC data classification policies
- Ensure compliance with local data protection regulations

## Best Practices

### Resource Management

```yaml
# Recommended configurations by project type
Small Projects:
  CPU: 2 cores
  Memory: 4GB
  Storage: 10GB

Medium Projects:
  CPU: 3 cores
  Memory: 6GB
  Storage: 15GB

Large Projects:
  CPU: 4 cores
  Memory: 8GB
  Storage: 20GB
```

### Development Guidelines

1. **Version Control**
   - Commit frequently to avoid data loss
   - Use meaningful commit messages
   - Follow HKJC branching strategies

2. **Database Management**
   - Use migrations for schema changes
   - Keep development data minimal
   - Regular backups of important work

3. **Service Dependencies**
   - Document API contracts
   - Use environment variables for configuration
   - Implement proper error handling

## Advanced Configuration

### Custom Environment Variables

Add project-specific environment variables:

```hcl
# In your template customization
env {
  name  = "HKJC_ENV"
  value = "development"
}
env {
  name  = "API_BASE_URL"
  value = "http://localhost:3001"
}
```

### Additional Services

Extend the template with additional services:

```hcl
# Example: Add MongoDB sidecar
dynamic "container" {
  for_each = var.enable_mongodb ? [1] : []
  content {
    name  = "mongodb"
    image = "mongo:6"
    # ... configuration
  }
}
```

### Custom Initialization Scripts

Add project-specific setup:

```bash
# In startup_script
# Install additional tools
npm install -g @hkjc/internal-cli
pip install hkjc-utils

# Setup project structure
mkdir -p /home/coder/{src,docs,tests,scripts}
```

## Changelog

### Version 1.0.0 (Current)
- Initial release with PostgreSQL, Redis, and Mock APIs
- Multi-language container support
- Multi-region deployment capabilities
- Real-time monitoring integration
- Comprehensive documentation

### Planned Features
- MongoDB sidecar option
- ElasticSearch integration
- Message queue services (RabbitMQ/Kafka)
- Pre-configured CI/CD pipelines
- Enhanced security features