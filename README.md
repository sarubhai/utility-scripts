# utility-scripts
Some Utility Scripts for Automation


### 1. terraform_workspace_name.sh
#### Description: Apply or Destroy Terraform resources & Configure OpenVPN Client Profile on local machine for terraform cloud Workspace
### Usage:
- ./terraform_workspace_name.sh apply
- ./terraform_workspace_name.sh destroy


### 2. vault_kv_to_secrets_manager_migration.sh
#### Description: Migrate Vault KV Secrets Engines (V1/V2) to AWS Secrets Manager
### Usage:
- ./vault_kv_to_secrets_manager_migration.sh

#### TO-DO: Post the key/values pairs to AWS Secrets Manager


### 3. tf-resource-listing.sh
#### Description: List Terraform resources By Workspace foreach nested directories
### Usage:
- ./tf-resource-listing.sh apply


### 4. airflow_server.sh
#### Description: Install Standalone Airflow in EC2 Instance
### Usage:
- Add in User data section while Launching an EC2 Instance


### 5. mlflow_server.sh
#### Description: Install ML Tracking Server in EC2 Instance
### Usage:
- Create a S3 Bucket & an IAM Role
- Attach the IAM instance profile while Launching an EC2 Instance
- Add in User data section while Launching an EC2 Instance
