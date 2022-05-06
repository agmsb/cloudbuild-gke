# GKE VPC

gcloud compute networks create $CLUSTER_VPC_NAME \
    --project=$PROJECT_ID \
    --subnet-mode=custom

gcloud compute networks subnets create $CLUSTER_SUBNET_NAME \
    --project=$PROJECT_ID \
    --region=$REGION \
    --network=$CLUSTER_VPC_NAME \
    --range=10.4.0.0/22 \
    --secondary-range=pod-net=10.0.0.0/14,svc-net=10.4.4.0/22


# Private Pool VPC
gcloud compute networks create $PRIVATE_POOL_VPC_NAME \
    --project=$PROJECT_ID \
    --subnet-mode=custom

 gcloud compute addresses create $PRIVATE_POOL_IP_RANGE_NAME \
      --global \
      --addresses=$PRIVATE_POOL_IP_RANGE \
      --purpose=VPC_PEERING \
      --prefix-length=$PRIVATE_POOL_IP_RANGE_SIZE \
      --network=$PRIVATE_POOL_VPC_NAME

gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=$PRIVATE_POOL_IP_RANGE_NAME \
    --network=$PRIVATE_POOL_VPC_NAME \
    --project=$PROJECT_ID

gcloud compute networks peerings update servicenetworking-googleapis-com \
    --network=$PRIVATE_POOL_VPC_NAME \
    --export-custom-routes \
    --no-export-subnet-routes-with-public-ip