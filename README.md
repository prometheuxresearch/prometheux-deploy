# Prometheux Deploy
## Overview
This repository contains the necessary files to set up and run the Prometheux services using Docker Compose. The setup creates a network connecting the services and exposes their ports for external access.

## Prerequisites
- **Docker** and **Docker Compose** installed.
- **PROMETHEUX_PULL_IMAGE_TOKEN:** A token required to pull Docker images from the Prometheux repository

## Services
- **vadalog-parallel:**
The [core reasoning engine of Prometheux](https://www.prometheux.co.uk/docs/learn/getting-started)
.

- **jarvis:**
The Reasoning Explanations Builder and LLMs Manager.

- **constellation:**
Manages registered databases and data sources.

- **jupyterlab:**
A JupyterLab environment equipped with both Python and Vadalog kernels. It automatically integrates the [Python SDK library of the prometheux chain](https://www.prometheux.co.uk/docs/sdk).

    To enable the interaction of the prometheux chain within **jupyterlab** with the other composed services, you will have to set the following configuration properties:
    
    ```
    prometheux_chain.config.set("CONSTELLATION_BACKEND_URL", "http://constellation:8085")
    prometheux_chain.config.set("JARVIS_URL", "http://jarvis:8084")
    ```

## Setup Instructions

1. **Clone the Repository:**

    ```
    git clone git@github.com:prometheuxresearch/prometheux-deploy.git
    cd prometheux-deploy
    ```

2. **Configure the Image Pull Token:**

- Obtain from Prometheux the **PROMETHEUX_PULL_IMAGE_TOKEN** and replace the content of **prometheux-image-pull-token.txt** file with the provided token.

3. **Start the Services:**

- Run the following command to start all Prometheux services:

    ```
    ./docker-compose-up.sh
    ```

    This script reads the image pull token and starts the services in detached mode.

4. **Configuration Files:**

- You can modify the configuration files for vadalog-parallel, jarvis, and constellation. These are mounted from the host.

5. **Accessing Services:**

- The services are accessible on the following ports:
    - vadalog-parallel: 8080
    - constellation: 8085
    - jarvis: 8084
    - jupyterlab: 8888

6. Stopping the Services:

- To stop all services, run:

    ```
    ./docker-compose-down.sh
    ```

## Notes
- Ensure that the paths specified in the **docker-compose.yml** file match your directory structure.
- Modify the **.sh** scripts as needed to fit your environment.

