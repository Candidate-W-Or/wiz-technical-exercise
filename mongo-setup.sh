#!/bin/bash

# 1. Install MongoDB
curl -fsSL https://pgp.mongodb.com/server-4.2.asc | sudo apt-key add -
echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" \
| sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod

# 2. Open MongoDB to the network
sudo bash -c 'cat > /etc/mongodb.conf <<EOF
# MongoDB Configuration - YAML Format

systemLog:
  destination: file
  path: /var/log/mongodb/mongodb.log
  logAppend: true

storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
  # Enable Disk Compression (Zlib)
  wiredTiger:
    collectionConfig:
      blockCompressor: zlib

net:
  port: 27017
  bindIp: 0.0.0.0
  # Enable Network Compression (Zlib)
  compression:
    compressors:
       - zlib
       - snappy

security:
  authorization: enabled
EOF'
systemctl restart mongodb

# 3. Create DB User
sleep 15
# FIXED: Updated password to match your Terraform code (2026!)
mongo wizdb --eval 'use admin; db.createUser({user: "admin",pwd: "WizExercise2026!",roles: [ { role: "root", db: "admin" } ]})'
mongo wizdb --eval 'db.exerciseData.insert({status: "This data should not be public", secret: "wiz-secret-token-123"})'

# 4. Setup Azure CLI & Backup Script
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# FIXED: Changed directory to /home/mongoadmin
cat <<EOF > /home/mongoadmin/backup_script.sh
#!/bin/bash
mongodump -u admin -p WizExercise2026! --out /tmp/backup/
tar -czvf /tmp/wizdb_backup.tar.gz /tmp/backup/
az login --identity
az storage blob upload \
    --account-name "wizbackups01" \
    --container-name "db-backups" \
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
