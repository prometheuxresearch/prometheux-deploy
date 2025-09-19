# Prometheux Databricks Integration - User Setup Guide

## Overview
This guide helps you configure Prometheux with Databricks using either Personal Access Tokens (PAT) or OAuth authentication.

---

## 📋 Prerequisites

Before starting, ensure you have:
- ✅ A Databricks workspace (AWS, Azure, or GCP)
- ✅ Admin access to your Databricks account
- ✅ Terraform installed (for automated cluster creation)
- ✅ Databricks CLI installed (optional, for manual setup)

---

## 🎯 Configuration Options

Choose your preferred setup method:

### Option 1: Quick Setup with Personal Access Token (PAT) ⚡
- **Best for**: Development, testing, small teams
- **Setup time**: 5 minutes
- **Security**: Good for internal use

### Option 2: Enterprise Setup with OAuth ⭐ **Recommended for Production**
- **Best for**: Production, enterprise security
- **Setup time**: 15 minutes  
- **Security**: Enterprise-grade

### Option 3: Manual Cluster Creation 🔧
- **Best for**: Custom configurations, existing clusters
- **Setup time**: 10 minutes
- **Security**: Depends on chosen authentication method

---

## 🔍 Understanding Authentication Modes

### Key Concept: Two-Layer Authentication

**Layer 1: Terraform (Infrastructure)**
- Always uses Personal Access Token (PAT)
- Used to CREATE and MANAGE clusters
- This is how Terraform talks to Databricks APIs

**Layer 2: Application Access (Runtime)**
- Uses the mode you specify: PAT or OAuth
- This is how PROMETHEUX will connect to the cluster
- Configured via `authentication_mode` setting

### Authentication Mode Details

| Mode | Terraform Uses | Cluster Configured For | Applications Use |
|------|----------------|------------------------|------------------|
| **PAT** | PAT Token | PAT Access | Same PAT Token |
| **OAuth** | PAT Token | Service Principal | OAuth Client ID/Secret |

### Why This Design?

1. **Infrastructure Management**: Terraform needs stable, long-term credentials (PAT)
2. **Application Security**: OAuth provides enterprise-grade, auditable access
3. **Separation of Concerns**: Cluster creation vs. cluster usage can have different auth methods

### Example Scenarios

**Development/Testing (`authentication_mode = "pat"`):**
```
1. Terraform uses PAT → Creates cluster
2. Prometheux uses PAT → Connect to cluster
✅ Simple, same credentials for everything
```

**Production/Enterprise (`authentication_mode = "oauth"`):**
```
1. Terraform uses PAT → Creates OAuth-ready cluster 
2. Prometheux uses OAuth → Connect to cluster with service principal
✅ Secure, auditable, enterprise-compliant
```

---

## 🛠️ Configuration Methods: ENV Variables vs TFVARS

Before starting any setup option, understand how to provide configuration to Terraform:

### Method A: Environment Variables + setup.sh ⚡ **Easiest**
```bash
export DATABRICKS_HOST="https://your-workspace.cloud.databricks.com"
export DATABRICKS_TOKEN="dapi_your_token_here"
./setup.sh deploy  # Creates terraform.tfvars automatically
```

