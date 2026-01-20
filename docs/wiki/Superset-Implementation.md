_Apache Superset is an open source Business Intelligence tool that allows institutions capable of self hosting to implement the Educator Workforce Dashboards with no licensing costs. This page provides an overview of how to implement Educator Workforce for Superset._

### **1.0 Overview**

This document details the architecture and deployment steps for instantiating an Apache Superset instance on an Amazon EC2 (Linux) host using Docker. The primary architectural requirement is to associate this instance within the same AWS VPC as an existing Windows VM running an MSSQL server (hosting an Ed-Fi ODS).

Connectivity will be established exclusively over the private network, using the MSSQL server's **Private IP address**. This design ensures low latency and a secure posture, as database traffic does not traverse the public internet.

A key technical requirement is the use of the `mssql+pymssql://` SQLAlchemy connection string. This mandates customizing the standard Superset Docker deployment to include the `pymssql` Python library, which in turn relies on FreeTDS system libraries.

### **2.0 Prerequisites**

Before proceeding, ensure the following prerequisites are met and all information is available:

* **AWS Environment:**  
  * An existing AWS VPC with at least one public and one private subnet (or two private subnets if a bastion host is used for access).  
  * An existing EC2 Key Pair for SSH access.  
* **MSSQL Server (Windows VM):**  
  * The instance is running and accessible within the VPC.  
  * The **Private IP Address** of the Windows VM (e.g., `10.10.20.50`).  
  * The **Database Name** to be connected (e.g., `EdFi_Ods_2024`).  
  * An **SQL Server Authentication** user (username and password) with appropriate `read` permissions on the database. *Windows Authentication is not viable from the Linux-based Superset container.*  
* **MSSQL Configuration:**  
  * **TCP/IP Protocol:** Enabled in SQL Server Configuration Manager.  
  * **Listening Port:** Configured to listen on a static port (default: **TCP 1433**).  
  * **Windows Firewall:** An inbound rule must exist on the Windows VM allowing TCP traffic on port `1433` from the **Private IP** or **Subnet CIDR** of the new Superset EC2 instance.

### **3.0 Architecture & Network Security**

The core of this architecture relies on AWS Security Groups (SGs) to manage traffic flow within the VPC.

1. **`SG-MSSQL` (Attached to Windows VM):**  
   * This existing security group must be modified.  
   * **Inbound Rule:**  
     * **Type:** `MSSQL` (or Custom TCP)  
     * **Protocol:** `TCP`  
     * **Port Range:** `1433`  
     * **Source:** `sg-superset-id` (The ID of the `SG-SUPERSET` group created below). Using an SG-to-SG reference is more secure and dynamic than hard-coding IPs.  
2. **`SG-SUPERSET` (To be created and attached to Superset EC2):**  
   * **Inbound Rule (Management):**  
     * **Type:** `SSH`  
     * **Protocol:** `TCP`  
     * **Port Range:** `22`  
     * **Source:** Your corporate IP range or a bastion host's IP/SG.  
   * **Inbound Rule (Application):**  
     * **Type:** `Custom TCP`  
     * **Protocol:** `TCP`  
     * **Port Range:** `8088` (Default Superset web port)  
     * **Source:** Your corporate IP range (for UI access).  
   * **Outbound Rules:**  
     * Default `(0.0.0.0/0)` is acceptable, but for a stricter policy, allow outbound `TCP 1433` to the `SG-MSSQL` security group and `TCP 80/443` for pulling Docker images and packages.

---

### **4.0 Step 1: Provision Superset EC2 Host**

1. Navigate to the **EC2 Console** and launch a new instance.  
2. **AMI:** Select **Amazon Linux 2** (or a recent Ubuntu Server).  
3. **Instance Type:** `t3.medium` or `t3.large` is recommended. Superset (especially the `superset-worker`) is memory-intensive. A `t3.small` will likely be insufficient.  
4. **Network Settings:**  
   * **VPC:** Select the correct VPC (the one containing the MSSQL VM).  
   * **Subnet:** Select a subnet. A public subnet is simpler for setup as it allows direct SSH and package downloads.  
   * **Auto-assign Public IP:** `Enable`.  
5. **Security Group:** Attach the **`SG-SUPERSET`** security group created in the previous section.  
6. **Key Pair:** Select your pre-existing `.pem` key.  
7. Launch the instance.

---

### **5.0 Step 2: Install Docker & Superset Environment**

1. SSH into the newly created EC2 instance using its Public IP.  
   Bash

```shell

ssh -i /path/to/your-key.pem ec2-user@<public-ip-address>
```

2. Install Docker and Docker Compose.  
   Bash

```shell

# Update packages and install Docker
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start

# Add ec2-user to the docker group to avoid using sudo
sudo usermod -a -G docker ec2-user

# Install Docker Compose V2 (latest)
sudo yum install -y git
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

3. **Log out and log back in** to apply the new group permissions.  
   Bash

```shell

exit
ssh -i /path/to/your-key.pem ec2-user@<public-ip-address>
```

   

4. Verify installation:

```shell
b
docker --version
docker compose version
```

   

5. Clone the Apache Superset repository.

```shell

git clone https://github.com/apache/superset.git
cd superset
```

   

6. **Crucial: Add `pymssql` Dependency.** The official Superset Docker build process automatically installs Python packages listed in `docker/requirements-local.txt`. The base Superset images (based on Debian) already include the `freetds-dev` system dependency, so we only need to specify the Python package.  
   Bash

```shell

