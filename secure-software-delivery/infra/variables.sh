# Global variables
PROJECT_ID=$(gcloud config get project)
PROJECT_NUM=$(gcloud projects describe $PROJECT_ID --format=flattened | awk 'FNR == 7 {print $2}')
REGION=us-central1

# Cluster variables
CLUSTER_NAME=cluster
CLUSTER_VERSION=$(gcloud beta container get-server-config --region us-central1 --format='value(validMasterVersions[0])')

# VPC variables
CLUSTER_VPC_NAME=network1
CLUSTER_SUBNET_NAME=ha-vpn-subnet-1
CLUSTER_CONTROL_PLANE_CIDR=172.16.2.32/28
PRIVATE_POOL_VPC_NAME=network2
PRIVATE_POOL_SUBNET_NAME=ha-vpn-subnet-3
PRIVATE_POOL_IP_RANGE_NAME=private-pool-ip-range
PRIVATE_POOL_IP_RANGE=10.195.64.0
PRIVATE_POOL_IP_RANGE_SIZE=20

# VPN variables
PRIVATE_POOL_ROUTER=ha-vpn-router2
PRIVATE_POOL_ROUTER_PEER_0=router2-peer1
PRIVATE_POOL_ROUTER_PEER_1=router2-peer2
CLUSTER_ROUTER=ha-vpn-router1
CLUSTER_ROUTER_PEER_0=router1-peer1
CLUSTER_ROUTER_PEER_1=router1-peer2

# Private pool variables
PRIVATE_POOL_NAME=private-pool

# IAM variables
GCP_SA_GCB_DEFAULT=$PROJECT_NUM@cloudbuild.gserviceaccount.com
GCP_SA_NAME_01=build-01-sa
GCP_SA_NAME_02=build-02-sa

# Kubernetes variables
NAMESPACE_01=team-a
NAMESPACE_02=team-b
KSA_NAME_01=team-a-sa
KSA_NAME_02=team-b-sa

# Artifact Registry variables
REPOSITORY_A=team-a-repository
REPOSITORY_B=team-b-repository

# Secrets Manager variables
SECRET_NAME=secret-01

# Binauthz variables
ATTESTOR_ID=built-by-cloud-build

# GitHub variables
GH_REPO_01=