### Method B: terraform.tfvars File 📁 **Most Control**
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform apply
```

### Method C: Hybrid (What our examples show) 🔄
```bash
# Set ENV vars for setup.sh
export DATABRICKS_HOST="..." && export DATABRICKS_TOKEN="..."
# But also create terraform.tfvars for OAuth and advanced settings
cp terraform.tfvars.example terraform.tfvars
```

### Which Method to Choose?

| Use Case | Method | Why |
|----------|--------|-----|
| **Quick PAT setup** | ENV + setup.sh | Fastest, automated |
| **OAuth setup** | terraform.tfvars | More config options needed |
| **Production** | terraform.tfvars | Full control, version-controlled |
| **CI/CD** | ENV variables | Easy secret injection |

**Note**: If both exist, `terraform.tfvars` takes priority over environment variables.

---

## 🚀 Quick Setup - Option 1: PAT Authentication

### Step 1: Get Your Databricks Information

1. **Log into your Databricks workspace**
2. **Copy the workspace URL** from your browser:
   ```
   Example: https://dbc-xxxxxxxx-xxxx.cloud.databricks.com
   ```

3. **Create a Personal Access Token**:
   - Go to: **User Settings** → **Developer** → **Access Tokens**
   - Click: **Generate New Token**
   - Name: `prometheux-integration`
   - Lifetime: `90 days` (or as per your policy)
   - Click: **Generate**
   - **⚠️ Copy the token immediately** (you won't see it again!)
   ```
   Example: dapi_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

### Step 2: Run Automated Cluster Creation

**Using Method A (Environment Variables + setup.sh):**

```bash
# Navigate to the deploy directory
cd /path/to/prometheux-deploy/databricks/

# Set your information
export DATABRICKS_HOST="https://your-workspace.cloud.databricks.com"
export DATABRICKS_TOKEN="dapi_your_token_here"

# Run automated setup (uses PAT mode by default)
./setup.sh setup
./setup.sh deploy
```

**Alternative - Using Method B (terraform.tfvars):**

```bash
cd /path/to/prometheux-deploy/databricks/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set databricks_host, databricks_token, keep authentication_mode = "pat"
terraform init
terraform apply -auto-approve
```

**What happens behind the scenes:**
- Terraform uses your PAT token to create the cluster
- Cluster is configured for PAT authentication (`authentication_mode = "pat"` by default)
- Applications can connect using the same PAT token

### Step 3: Get Cluster Information

After successful deployment, note down:
- **Cluster ID**: (displayed in setup output)
- **Cluster Name**: `prometheux-spark-connect`

**✅ That's it! Provide these values to the Prometheux system:**
- Workspace URL
- Personal Access Token  
- Cluster ID

---

## 🏢 Enterprise Setup - Option 2: OAuth Authentication

### Step 1: Get Your Databricks Information

1. **Get Workspace URL** (same as Option 1)
2. **Get Account URL**:
   - AWS: `https://accounts.cloud.databricks.com`
   - Azure: `https://accounts.azuredatabricks.net`  
   - GCP: `https://accounts.gcp.databricks.com`

### Step 2: Create Service Principal

1. **Go to Databricks Account Console**
2. **Navigate**: User Management → Service Principals
3. **Click**: Add service principal
4. **Enter name**: `prometheux-oauth-integration`
5. **Click**: Add
6. **Click on the created service principal**
7. **Click**: Generate Secret
8. **⚠️ Copy both Client ID and Secret immediately!**

```
Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Client Secret: your_generated_secret_here
```

### Step 3: Configure OAuth-Ready Cluster

**OAuth requires Method B (terraform.tfvars) for advanced configuration:**

```bash
cd /path/to/prometheux-deploy/databricks/
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# Databricks Configuration  
databricks_host = "https://your-workspace.cloud.databricks.com"
databricks_token = "dapi_your_personal_token"  # Used only for cluster creation

# Authentication Configuration
# This tells Terraform HOW to configure the cluster for access
authentication_mode = "oauth"  # Options: "pat" or "oauth"

# For OAuth mode, specify the service principal that will access the cluster
service_principal_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Cluster Configuration
cluster_name = "prometheux-oauth-cluster"

# ... other settings ...
```

**How Authentication Modes Work:**
- **`authentication_mode = "pat"`**: Cluster allows PAT token access (default)
- **`authentication_mode = "oauth"`**: Cluster is configured for service principal access
- **Note**: Terraform itself always uses `databricks_token` (PAT) to CREATE the cluster, regardless of mode

### Step 4: Deploy OAuth-Ready Cluster

**Deploy using terraform.tfvars (recommended for OAuth):**

