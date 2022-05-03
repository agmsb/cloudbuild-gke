# Global variables
PROJECT_ID=$(gcloud config get project)
PROJECT_NUM=$(gcloud projects describe agmsb-k8s --format=flattened | awk 'FNR == 7 {print $2}')
REGION=us-west1

# Cluster variables
CLUSTER_NAME=cluster
CLUSTER_VERSION=$(gcloud beta container get-server-config --region us-west1 --format='value(validMasterVersions[0])')

# VPC variables
CLUSTER_VPC_NAME=cluster-vpc
CLUSTER_SUBNET_NAME=cluster-vpc-subnet-01
CLUSTER_CONTROL_PLANE_CIDR=172.16.0.32/28
PRIVATE_POOL_VPC_NAME=private-pool-vpc
PRIVATE_POOLS_IP_RANGE_NAME=private-pool-ip-range

# VPN variables
ASN_01=65001
ASN_02=65002

# Private pool variables
PRIVATE_POOL_NAME=private-pool

# IAM variables
GCP_SA_NAME_01=build-01-sa
GCP_SA_NAME_02=build-02-sa

# Secrets Manager variables
SECRET_NAME=secret-01