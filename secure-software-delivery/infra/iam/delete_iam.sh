source ../variables.sh

gcloud iam service-accounts delete $GCP_SA_NAME_01 \
  --display-name=$GCP_SA_NAME_01

gcloud iam service-accounts delete $GCP_SA_NAME_02 \
  --display-name=$GCP_SA_NAME_02