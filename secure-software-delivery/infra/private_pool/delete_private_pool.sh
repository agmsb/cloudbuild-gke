source ../variables.sh

gcloud builds worker-pools delete $PRIVATE_POOL_NAME --region $REGION