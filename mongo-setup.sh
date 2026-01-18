#!/bin/bash

# 1. Install MongoDB
apt-get update
apt-get install -y mongodb

# 2. Open MongoDB to the network
sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf
systemctl restart mongodb

# 3. Create DB User
sleep 15
# FIXED: Updated password to match your Terraform code (2026!)
mongo wizdb --eval 'db.createUser({user:"admin",pwd:"WizExercise2026!",roles:[{role:"readWrite",db:"wizdb"}]})'
mongo wizdb --eval 'db.exerciseData.insert({status: "This data should not be public", secret: "wiz-secret-token-123"})'

# 4. Setup Azure CLI & Backup Script
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# FIXED: Changed directory to /home/mongoadmin
cat <<EOF > /home/mongoadmin/backup_script.sh
#!/bin/bash
mongodump --out /tmp/backup/
tar -czvf /tmp/wizdb_backup.tar.gz /tmp/backup/
az login --identity
az storage blob upload \
    --account-name "${storage_account_name}" \
    --container-name "${container_name}" \
    --name wizdb_backup_\$(date +%F_%H-%M).tar.gz \
    --file /tmp/wizdb_backup.tar.gz \
    --auth-mode login
rm -rf /tmp/backup/ /tmp/wizdb_backup.tar.gz
EOF

# 5. Make it executable and schedule it
# FIXED: Changed permissions and path to mongoadmin
chmod +x /home/mongoadmin/backup_script.sh
chown mongoadmin:mongoadmin /home/mongoadmin/backup_script.sh

# FIXED: Changed cron to every 30 minutes (*/30)
echo "*/30 * * * * /home/mongoadmin/backup_script.sh >> /var/log/db_backup.log 2>&1" | crontab -
