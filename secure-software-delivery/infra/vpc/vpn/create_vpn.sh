source ../../variables.sh

# Create VPN gateways

gcloud compute vpn-gateways create $GW_NAME_01 \
   --network=$CLUSTER_VPC_NAME \
   --region=$REGION

gcloud compute vpn-gateways create $GW_NAME_02 \
   --network=$PRIVATE_POOL_VPC_NAME \
   --region=$REGION

# Create routers

gcloud compute routers create $ROUTER_NAME_01 \
   --region=$REGION \
   --network=$CLUSTER_VPC_NAME \
   --asn=65001

gcloud compute routers create $ROUTER_NAME_02 \
   --region=$REGION \
   --network=$PRIVATE_POOL_VPC_NAME \
   --asn=65002

# Generate shared secret
SHARED_SECRET=$(head -c 4096 /dev/urandom | sha256sum | cut -b1-32)

# Create VPN tunnels

gcloud compute vpn-tunnels create $TUNNEL_NAME_GW01_IF0 \
    --peer-gcp-gateway=$GW_NAME_02 \
    --region=$REGION \
    --ike-version=2 \
    --shared-secret=$SHARED_SECRET \
    --router=$ROUTER_NAME_01 \
    --vpn-gateway=$GW_NAME_01 \
    --interface=0

gcloud compute vpn-tunnels create $TUNNEL_NAME_GW01_IF1 \
    --peer-gcp-gateway=$GW_NAME_02 \
    --region=$REGION \
    --ike-version=2 \
    --shared-secret=$SHARED_SECRET \
    --router=$ROUTER_NAME_01 \
    --vpn-gateway=$GW_NAME_01 \
    --interface=1

gcloud compute vpn-tunnels create $TUNNEL_NAME_GW02_IF0 \
    --peer-gcp-gateway=$GW_NAME_01 \
    --region=$REGION \
    --ike-version=2 \
    --shared-secret=$SHARED_SECRET \
    --router=$ROUTER_NAME_02 \
    --vpn-gateway=$GW_NAME_02 \
    --interface=0

gcloud compute vpn-tunnels create $TUNNEL_NAME_GW02_IF1 \
    --peer-gcp-gateway=$GW_NAME_01 \
    --region=$REGION \
    --ike-version=2 \
    --shared-secret=$SHARED_SECRET \
    --router=$ROUTER_NAME_02 \
    --vpn-gateway=$GW_NAME_02 \
    --interface=1

# Create BGP sessions

ROUTER_01_INTERFACE_NAME_0=${ROUTER_NAME_01}_INTERFACE_0
ROUTER_01_INTERFACE_NAME_1=${ROUTER_NAME_01}_INTERFACE_1
ROUTER_02_INTERFACE_NAME_0=${ROUTER_NAME_02}_INTERFACE_0
ROUTER_01_INTERFACE_NAME_1=${ROUTER_NAME_02}_INTERFACE_1

PEER_NAME_GW01_IF0=${TUNNEL_NAME_GW01}_IF0_PEER
PEER_NAME_GW01_IF1=${TUNNEL_NAME_GW01}_IF1_PEER
PEER_NAME_GW02_IF0=${TUNNEL_NAME_GW02}_IF0_PEER
PEER_NAME_GW02_IF1=${TUNNEL_NAME_GW02}_IF1_PEER


gcloud compute routers add-interface $ROUTER_NAME_01 \
    --interface-name=$ROUTER_01_INTERFACE_NAME_0 \
    --ip-address=169.254.0.1 \
    --mask-length=30 \
    --vpn-tunnel=$TUNNEL_NAME_GW01_IF0 \
    --region=$REGION

gcloud compute routers add-bgp-peer $ROUTER_NAME_01 \
    --peer-name=$PEER_NAME_GW01_IF0 \
    --interface=$ROUTER_01_INTERFACE_NAME_0 \
    --peer-ip-address=169.254.0.2 \
    --peer-asn=65002 \
    --region=$REGION

gcloud compute routers add-interface $ROUTER_NAME_01 \
    --interface-name=$ROUTER_01_INTERFACE_NAME_1 \
    --ip-address=169.254.1.1 \
    --mask-length=30 \
    --vpn-tunnel=$TUNNEL_NAME_GW01_IF1 \
    --region=$REGION    

gcloud compute routers add-bgp-peer $ROUTER_NAME_01 \
    --peer-name=$PEER_NAME_GW01_IF1 \
    --interface=$ROUTER_01_INTERFACE_NAME_1 \
    --peer-ip-address=169.254.1.2 \
    --peer-asn=65002 \
    --region=$REGION

gcloud compute routers add-interface $ROUTER_NAME_02 \
    --interface-name=$ROUTER_02_INTERFACE_NAME_0 \
    --ip-address=169.254.0.2 \
    --mask-length=30 \
    --vpn-tunnel=$TUNNEL_NAME_GW02_IF0 \
    --region=$REGION

gcloud compute routers add-bgp-peer $ROUTER_NAME_02 \
    --peer-name=$PEER_NAME_GW02_IF0 \
    --interface=$ROUTER_02_INTERFACE_NAME_0 \
    --peer-ip-address=169.254.0.1 \
    --peer-asn=65001 \
    --region=$REGION

gcloud compute routers add-interface $ROUTER_NAME_02 \
    --interface-name=$ROUTER_02_INTERFACE_NAME_1 \
    --ip-address=169.254.1.2 \
    --mask-length=30 \
    --vpn-tunnel=$TUNNEL_NAME_GW02_IF1 \
    --region=$REGION

gcloud compute routers add-bgp-peer $ROUTER_NAME_02 \
    --peer-name=$PEER_NAME_GW02_IF1 \
    --interface=$ROUTER_02_INTERFACE_NAME_1 \
    --peer-ip-address=169.254.1.1 \
    --peer-asn=65001 \
    --region=$REGION

gcloud compute routers update-bgp-peer $ROUTER_NAME_01 \
    --peer-name=$PEER_NAME_GW01_IF0 \
    --region=$REGION \
    --advertisement-mode=CUSTOM \
    --set-advertisement-ranges=$PRIVATE_POOL_VPC_NAME/$PRIVATE_POOLS_IP_RANGE_NAME

gcloud compute routers update-bgp-peer $ROUTER_NAME_01 \
    --peer-name=$PEER_NAME_GW01_IF1 \
    --region=$REGION \
    --advertisement-mode=CUSTOM \
    --set-advertisement-ranges=$PRIVATE_POOL_VPC_NAME/$PRIVATE_POOLS_IP_RANGE_NAME

gcloud compute routers update-bgp-peer $ROUTER_NAME_02 \
    --peer-name=$PEER_NAME_GW02_IF0 \
    --region=$REGION \
    --advertisement-mode=CUSTOM \
    --set-advertisement-ranges=$CLUSTER_CONTROL_PLANE_CIDR

gcloud compute routers update-bgp-peer $ROUTER_NAME_02 \
    --peer-name=$PEER_NAME_GW02_IF1 \
    --region=$REGION \
    --advertisement-mode=CUSTOM \
    --set-advertisement-ranges=$CLUSTER_CONTROL_PLANE_CIDR