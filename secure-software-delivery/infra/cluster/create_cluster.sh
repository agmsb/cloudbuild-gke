gcloud container clusters create $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --cluster-version=$CLUSTER_VERSION \
    --enable-ip-alias \
    --network=$CLUSTER_VPC_NAME \
    --subnetwork=$CLUSTER_SUBNET_NAME \
    --cluster-secondary-range-name=pod-net \
    --services-secondary-range-name=svc-net \
    --region=$REGION \
    --num-nodes=3 \
    --enable-binauthz \
    --enable-intra-node-visibility \
    --enable-private-nodes \
    --enable-private-endpoint \
    --master-ipv4-cidr=$CLUSTER_CONTROL_PLANE_CIDR

export GKE_PEERING_NAME=$(gcloud container clusters describe $CLUSTER_NAME \
    --region=$REGION \
    --format='value(privateClusterConfig.peeringName)')

gcloud compute networks peerings update $GKE_PEERING_NAME \
    --network=$CLUSTER_VPC_NAME \
    --export-custom-routes \
    --no-export-subnet-routes-with-public-ip