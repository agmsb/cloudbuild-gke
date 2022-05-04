source ../variables.sh

gcloud secrets create $SECRET_NAME \
    --replication-policy="automatic"

echo -n "this is my super secret data" | \
    gcloud secrets versions add $SECRET_NAME --data-file=-