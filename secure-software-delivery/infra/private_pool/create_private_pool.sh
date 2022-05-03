source ../variables.sh

cat > private-pool.yaml <<EOF
privatePoolV1Config:
  networkConfig:
    peeredNetwork: projects/${PROJECT_NUM}/global/networks/${PRIVATE_POOL_VPC_NAME}
    machineType: e2-standard-32
    diskSizeGb: 100
EOF

gcloud builds worker-pools create $PRIVATE_POOL_NAME --config-from-file private-pool.yaml --region $REGION