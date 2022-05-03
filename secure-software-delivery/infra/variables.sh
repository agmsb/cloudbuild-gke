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

# Private pool variables
PRIVATE_POOL_NAME=private-pool