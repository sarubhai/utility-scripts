
#!/bin/bash
# Name: mlflow_server.sh
# Owner: Saurav Mitra
# Description: Configure MLflow Server
# Amazon Linux 2 Kernel 5.10 AMI 2.0.20221210.1 x86_64 HVM gp2


# Install PostgreSQL (Optional)
sudo amazon-linux-extras enable postgresql14 > /dev/null
sudo yum -y install postgresql postgresql-server postgresql-contrib postgresql-devel > /dev/null
sudo pip3 install psycopg2-binary


# Configure Database
sudo postgresql-setup initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo -u postgres psql -c "CREATE DATABASE mlflow_db;"
sudo -u postgres psql -c "CREATE USER mlflow_user WITH PASSWORD 'mlflow_pass';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mlflow_db TO mlflow_user;"

sudo sed -i 's|host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            md5|g' /var/lib/pgsql/data/pg_hba.conf
sudo systemctl restart postgresql


# Install MLflow
cd /opt/mlflow
export MLFLOW_HOME=/opt/mlflow
sudo pip3 install mlflow
# sudo pip3 install scikit-learn
# sudo pip3 install boto3


# MLflow Setup
sudo mkdir /opt/mlflow
sudo mkdir /opt/mlflow/logs
chown -R ec2-user:ec2-user /opt/mlflow

sudo tee -a /etc/systemd/system/mlflow.service <<EOF
[Unit]
Description=MLflow Tracking Server daemon
After=network.target postgresql.service
Wants=postgresql.service
[Service]
StandardOutput=file:/opt/mlflow/logs/stdout.log
StandardError=file:/opt/mlflow/logs/stderr.log
User=ec2-user
Group=ec2-user
Type=simple
ExecStart=/usr/local/bin/mlflow server --host 0.0.0.0 --port 5000 --backend-store-uri postgresql+psycopg2://mlflow_user:mlflow_pass@localhost:5432/mlflow_db --default-artifact-root s3://mlflow-artifact-root-default
Restart=on-failure
RestartSec=5s
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF

sudo chmod 0664 /etc/systemd/system/mlflow.service
sudo systemctl enable mlflow.service
sudo systemctl start mlflow
