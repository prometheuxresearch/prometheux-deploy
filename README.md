# Prometheux Deploy

## Overview

This repository contains the necessary files to deploy the Prometheux platform on-premise using Docker Compose. The setup is composed of two independent stacks:

- **Router** (`router/`) — an on-premise reverse proxy that routes each user to their dedicated tenant backend, with circuit-breaker and health-check support.
- **Tenant** (`tenant/`) — a full per-tenant stack including the reasoning engine, data manager, language service, vector database, and JupyterLab.

This deployment runs on **any Linux machine that can run Docker** — whether a physical server in your data centre or a VM on a public cloud. If you are using a cloud VM, see the [Provisioning a Cloud VM](#provisioning-a-cloud-vm-optional) section before proceeding.

```
┌─────────────────────────────────────────┐
│               Router                    │
│  (router-on-premise, host network)      │
│  Listens on host port 8000              │
│  Routes user_1 → localhost:8001         │
│  Routes user_2 → localhost:8002  ...    │
└────────────────┬────────────────────────┘
                 │
    ┌────────────▼────────────┐
    │       Tenant Stack      │
    │  jarvispy      :8001    │
    │  vadalog-parallel       │
    │  data-manager           │
    │  vadalingo              │
    │  pgvector               │
    │  jupyterlab    :8888    │
    └─────────────────────────┘
```

---

## Provisioning a Cloud VM (Optional)

> Skip this section if you are deploying on a **physical Linux server** — the setup process is identical once Docker is installed.

If you are running on a cloud provider, provision a Linux VM first. The minimum recommended size is **4 vCPUs, 16 GB RAM, 50 GB disk**.

> **Sizing your disk:** The 50 GB minimum only covers the OS and container images — it does **not** account for your data (`shared/disk`, `postgres-data`, Engine checkpoints/logs). Before provisioning, consider how much data you expect to store over time:
> - **If the machine will not be resized later**, size the boot/data disk generously upfront based on your expected data growth (e.g. 500 GB, 1 TB, or more).
> - **If you want to avoid guessing**, attach a **separate, extensible storage volume** for the stateful paths instead of relying on the VM's own disk (AWS EBS, Azure Managed Disk, or GCP Persistent Disk can all be resized later without recreating the VM). This is the safest option and also makes [migration](#migrating-to-a-different-machine) trivial.
> - **If the disk size is already fixed** and you later need to move to a bigger disk, you can `tar`/`gzip` the stateful folders and copy the archive to the new disk instead of attaching/detaching a volume:
>   ```bash
>   tar -czf tenant-data.tar.gz tenant/shared tenant/postgres-data tenant/vadalog-parallel/{localCheckpoints,tmp,log}
>   scp tenant-data.tar.gz user@<new-host>:/path/to/prometheux-deploy/
>   # on the new host
>   tar -xzf tenant-data.tar.gz
>   ```

<details>
<summary><strong>AWS — EC2</strong></summary>

1. Open the [EC2 console](https://console.aws.amazon.com/ec2/) and click **Launch instance**.
2. Choose an **Ubuntu 22.04 LTS** (or later) AMI.
3. Select instance type **`m5.xlarge`** (4 vCPU, 16 GB) or larger.
4. Under **Key pair**, create or select an existing key pair for SSH access.
5. Under **Network settings**, ensure port **22** (SSH) is open. Open ports **8000**, **8001**, **8888** (or your chosen ports) to your desired CIDR range.
6. Set root volume to at least **50 GB**.
7. Launch the instance and connect via SSH:
    ```bash
    ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
    ```

</details>

<details>
<summary><strong>Azure — Virtual Machine</strong></summary>

1. Open the [Azure Portal](https://portal.azure.com/) and search for **Virtual machines** → **Create**.
2. Choose **Ubuntu Server 22.04 LTS** as the image.
3. Select size **`Standard_D4s_v3`** (4 vCPU, 16 GB) or larger.
4. Under **Administrator account**, choose **SSH public key** and upload or generate a key.
5. Under **Inbound port rules**, allow **SSH (22)**. After creation, add inbound rules for ports **8000**, **8001**, **8888** (or your chosen ports) in the **Network Security Group**.
6. Set OS disk size to at least **50 GB**.
7. Connect via SSH:
    ```bash
    ssh -i your-key.pem azureuser@<VM_PUBLIC_IP>
    ```

</details>

<details>
<summary><strong>GCP — Compute Engine</strong></summary>

1. Open the [Compute Engine console](https://console.cloud.google.com/compute/) and click **Create instance**.
2. Choose **Ubuntu 22.04 LTS** as the boot disk image.
3. Select machine type **`e2-standard-4`** (4 vCPU, 16 GB) or larger.
4. Under **Boot disk**, set the size to at least **50 GB**.
5. Under **Firewall**, check **Allow HTTP traffic** or create a custom firewall rule to open ports **8000**, **8001**, **8888** (or your chosen ports).
6. Under **SSH Keys**, add your public key in the **Metadata** section.
7. Connect via SSH:
    ```bash
    ssh -i your-key username@<VM_EXTERNAL_IP>
    ```
    Or use the **SSH** button directly in the console.

</details>

Once connected to your VM, proceed with the Docker and Docker Compose installation below.

---

## Prerequisites

- **Docker** and **Docker Compose** installed (see installation steps below).
- The following credentials, all **provided by Prometheux**:

| Secret | Where it is used |
|---|---|
| `PROMETHEUX_PULL_IMAGE_TOKEN` | Password for authenticating against the Prometheux AWS ECR registry to pull Docker images. Used by the startup scripts in both `router/` and `tenant/`. |
| `SECRET_KEY` | JWT secret used by the Router to validate tokens issued by the Prometheux UI. Set in `router/.env`. |
| `CUSTOMER` | Customer-specific name that identifies the correct `vadalog-parallel` image tag (`prometheux-reasoner-premises-${CUSTOMER}:latest`). Set in `tenant/.env`. |

### Installing Docker

> The official Docker package is supported on **Ubuntu**, **Debian**, **Fedora**, **RHEL/CentOS**, and others. Select your distribution below.

<details>
<summary><strong>Ubuntu</strong></summary>

1. Update your package index and install required dependencies:
    ```bash
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    ```

2. Add Docker's official GPG key and repository:
    ```bash
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    ```

3. Install Docker Engine:
    ```bash
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    ```

</details>

<details>
<summary><strong>Debian</strong></summary>

1. Update your package index and install required dependencies:
    ```bash
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    ```

2. Add Docker's official GPG key and repository:
    ```bash
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    ```

3. Install Docker Engine:
    ```bash
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    ```

</details>

<details>
<summary><strong>Fedora</strong></summary>

1. Install the `dnf-plugins-core` package and add the Docker repository:
    ```bash
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    ```

2. Install Docker Engine:
    ```bash
    sudo dnf install -y docker-ce docker-ce-cli containerd.io
    ```

3. Start and enable the Docker service:
    ```bash
    sudo systemctl start docker
    sudo systemctl enable docker
    ```

</details>

<details>
<summary><strong>RHEL / CentOS / Rocky Linux / AlmaLinux</strong></summary>

1. Install the `yum-utils` package and add the Docker repository:
    ```bash
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    ```

2. Install Docker Engine:
    ```bash
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    ```

3. Start and enable the Docker service:
    ```bash
    sudo systemctl start docker
    sudo systemctl enable docker
    ```

</details>

After installing Docker on any distribution, add your user to the `docker` group to run Docker without `sudo`:

```bash
sudo usermod -aG docker $USER
```

> **Note:** Log out and back in for the group change to take effect.

Verify the installation:

```bash
docker --version
```

### Installing Docker Compose

1. Download the latest Docker Compose binary:
    ```bash
    sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    ```

2. Apply executable permissions:
    ```bash
    sudo chmod +x /usr/local/bin/docker-compose
    ```

3. Verify the installation:
    ```bash
    docker-compose --version
    ```

---

## Repository Structure

```
prometheux-deploy/
├── router/
│   ├── docker-compose.yaml          # Router service definition
│   ├── docker-compose-up.sh         # Start the router
│   ├── docker-compose-down.sh       # Stop the router
│   ├── config.yaml                  # User-to-backend routing configuration
│   ├── .env.example                 # Router environment variables template
│   └── prometheux-image-pull-token.txt  # ECR pull token (to be filled in)
│
└── tenant/                          # Template — copy and rename per user (e.g. alice/, bob/)
    ├── docker-compose.yml           # Full tenant stack definition
    ├── docker-compose-up.sh         # Start the tenant stack
    ├── docker-compose-down.sh       # Stop the tenant stack
    ├── .env.example                 # Tenant environment variables template
    ├── prometheux-image-pull-token.txt  # ECR pull token (to be filled in)
    └── vadalog-parallel/
        ├── pmtx.properties          # Engine configuration
        └── spark-defaults.conf      # Spark configuration
```

---

## Services

### Router

| Service | Port | Description |
|---|---|---|
| `router-on-premise` | `8000` | Reverse proxy that routes authenticated users to their tenant `jarvispy` instance. Runs in host network mode and listens on port 8000. |

### Tenant

| Service | Port | Description |
|---|---|---|
| `jarvispy` | `8001` (configurable) | Main Prometheux API backend for the tenant. |
| `vadalog-parallel` | internal | [Core reasoning engine of Prometheux](https://www.vldb.org/pvldb/vol17/p4614-benedetto.pdf). |
| `data-manager` | internal | Manages data sources and persistence. |
| `vadalingo` | internal | Natural language to Engine translation service. |
| `pgvector` | internal | PostgreSQL database with vector extension for semantic storage. |
| `jupyterlab` | `8888` | JupyterLab with Python and Engine kernels. Install the SDK via: `pip install --upgrade prometheux_chain` |

---

## Setup Instructions

### 1. Clone the Repository

```bash
git clone git@github.com:prometheuxresearch/prometheux-deploy.git
cd prometheux-deploy
```

Make the startup and shutdown scripts executable:

```bash
chmod +x router/docker-compose-up.sh router/docker-compose-down.sh
chmod +x tenant/docker-compose-up.sh tenant/docker-compose-down.sh
```

### 2. Configure the Image Pull Token

Both the `router/` and `tenant/` folders contain a `prometheux-image-pull-token.txt` file. Replace the placeholder content in **each** file with the `PROMETHEUX_PULL_IMAGE_TOKEN` provided by Prometheux:

```bash
echo "<your-token>" > router/prometheux-image-pull-token.txt
echo "<your-token>" > tenant/prometheux-image-pull-token.txt
```

This token is used by the startup scripts to authenticate against the Prometheux AWS ECR registry before pulling Docker images.

### 3. Configure the Router

Copy the example environment file and fill in the values:

```bash
cp router/.env.example router/.env
```

Edit `router/.env` and set `SECRET_KEY` to the JWT secret provided by Prometheux. This key is used by the router to validate tokens issued by the Prometheux UI.

Edit `router/config.yaml` to map each username to their tenant's `jarvispy` backend URL:

```yaml
users:
  alice: "http://localhost:8001"
  bob:   "http://localhost:8002"
```

### 4. Configure the Tenant Stack

> The `tenant/` folder is a **template**, not a running stack. You never start it directly — instead you **copy it once per tenant user** and associate that copy with a single user. Repeat this section for every user you want to onboard.

Copy the template folder and rename it after the tenant's username (e.g. `alice`):

```bash
cp -r tenant alice
```

Then copy the example environment file inside the new folder and fill in the values:

```bash
cp alice/.env.example alice/.env
```

Edit `alice/.env`:

| Variable | Description |
|---|---|
| `USERNAME` | The tenant's username. Used in all container names and the Docker network name. |
| `ORGANIZATION` | The tenant's organisation name, passed to the `jarvispy` service. |
| `CUSTOMER` | The customer name provided by Prometheux, used in the `vadalog-parallel` image tag (`prometheux-reasoner-premises-${CUSTOMER}:latest`). |
| `JARVISPY_PORT` | The host port on which `jarvispy` is exposed. Must match the entry for this user in `router/config.yaml`. |
| `JUPYTERLAB_PORT` | The host port on which JupyterLab is exposed (e.g. `8888`). Reachable at `http://localhost:${JUPYTERLAB_PORT}` from the VM. |
| `JUPYTERLAB_TOKEN` | The access token for JupyterLab. Choose any value — this is the token you will use to log in to JupyterLab. |

You can also tune the Prometheux Engine by editing:
- `alice/vadalog-parallel/pmtx.properties`
- `alice/vadalog-parallel/spark-defaults.conf`

> **To onboard additional users**, repeat this step for each one — copy `tenant` to a new folder (`cp -r tenant bob`), configure its `.env` with a **unique** `USERNAME`, `JARVISPY_PORT`, and `JUPYTERLAB_PORT`, and add the matching routing entry in `router/config.yaml` (see step 3).

### 5. Start the Router

```bash
cd router
./docker-compose-up.sh
```

This authenticates with ECR, pulls the latest `router-on-premise` image, and starts it in detached mode using host networking.

### 6. Start the Tenant Stack

Start the **per-user copy** you created in step 4 (not the `tenant/` template itself). Repeat for each user's folder:

```bash
cd alice
./docker-compose-up.sh
```

This authenticates with ECR, creates the required local directories (`shared/disk`, `vadalog-parallel/localCheckpoints`, `vadalog-parallel/tmp`, `vadalog-parallel/log`), pulls all images, and starts the full tenant stack in detached mode.

---

## Stopping the Services

To stop the **router**:
```bash
cd router
./docker-compose-down.sh
```

To stop a **tenant** stack, run the script from that user's folder:
```bash
cd alice
./docker-compose-down.sh
```

---

## Notes

- The `tenant/` folder is a **template**. For each new user, copy the folder and rename it to their username, then fill in their `.env` file with unique values for `USERNAME`, `JARVISPY_PORT`, `JUPYTERLAB_PORT`, etc.:
    ```bash
    cp -r tenant alice
    cp alice/.env.example alice/.env
    # edit alice/.env
    ```
  Then add the user's routing entry in `router/config.yaml`:
    ```yaml
    users:
      alice: "http://localhost:8001"
    ```
- The `shared/disk` volume is shared between `jarvispy`, `vadalog-parallel`, `data-manager`, `vadalingo`, and `jupyterlab`, enabling seamless file exchange across services within a tenant.
- All services are configured with `restart: unless-stopped`, so they will automatically restart after a system reboot.

## Migrating to a Different Machine

All persistent state is stored in plain host directories (not Docker volumes), which makes migration straightforward if that state lives on a **separate mounted disk** (e.g. an AWS EBS volume, Azure Managed Disk, or GCP Persistent Disk) rather than the VM's boot disk.

**Stateful paths to preserve:**

| Path | Contents |
|---|---|
| `tenant/shared/disk` | Files shared across `jarvispy`, `vadalog-parallel`, `data-manager`, `vadalingo`, `jupyterlab` |
| `tenant/postgres-data` | `pgvector` database |
| `tenant/vadalog-parallel/{localCheckpoints,tmp,log}` | Engine runtime state |
| `tenant/.env`, `router/.env` | Configuration values |
| `*/prometheux-image-pull-token.txt` | ECR credentials |

**Migration steps:**

1. Stop the services on the source machine:
    ```bash
    cd tenant && ./docker-compose-down.sh
    cd ../router && ./docker-compose-down.sh
    ```
2. Detach the mounted disk containing the stateful paths above from the source VM.
3. Attach and mount the disk at the same path on the new VM (install Docker/Docker Compose there first — see [Prerequisites](#prerequisites)).
4. Clone this repository again (the compose files themselves are not part of the mounted disk):
    ```bash
    git clone git@github.com:prometheuxresearch/prometheux-deploy.git
    cd prometheux-deploy
    ```
5. If `.env` and `prometheux-image-pull-token.txt` are **not** on the mounted disk, recreate them as described in [Setup Instructions](#setup-instructions).
6. Start the services again:
    ```bash
    cd router && ./docker-compose-up.sh
    cd ../tenant && ./docker-compose-up.sh
    ```

Since no image layers or database data need to be re-downloaded or re-imported, migration is typically just a matter of remounting the disk and restarting the containers.

