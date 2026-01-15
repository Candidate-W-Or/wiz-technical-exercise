# Wiz Technical Exercise: Cloud-Native Security Lab

## Project Overview
This project demonstrates a 3-tier cloud architecture on Azure, designed to highlight **Toxic Combinations** and lateral movement risks.

## The Architecture
- **Frontend:** AKS Cluster (Nginx)
- **Middleware:** Ubuntu 18.04 VM (Backend)
- **Storage:** Azure Blob Storage (Sensitive Backups)

## Security Analysis: The "Toxic Path"
1. **Public Exposure:** AKS LoadBalancer is internet-facing.
2. **Identity Risk:** VM has a **Managed Identity** with Storage access.
3. **Lateral Movement:** Insecure NSG allows AKS-to-VM traffic on 27017.
4. **Data Exfiltration:** Attacker pivots from Pod -> VM -> Storage.

## DevOps & Automation
- **IaC:** Terraform (`main.tf`)
- **CI/CD:** GitHub Actions (`.github/workflows/deploy.yml`)
