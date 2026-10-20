# Deployment Guide

This guide provides step-by-step instructions for deploying the MusicLib application in two environments: locally on Windows and on a fresh Linux Virtual Machine (e.g., Ubuntu).

---

## 1. Local Deployment on Windows

### Prerequisites

1. **Install Docker Desktop for Windows**
   - Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
   - Ensure WSL 2 (Windows Subsystem for Linux) backend is enabled in Docker Desktop settings (this is the default and recommended approach).
   - Start Docker Desktop and wait for the engine to be running (the whale icon in the system tray should stop animating).

2. **Install Git**
   - Download and install [Git for Windows](https://gitforwindows.org/).

### Deployment Steps

1. **Clone the Repository**
   Open PowerShell or Command Prompt and run:
   ```powershell
   git clone <your-repo-url>
   cd DBMS_CC_retry
   ```

2. **Configure Environment Variables**
   Copy the example environment file to create your local config:
   ```powershell
   copy .env.example .env
   ```
   Open `.env` in a text editor (like VS Code or Notepad) and customize the passwords and secrets if desired.

3. **Run Docker Compose**
   Build and start the containers in detached mode:
   ```powershell
   docker-compose up -d --build
   ```

4. **Verify the Deployment**
   - Open Docker Desktop and check the `dbms_cc_retry` application under the "Containers" tab. All three services (`musiclib_py_db`, `musiclib_py_backend`, `musiclib_py_frontend`) should be running.
   - Access the Frontend at [http://localhost:5273](http://localhost:5273).
   - Access the Backend API Healthcheck at [http://localhost:3101/health](http://localhost:3101/health).

### Troubleshooting on Windows

- **Port Conflicts (`bind: Only one usage of each socket address...`)**
  If you have a local installation of MySQL running natively on Windows, it will be using port `3306`. The `docker-compose.yml` is configured to map the container's `3306` to your machine's `3407` to prevent this. 
  If you see this error for another port, change `FRONTEND_PORT`, `BACKEND_PORT` or `DB_PORT` in `.env`.
  
- **Docker Daemon Not Running**
  Ensure Docker Desktop is open and running in the background before running `docker-compose` commands.

---

## 2. Deployment on a Fresh Linux VM (Ubuntu)

This assumes a fresh Ubuntu 22.04 or 24.04 server instance (e.g., AWS EC2, DigitalOcean Droplet, etc.).

### Prerequisites Installation

1. **Update system packages**
   ```bash
   sudo apt-get update
   sudo apt-get upgrade -y
   ```

2. **Install Docker Engine and Docker Compose**
   Follow the official Docker installation steps:
   ```bash
   # Add Docker's official GPG key
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl gnupg
   sudo install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   sudo chmod a+r /etc/apt/keyrings/docker.gpg

   # Add the repository to Apt sources
   echo \
     "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
     "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

   # Install Docker packages
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```

3. **Manage Docker as a non-root user (Optional but recommended)**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

4. **Install Git**
   ```bash
   sudo apt-get install -y git
   ```

### Deployment Steps

1. **Clone the Repository**
   ```bash
   git clone <your-repo-url>
   cd DBMS_CC_retry
   ```

2. **Configure Environment Variables**
   ```bash
   cp .env.example .env
   # Edit the .env file using nano or vim
   nano .env
   ```

3. **Start the Application**
   Run Docker Compose in detached mode:
   ```bash
   docker compose up -d --build
   ```
   *(Note: On newer Linux Docker installations, it is `docker compose` without the hyphen).*

4. **Firewall Configuration (UFW)**
   If you are using a firewall, you need to expose the frontend and backend ports:
   ```bash
   sudo ufw allow 5273/tcp
   sudo ufw allow 3101/tcp
   sudo ufw reload
   ```

5. **Verify the Deployment**
   - Check container status: `docker compose ps`
   - Access the application via your VM's public IP address: `http://<YOUR_VM_IP>:5273`
   - (Note: Vite binds to `0.0.0.0` in the Dockerfile so it will be accessible externally).

### Updating the Application

When you push new code to your repository, you can update the VM deployment with:
```bash
cd DBMS_CC_retry
git pull origin main
docker compose up -d --build
```

---

## 3. Azure VM notes

The app runs the same way on an Azure Linux VM (Ubuntu 22.04/24.04 or Debian 12): `bash setup-vm.sh --skip-clone`
from inside the cloned repo installs Docker, writes `.env` with generated secrets and runs `docker compose up -d --build`.

1. **Open the ports in the Azure Network Security Group.** UFW alone is not enough; Azure blocks inbound traffic
   by default. Allow TCP **5273** (the site). Port 3101 (direct API access) is optional, since the browser reaches the API
   through the frontend's `/api` proxy.
   ```bash
   az vm open-port --resource-group <RESOURCE_GROUP> --name <VM_NAME> --port 5273 --priority 1010
   ```
   (or add an inbound rule in the portal: VM -> Networking).
2. **Browse to** `http://<VM_PUBLIC_IP_OR_DNS_NAME>:5273` and log in with `alice` / `password123`.
3. **MySQL is not exposed.** `docker-compose.yml` publishes it on `127.0.0.1:3407` only (Docker-published ports bypass UFW),
   so connect with `docker compose exec db mysql -uroot -p music_library` or an SSH tunnel.
4. **Check it is healthy:**
   ```bash
   docker compose ps                      # musiclib_py_backend should show "healthy"
   curl http://localhost:3101/health      # {"status":"ok",...}
   docker compose logs backend            # look for "Schema ready" and "Demo data ready"
   ```

### Upgrading a VM that ran the old Node/Prisma version

Your existing `mysql_data` volume keeps working: the Python backend adopts the tables Prisma created
(`CREATE TABLE IF NOT EXISTS`) and the demo seed only inserts what is missing. Existing logins and JWTs stay valid
(same bcrypt hashes, same `JWT_SECRET`). The leftover `_prisma_migrations` table is harmless and can be dropped.
```bash
git pull
docker compose up -d --build
```
To start from a clean database instead: `docker compose down -v` (this deletes all data), then `docker compose up -d --build`.
