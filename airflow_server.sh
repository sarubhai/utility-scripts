
#!/bin/bash
# Name: airflow_server.sh
# Owner: Saurav Mitra
# Description: Configure Airflow Server
# Amazon Linux 2 Kernel 5.10 AMI 2.0.20221210.1 x86_64 HVM gp2


POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=airflow_db
POSTGRES_USER=airflow_user
POSTGRES_PASSWORD=airflow_pass


# Optional PostgreSQL in the same machine. You may use RDS/managed database #
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
# Install PostgreSQL (Optional)
sudo amazon-linux-extras enable postgresql14 > /dev/null
sudo yum -y install postgresql postgresql-server postgresql-contrib postgresql-devel > /dev/null
sudo pip3 install psycopg2-binary

# Configure Database
sudo postgresql-setup initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo -u postgres psql -c "CREATE DATABASE ${POSTGRES_DB};"
sudo -u postgres psql -c "CREATE USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};"

sudo sed -i 's|host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            md5|g' /var/lib/pgsql/data/pg_hba.conf
sudo systemctl restart postgresql

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #


# Airflow Setup
sudo mkdir /opt/airflow
sudo mkdir /opt/airflow/dags
sudo mkdir /opt/airflow/logs
sudo mkdir /opt/airflow/plugins

# Project Repository
sudo yum -y install git
# git clone https://github.com/username/demo_airflow.git


# Install Airflow
cd /opt/airflow
export AIRFLOW_HOME=/opt/airflow
AIRFLOW_VERSION=2.5.0
PYTHON_VERSION="$(python3 --version | cut -d " " -f 2 | cut -d "." -f 1-2)"
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
sudo pip3 install "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"
sudo pip3 install apache-airflow[amazon,databricks,dbt-cloud,postgres,sftp,snowflake,ssh]
sudo pip3 install -r requirements.txt

airflow config list 2> /dev/null
sed -i "s|sql_alchemy_conn = sqlite:////opt/airflow/airflow.db|sql_alchemy_conn = postgresql+psycopg2://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}|g" /opt/airflow/airflow.cfg
sed -i 's|executor = SequentialExecutor|executor = LocalExecutor|g' /opt/airflow/airflow.cfg
sed -i 's|load_examples = True|load_examples = False|g' /opt/airflow/airflow.cfg
sed -i 's|parallelism = 32|parallelism = 4|g' /opt/airflow/airflow.cfg

airflow db init
airflow users create --username admin --firstname Airflow --lastname Admin --role Admin --email admin@example.org --password password

chown -R ec2-user:ec2-user /opt/airflow

sudo tee -a /etc/environment <<EOF
AIRFLOW_HOME='/opt/airflow'
EOF


sudo tee -a /etc/systemd/system/airflow-webserver.service <<EOF
[Unit]
Description=Airflow webserver daemon
After=network.target postgresql.service
Wants=postgresql.service
[Service]
EnvironmentFile=/etc/environment
User=ec2-user
Group=ec2-user
Type=simple
ExecStart= /usr/local/bin/airflow webserver
Restart=on-failure
RestartSec=5s
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF


sudo tee -a /etc/systemd/system/airflow-scheduler.service <<EOF
[Unit]
Description=Airflow scheduler daemon
After=network.target postgresql.service
Wants=postgresql.service
[Service]
EnvironmentFile=/etc/environment
User=ec2-user
Group=ec2-user
Type=simple
ExecStart=/usr/local/bin/airflow scheduler
Restart=always
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF

sudo chmod 0664 /etc/systemd/system/airflow-webserver.service
sudo chmod 0664 /etc/systemd/system/airflow-scheduler.service
sudo systemctl enable airflow-webserver.service
sudo systemctl enable airflow-scheduler.service
sudo systemctl start airflow-webserver
sudo systemctl start airflow-scheduler
