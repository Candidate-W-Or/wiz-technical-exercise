#!/bin/bash

# --- 1. Install MongoDB (Simulating "Outdated" Service) ---
apt-get update
apt-get install -y mongodb

# --- 2. Configure MongoDB to Listen on All Interfaces ---
# REQUIRED: This allows the K8s cluster (and the internet) to connect
sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf
systemctl restart mongodb

# --- 3. Create a Dummy Database & User ---
sleep 10
mongo wizdb --eval 'db.createUser({user:"admin",pwd:"WizExercise2024!",roles:[{role:"readWrite",db:"wizdb"}]})'
mongo wizdb --eval 'db.exerciseData.insert({status: "This data should not be public", secret: "wiz-secret-token-123"})'

# --- 4. Install Azure CLI (For Backups) ---
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# --- 5. Create the Backup Script ---
# We inject the Storage Account Name and Container Name from Terraform
cat <<EOF > /home/azureuser/backup_script.sh
#!/bin/bash
# Dump the database
mongodump --out /tmp/backup/

# Create a tarball
tar -czvf /tmp/wizdb_backup.tar.gz /tmp/backup/

# Upload to Azure Blob Storage
# Uses the VM's Managed Identity (no password needed)
az login --identity
az storage blob upload \\
    --account-name "${storage_account_name}" \\
    --container-name "${container_name}" \\
    --name wizdb_backup_\$(date +%F_%H-%M).tar.gz \\
    --file /tmp/wizdb_backup.tar.gz \\
    --auth-mode login

# Clean up
rm -rf /tmp/backup/ /tmp/wizdb_backup.tar.gz
EOF

chmod +x /home/azureuser/backup_script.sh

# --- 6. Schedule the Cron Job (Every 5 minutes) ---
echo "*/5 * * * * /home/azureuser/backup_script.sh >> /var/log/db_backup.log 2>&1" | crontab -
