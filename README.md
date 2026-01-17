# Wiz Technical Exercise: Cloud-Native Security Lab

## 🚀 Project Overview
This project demonstrates a vulnerable-by-design cloud architecture on Azure. It simulates a real-world "Shadow IT" scenario where legacy infrastructure (VMs) interacts with modern cloud-native apps (Kubernetes), creating a **Toxic Combination** of risks.

The goal is to demonstrate a full "Kill Chain"—from initial access to data exfiltration—and then implement a "Shift Left" defense strategy using Microsoft Defender for Cloud and GitHub Advanced Security.

---

## 🏗️ Architecture
* **Frontend Application:** [Tasky](https://github.com/jeffthorne/tasky) (Containerized To-Do App)
    * Deployed on **Azure Kubernetes Service (AKS)**.
    * Built via **Azure Container Registry (ACR)** tasks.
    * Exposed via an external Load Balancer.
* **Backend Database:** MongoDB
    * Hosted on a legacy **Ubuntu 18.04 Virtual Machine**.
    * Simulates "Pet" infrastructure with weak credentials.
* **Storage:** Azure Blob Storage
    * Used for database backups (simulating sensitive PII data).

---

## 💥 The Security "Kill Chain" (Vulnerabilities)
This environment was intentionally deployed with critical misconfigurations to demonstrate how attackers pivot through a network:

### 1. Application Risks (The Entry Point)
* **Over-Privileged Container:** The Tasky pod is configured with a ServiceAccount granting `cluster-admin` privileges, allowing potential cluster takeover.
* **Hardcoded Secrets:** A verification token (`wizexercise.txt`) is baked directly into the container image.

### 2. Infrastructure Risks (Lateral Movement)
* **Weak Credentials:** The VM uses a weak, guessable password (`WizExercise2024!`) for the `mongoadmin` user.
* **Exposed Database:** MongoDB is bound to `0.0.0.0`, listening on all interfaces.
* **Over-Permissive NSG:** Network Security Groups allow inbound traffic from `0.0.0.0/0` (Anywhere).

### 3. Data Exfiltration (The Impact)
* **Public Storage:** The Azure Blob Storage container `db-backups` has "Blob Public Access" enabled.
* **Automated Leak:** A cron job on the VM automatically uploads database backups to this public container every 2 minutes, making sensitive data accessible to anyone on the internet.

---

## 🛡️ "Shift Left" Defense Strategy
To mitigate these risks, a DevSecOps pipeline was implemented to detect vulnerabilities *before* deployment.

* **CI/CD Security:** A GitHub Actions workflow (`security-scan.yml`) runs on every push.
* **Tools Used:**
    * **Microsoft Security DevOps (MSDO):** Orchestrates scanners like Terrascan and Trivy.
    * **Infrastructure as Code (IaC) Scanning:** Detects the public storage and open NSG rules in Terraform.
    * **Container Scanning:** Flags the `allowPrivilegeEscalation` and root user risks in the Kubernetes deployment.
* **Cloud Security Posture Management (CSPM):**
    * Integrated with **Microsoft Defender for Cloud**.
    * All alerts are visible in the Azure "DevOps Security" dashboard for unified visibility.

---

## 🛠️ Deployment Instructions

### Prerequisites
* Azure Subscription
* Terraform installed
* Azure CLI (`az`) installed

### 1. Infrastructure Deployment
```bash
terraform init
terraform apply -auto-approve

# Build the image in Azure
az acr build --registry wizregistry29260 --image tasky:v1 .

# Deploy to Kubernetes
kubectl apply -f tasky-deploy.yaml
