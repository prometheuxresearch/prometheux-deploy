# Prometheux Deploy

## Overview

This repository contains the necessary files to deploy the Prometheux platform on-premise using Docker Compose. The setup is composed of two independent stacks:

- **Router** (`router/`) — an on-premise reverse proxy that routes each user to their dedicated tenant backend, with circuit-breaker and health-check support.
- **Tenant** (`tenant/`) — a full per-tenant stack including the reasoning engine, data manager, language service, vector database, and JupyterLab.

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

## Prerequisites

- **Docker** and **Docker Compose** installed (see installation steps below).
- The following credentials, all **provided by Prometheux**:

| Secret | Where it is used |
|---|---|
| `PROMETHEUX_PULL_IMAGE_TOKEN` | Password for authenticating against the Prometheux AWS ECR registry to pull Docker images. Used by the startup scripts in both `router/` and `tenant/`. |
| `SECRET_KEY` | JWT secret used by the Router to validate tokens issued by the Prometheux UI. Set in `router/.env`. |
| `CUSTOMER` | Customer-specific name that identifies the correct `vadalog-parallel` image tag (`prometheux-reasoner-premises-${CUSTOMER}:latest`). Set in `tenant/.env`. |

### Installing Docker

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

4. Add your user to the `docker` group to run Docker without `sudo`:
    ```bash
    sudo usermod -aG docker $USER
    ```
    > **Note:** Log out and back in for the group change to take effect.

5. Verify the installation:
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
        ├── pmtx.properties          # Vadalog engine configuration
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
| `vadalog-parallel` | internal | [Core reasoning engine](https://www.prometheux.ai/docs/learn/getting-started) of Prometheux. |
| `data-manager` | internal | Manages data sources and persistence. |
| `vadalingo` | internal | Natural language to Vadalog translation service. |
| `pgvector` | internal | PostgreSQL database with vector extension for semantic storage. |
| `jupyterlab` | `8888` | JupyterLab with Python and Vadalog kernels. Install the SDK via: `pip install --upgrade prometheux_chain` |

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

Copy the example environment file and fill in the values:

```bash
cp tenant/.env.example tenant/.env
```

Edit `tenant/.env`:

| Variable | Description |
|---|---|
| `USERNAME` | The tenant's username. Used in all container names and the Docker network name. |
| `ORGANIZATION` | The tenant's organisation name, passed to the `jarvispy` service. |
| `CUSTOMER` | The customer name provided by Prometheux, used in the `vadalog-parallel` image tag (`prometheux-reasoner-premises-${CUSTOMER}:latest`). |
| `JARVISPY_PORT` | The host port on which `jarvispy` is exposed. Must match the entry for this user in `router/config.yaml`. |
| `JUPYTERLAB_PORT` | The host port on which JupyterLab is exposed (e.g. `8888`). Reachable at `http://localhost:${JUPYTERLAB_PORT}` from the VM. |
| `JUPYTERLAB_TOKEN` | The access token for JupyterLab. Choose any value — this is the token you will use to log in to JupyterLab. |

You can also tune the Vadalog engine by editing:
- `tenant/vadalog-parallel/pmtx.properties`
- `tenant/vadalog-parallel/spark-defaults.conf`

### 5. Start the Router

```bash
cd router
./docker-compose-up.sh
```

This authenticates with ECR, pulls the latest `router-on-premise` image, and starts it in detached mode using host networking.

### 6. Start the Tenant Stack

```bash
cd tenant
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

To stop the **tenant** stack:
```bash
cd tenant
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

