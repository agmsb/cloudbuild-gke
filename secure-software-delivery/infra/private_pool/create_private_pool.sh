source ../variables.sh

cat > private-pool.yaml <<EOF
privatePoolV1Config:
  networkConfig:
    peeredNetwork: projects/${PROJECT_NUM}/global/networks/${PRIVATE_POOL_VPC_NAME}
    machineType: e2-standard-32
    diskSizeGb: 100
EOF