```bash
# Deploy cluster configured for service principal
terraform init
terraform plan
terraform apply -auto-approve
```

**Alternative - Set ENV vars if needed:**

```bash
# Only if you haven't set values in terraform.tfvars
export DATABRICKS_HOST="https://your-workspace.cloud.databricks.com"
export DATABRICKS_TOKEN="dapi_your_token_here"
terraform apply -auto-approve
```

**✅ Provide these values to the Prometheux system:**
- Workspace URL
- OAuth Client ID
- OAuth Client Secret
- Cluster ID

---

## 🔧 Manual Setup - Option 3: Custom Cluster

### Step 1: Create Cluster Manually

1. **Go to**: Databricks Workspace → Compute → Create Cluster
2. **Configure**:
   ```
   Cluster Name: prometheux-custom-cluster
   Access Mode: Shared (for OAuth) or Single User (for PAT or OAuth with OAuth Principal ID)
   Runtime Version: 17.1.x-scala2.13 (Spark 4.0+)
   Node Type: i3.xlarge or similar
   Min Workers: 1
   Max Workers: 3
   ```

3. **Advanced Options** → **Spark Config**:
   ```
   spark.connect.grpc.binding.port 15002
   spark.databricks.unity.catalog.enabled true
   spark.databricks.delta.optimizeWrite.enabled true
   ```

4. **If using OAuth**: Set **Single User Access** to your service principal ID

5. **Click**: Create Cluster

### Step 2: Note Cluster Information

- **Cluster ID**: Found in cluster URL or cluster details
- **Cluster Name**: As you named it

---

## 📝 Information Collection Summary

Regardless of which option you chose, collect this information:

### Required for All Setups:
```
Workspace URL: https://dbc-xxxxxxxx-xxxx.cloud.databricks.com
Cluster ID: xxxx-xxxxxx-xxxxxxxx
Cluster Name: prometheux-spark-connect
```

### For PAT Authentication:
```
Personal Access Token: dapi_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### For OAuth Authentication:
```
OAuth Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
OAuth Client Secret: your_generated_secret_here
```

---

## 🔧 Terminal Commands Reference

### Install Prerequisites

```bash
# Install Terraform (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Install Databricks CLI
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
```

### Quick Terraform Commands

```bash
# Initialize Terraform
terraform init

# Check what will be created
terraform plan

# Create resources
terraform apply -auto-approve

# Destroy resources (when done)
terraform destroy -auto-approve

# Check cluster status
databricks clusters list
```

### Environment Variables Setup

```bash
# For PAT Authentication
export DATABRICKS_HOST="https://your-workspace.cloud.databricks.com"
export DATABRICKS_TOKEN="dapi_your_token_here"

# For OAuth Testing (additional)
export DATABRICKS_OAUTH_CLIENT_ID="your_client_id"
export DATABRICKS_OAUTH_CLIENT_SECRET="your_client_secret"
```

---

## ❓ Troubleshooting

### Common Issues:

1. **"Authentication failed"**
   - Verify your token/credentials are correct
   - Check if token has expired

2. **"Cluster not found"**
   - Verify cluster ID is correct
   - Ensure cluster is running

3. **"Permission denied"**
   - For OAuth: Ensure service principal has cluster access
   - For PAT: Ensure token has sufficient permissions

4. **Terraform errors**
   - Run `terraform init` first
   - Check your `terraform.tfvars` file syntax

### Get Help:

```bash
# Check cluster status
databricks clusters get CLUSTER_ID

# Test connection
databricks clusters list

# View Terraform plan
terraform plan
```

---

## 🎯 Next Steps

Once you have collected all the required information:

1. **Provide the information to the Prometheux system**
2. **The system will automatically configure the integration**
3. **Start processing your data with enterprise-grade security!**

---

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify all prerequisites are installed
3. Ensure all information is collected correctly
4. Contact support with your specific error messages 