echo "pymssql" > ./docker/requirements-local.txt
```

7. **Launch Superset (Non-Development Mode).** We will use the `docker-compose-non-dev.yml` file, which is optimized for a more stable, production-like deployment.  
   Bash

```shell

# Pull the images defined in the compose file
docker compose -f docker-compose-non-dev.yml pull

# Build and start all services in detached mode
docker compose -f docker-compose-non-dev.yml up -d
```

8. **Initialize the Superset Instance.** These commands must be run *after* the containers are up.  
   Bash

```shell

# Create an admin user (follow the prompts)
docker compose -f docker-compose-non-dev.yml exec superset superset fab create-admin

# Run database migrations
docker compose -f docker-compose-non-dev.yml exec superset superset db upgrade

# Initialize Superset roles and permissions
docker compose -f docker-compose-non-dev.yml exec superset superset init
```

#### ** Configure Superset Inside Docker**
Inside your terminal run ```sudo docker exec -it {CONTAINER NAME} bash``` to enter the container.
After you are in the container, create or open ```superset_config.py``` 

```
SECRET_KEY = 'USER CREATED SECRET KEY'
SQLALCHEMY_DATABASE_URI = 'postgresql://{USER}:{PASSWORD}@{SUPERSET METADATABASE URI}'

# Enabling for certs
ENABLE_PROXY_FIX = True
ENABLE_CORS_HEADERS  = True
 
TALISMAN_ENABLED = False #Required False for custom JS
HTML_SANITIZATION = False
HTML_SANITIZATION_SCHEMA_EXTENSIONS = {
    "attributes": {
        "*": ["style", "className"],  # Allow style and className on all tags
    },
    "tagNames": ["style"],  # Allow the <style> tag
}

FEATURE_FLAGS = {
    "SSH_TUNNELING": True,
    "AUTH_ROLE_PUBLIC": True,
    "ENABLE_TEMPLATE_PROCESSING": True,
    "GENERIC_CHART_AXES": True,
    "ENABLE_JAVASCRIPT_CONTROLS": True,
    "PREVENT_UNSAFE_DB_CONNECTIONS": False,
    "HORIZONTAL_FILTER_BAR": True, 
    "EMBEDDED_SUPERSET": True,
}



MAPBOX_API_KEY = 'MAPBOX PRODUCT KEY'

EXTRA_CATEGORICAL_COLOR_SCHEMES = [
    {
        "id": 'edfi_colors_id',
        "description": 'Ed-Fi Alliance Color Palette',
        "label": 'Ed-Fi Colors',
        "colors":  ["#02215D","#1280E5","#3EC1A2","#2EBDD0","#1B00BD","#902687","#E23A77","#FF6726"]
}
]
```      


---

### **6.0 Step 3: Configure Database Connection in Superset**

1. Access the Superset UI in your browser: `http://<ec2-public-ip>:8088`  
2. Log in with the `admin` credentials you created in the previous step.  
3. Navigate to **Data** \-\> **Databases**.  
4. Click the **\+ Database** button in the top right.  
5. In the **"Connect a database"** window:  
   * **Database Name:** A user-friendly name (e.g., `Ed-Fi ODS Production`).  
   * **SQLAlchemy URI:** This is the most critical component. Use the following format, substituting your MSSQL server's **Private IP** and credentials.  
6. **Format:** `mssql+pymssql://<USERNAME>:<PASSWORD>@<WINDOWS_VM_PRIVATE_IP>:<PORT>/<DATABASE_NAME>`  
   **Example:** `mssql+pymssql://edfi_reader:StrongP@ssw0rd!@10.10.20.50:1433/EdFi_Ods_2024`  
7. Navigate to the **"Other"** tab.  
8. In the **"Engine Parameters"** JSON block, it is highly recommended to specify the TDS version to avoid connection issues with modern MSSQL servers.  
   JSON

```json

{
    "tds_version": "7.4"
}
```

9. Click the **"Test Connection"** button. You should receive an "OK" confirmation.  
10. Click **"Connect"** to save the database.

---

### **8.0 Verification & Troubleshooting**

If the **"Test Connection"** fails, follow this diagnostic procedure *from the Superset EC2 instance's terminal*:

1. **Check Docker Container Logs:**  
   * `docker compose -f docker-compose-non-dev.yml logs superset`  
   * Look for `pymssql` errors, "Login failed," or "timeout" messages.  
2. **Verify `pymssql` Installation:**  
   * `docker compose -f docker-compose-non-dev.yml exec superset pip list | grep pymssql`  
   * This should return the installed `pymssql` package and version.  
3. **Perform Network Connectivity Test (Telnet):**  
   * This is the definitive test for network/firewall issues.  
   * `sudo yum install -y telnet`  
   * `telnet <WINDOWS_VM_PRIVATE_IP> 1433`  
   * **Success:** You will see a `Connected to...` message or a blank, blinking cursor. This means the network path is open. The problem is likely with `pymssql`, auth, or TDS version.  
   * **Failure (`Connection timed out`):** This is a network-level block.  
     * Check **`SG-MSSQL`**: Ensure it allows TCP 1433 from `SG-SUPERSET`.  
     * Check **Windows VM Firewall**: This is the most common culprit. Ensure the *internal* Windows Defender Firewall has an inbound rule for TCP 1433\.  
   * **Failure (`Connection refused`):** The network path is open, but the MSSQL service is not running or not listening on port `1433`. Check SQL Server Configuration Manager on the Windows VM.




