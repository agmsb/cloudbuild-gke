# Creating your target infrastructure 

## Clone the example repo
```
$ git clone https://github.com/agmsb/cloudbuild-gke.git && cd cloudbuild-gke/08
```

## Enable the needed Google Cloud APIs
```
# Set to the project you will be working with. 
$ gcloud config set project <replace-with-your-project-id>

# Replace $GH_USERNAME with your GitHub username that you will be using in bin/variables.sh.

$ source bin/variables.sh
$ gcloud services enable container.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com artifactregistry.googleapis.com binaryauthorization.googleapis.com servicenetworking.googleapis.com containeranalysis.googleapis.com
```

## Create VPCs and VPN
```
$ cd infra/vpc
$ terraform init
$ terraform plan
$ terraform apply
# Type 'yes' to move forward with creating the resources. 

$ cd ../..
```

## Create GKE cluster
``` 
$ gcloud container clusters create $CLUSTER_NAME \
	--project=$PROJECT_ID \
	--cluster-version=$CLUSTER_VERSION \
	--enable-ip-alias \
	--network=$CLUSTER_VPC_NAME \
	--subnetwork=$CLUSTER_SUBNET_NAME \
	--cluster-secondary-range-name=pod \
	--services-secondary-range-name=svc \
	--region=$REGION \
	--num-nodes=2 \
	--enable-private-nodes \
	--enable-private-endpoint \
	--master-ipv4-cidr=$CLUSTER_CONTROL_PLANE_CIDR \
   	--workload-pool=$PROJECT_ID.svc.id.goog \
	--enable-binauthz
```

## Create VPC peering for GKE control plane
```
$ export GKE_PEERING_NAME=$(gcloud container clusters describe $CLUSTER_NAME \
    --region=$REGION \
    --format='value(privateClusterConfig.peeringName)')

$ gcloud compute networks peerings update $GKE_PEERING_NAME \
    --network=$CLUSTER_VPC_NAME \
    --export-custom-routes \
    --no-export-subnet-routes-with-public-ip
```

## Setup networking for Cloud Build private pool
```
$ gcloud compute addresses create $PRIVATE_POOL_IP_RANGE_NAME \
      --global \
      --addresses=$PRIVATE_POOL_IP_RANGE \
      --purpose=VPC_PEERING \
      --prefix-length=$PRIVATE_POOL_IP_RANGE_SIZE \
      --network=$PRIVATE_POOL_VPC_NAME


$ gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=$PRIVATE_POOL_IP_RANGE_NAME \
    --network=$PRIVATE_POOL_VPC_NAME \
    --project=$PROJECT_ID
 
$ gcloud compute networks peerings update servicenetworking-googleapis-com \
    --network=$PRIVATE_POOL_VPC_NAME \
    --export-custom-routes \
    --no-export-subnet-routes-with-public-ip
```

## Advertise ranges for private pool and GKE control plane

```
$ gcloud compute routers update-bgp-peer ${PRIVATE_POOL_ROUTER} \
    --peer-name=$PRIVATE_POOL_ROUTER_PEER_0 \
    --region=${REGION} \
    --advertisement-mode=CUSTOM \
    --set-advertisement-ranges=${PRIVATE_POOL_IP_RANGE}/${PRIVATE_POOL_IP_RANGE_SIZE}
 
$ gcloud compute routers update-bgp-peer ${PRIVATE_POOL_ROUTER} \
    --peer-name=$PRIVATE_POOL_ROUTER_PEER_1 \
    --region=${REGION} \
    --advertisement-mode=CUSTOM \
    --set-advertisement-ranges=${PRIVATE_POOL_IP_RANGE}/${PRIVATE_POOL_IP_RANGE_SIZE}
 
$ gcloud compute routers update-bgp-peer ${CLUSTER_ROUTER} \
    --peer-name=${CLUSTER_ROUTER_PEER_0} \
    --region=${REGION} \
    --advertisement-mode=CUSTOM \
    --set-advertisement-ranges=$CLUSTER_CONTROL_PLANE_CIDR
 
$ gcloud compute routers update-bgp-peer ${CLUSTER_ROUTER} \
    --peer-name=${CLUSTER_ROUTER_PEER_1} \
    --region=${REGION} \
    --advertisement-mode=CUSTOM \
    --set-advertisement-ranges=$CLUSTER_CONTROL_PLANE_CIDR
```

# Securing build and deployment infrastructure

## Create Cloud Build private pool
```
$ cat > infra/private-pool.yaml <<EOF
privatePoolV1Config:
  networkConfig:
        # egressOption: NO_PUBLIC_EGRESS
        peeredNetwork: projects/$PROJECT_ID/global/networks/$PRIVATE_POOL_VPC_NAME
  workerConfig:
        machineType: e2-standard-2
        diskSizeGb: 100
EOF

$ gcloud builds worker-pools create $PRIVATE_POOL_NAME --config-from-file infra/private-pool.yaml --region $REGION
 ```

## Create allowlist for private pool to access GKE control plane
```
$ gcloud container clusters update $CLUSTER_NAME \
	--enable-master-authorized-networks \
	--region=$REGION \
--master-authorized-networks=$PRIVATE_POOL_IP_RANGE/$PRIVATE_POOL_IP_RANGE_SIZE
```

# Applying the principle of least privilege to builds 

Create GCP Service Acounts and Artifact Registry repositories
```
$ gcloud iam service-accounts create $GCP_SA_NAME_01 \
  --display-name=$GCP_SA_NAME_01
 
$ gcloud artifacts repositories create $REPOSITORY_A \
    --repository-format=docker \
     --location=$REGION
 
$ gcloud artifacts repositories add-iam-policy-binding team-a-repository --location $REGION --member="serviceAccount:${GCP_SA_NAME_01}@${PROJECT_ID}.iam.gserviceaccount.com" --role=roles/artifactregistry.writer
 
$ gcloud iam service-accounts create $GCP_SA_NAME_02 \
  --display-name=$GCP_SA_NAME_02
 
$ gcloud artifacts repositories create $REPOSITORY_B \
    --repository-format=docker \
     --location=$REGION
 
$ gcloud artifacts repositories add-iam-policy-binding team-b-repository --location $REGION --member="serviceAccount:${GCP_SA_NAME_02}@${PROJECT_ID}.iam.gserviceaccount.com" --role=roles/artifactregistry.writer
```
## Create GKE custom IAM role
```
$ cat << EOF > infra/minimal-gke-role.yaml 
title: minimal-gke 
description: Gets credentials only, RBAC for authz. 
stage: GA 
includedPermissions: 
- container.apiServices.get 
- container.apiServices.list 
- container.clusters.get 
- container.clusters.getCredentials
EOF

$ gcloud iam roles create minimal_gke_role --project=$PROJECT_ID\
  --file=infra/minimal-gke-role.yaml
```

## Create GCP SA role bindings

```
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member="serviceAccount:${GCP_SA_NAME_01}@${PROJECT_ID}.iam.gserviceaccount.com" \
--role=projects/$PROJECT_ID/roles/minimal_gke_role 
 
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member="serviceAccount:${GCP_SA_NAME_01}@${PROJECT_ID}.iam.gserviceaccount.com" \
--role=roles/logging.logWriter
 
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member="serviceAccount:${GCP_SA_NAME_01}@${PROJECT_ID}.iam.gserviceaccount.com" \
--role=roles/storage.admin
 
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member="serviceAccount:${GCP_SA_NAME_02}@${PROJECT_ID}.iam.gserviceaccount.com" \
--role=projects/$PROJECT_ID/roles/minimal_gke_role
 
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member="serviceAccount:${GCP_SA_NAME_02}@${PROJECT_ID}.iam.gserviceaccount.com" \
--role=roles/logging.logWriter
 
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member="serviceAccount:${GCP_SA_NAME_02}@${PROJECT_ID}.iam.gserviceaccount.com" \
--role=roles/storage.admin
 
$ gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member="serviceAccount:${GCP_SA_GCB_DEFAULT}" \
--role=roles/container.admin
 ```

## Bootstrap GKE cluster
```
$ cat << EOF > infra/bootstrap-cluster.yaml
steps:
  - name: gcr.io/cloud-builders/gcloud
    id: Bootstrap GKE cluster
    entrypoint: bash
    args:
      - '-c'
      - |
        gcloud container clusters get-credentials cluster --region $REGION --project $PROJECT_ID
        kubectl create ns $NAMESPACE_01
        kubectl create ns $NAMESPACE_02
        kubectl create role team-a-admin --verb=get,list,watch,create,update,patch,delete --resource=deployments.apps,services --namespace=$NAMESPACE_01
        kubectl create role team-b-admin --verb=get,list,watch,create,update,patch,delete --resource=deployments.apps,services --namespace=$NAMESPACE_02
        kubectl create rolebinding team-a-gcp-sa-binding --role=team-a-admin --user=${GCP_SA_NAME_01}@${PROJECT_ID}.iam.gserviceaccount.com --namespace=$NAMESPACE_01
        kubectl create rolebinding team-b-gcp-sa-binding --role=team-b-admin --user=${GCP_SA_NAME_02}@${PROJECT_ID}.iam.gserviceaccount.com --namespace=$NAMESPACE_02
options:
  workerPool: 'projects/$PROJECT_NUM/locations/$REGION/workerPools/$PRIVATE_POOL_NAME'
EOF
 
$ gcloud builds submit . --config=infra/bootstrap-cluster.yaml
```

## Validate bootstrap
```
$ cat << EOF > bin/test-build-a.yaml
steps:
  - name: gcr.io/cloud-builders/gcloud
    id: Test GCP SA for Team A
    entrypoint: bash
    args:
      - '-c'
      - |
        gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID
        kubectl get deployments -n $NAMESPACE_01
        kubectl get deployments -n $NAMESPACE_02
serviceAccount: 'projects/$PROJECT_ID/serviceAccounts/${GCP_SA_NAME_01}@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  workerPool: 'projects/$PROJECT_NUM/locations/$REGION/workerPools/private-pool'
  logging: CLOUD_LOGGING_ONLY
EOF
 
$ gcloud builds submit . --config=bin/test-build-a.yaml
 
Visit your Cloud Build logs in your Cloud Build console. Output should be similar to:
 
>2022-07-01T15:02:23.226364190Z No resources found in team-a namespace.


>2022-07-01T15:02:23.625289198Z Error from server (Forbidden): deployments.apps is forbidden: User "build-01-sa@agmsb-lab.iam.gserviceaccount.com" cannot list resource "deployments" in API group "apps" in the namespace "team-b": requires one of ["container.deployments.list"] permission(s).
 
$ cat << EOF > bin/test-build-b.yaml
steps:
  - name: gcr.io/cloud-builders/gcloud
    id: Test GCP SA for Team B
    entrypoint: bash
    args:
      - '-c'
      - |
        gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID
        kubectl get deployments -n $NAMESPACE_02
        kubectl get deployments -n $NAMESPACE_01
serviceAccount: 'projects/$PROJECT_ID/serviceAccounts/${GCP_SA_NAME_02}@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  workerPool: 'projects/$PROJECT_NUM/locations/$REGION/workerPools/private-pool'
  logging: CLOUD_LOGGING_ONLY
EOF
 
$ gcloud builds submit . --config=bin/test-build-b.yaml
 
Visit your Cloud Build logs in your Cloud Build console. Output should be similar to:
 
>2022-07-01T15:02:23.226364190Z No resources found in team-b namespace.


>2022-07-01T15:02:23.625289198Z Error from server (Forbidden): deployments.apps is forbidden: User "build-02-sa@agmsb-lab.iam.gserviceaccount.com" cannot list resource "deployments" in API group "apps" in the namespace "team-a": requires one of ["container.deployments.list"] permission(s).
```

# Configuring release management 

## Set up `gh` CLI
```
$ gh auth login 

$ cd bin
$ gh repo create $GH_A --public
$ gh repo clone $GH_A && cd $GH_A
$ cp -r ../../repo_templates/team_a/. . 
$ git add .
$ git commit -m "Copy over example repo."
$ git push --set-upstream origin HEAD

$ cd ..
 
$ gh repo create $GH_B --public
$ gh repo clone $GH_B && cd $GH_B
$ cp  -r ../../repo_templates/team_b/. . 
$ git add .
$ git commit -m "Copy over example repo." 
$ git push --set-upstream origin HEAD

$ cd ../..
```

## Connect GH repositories
```
Follow the instructions here: https://cloud.google.com/build/docs/automating-builds/build-repos-from-github#installing_gcb_app
 
Ensure that you are selecting the "Only select repositories" option when installing the Cloud Build app. Repeat the following for the team-b repository. 
```

## Validate app
```
$ cat << EOF > bin/$GH_A/build-app-a.yaml
steps:
  - name: gcr.io/cloud-builders/docker
    id: Build container image
    args: ['build', '-t', '${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_A/team-a-app:v1',  '.']
images: [${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_A/team-a-app:v1]
serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/${GCP_SA_NAME_01}@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  requestedVerifyOption: VERIFIED
  workerPool: 'projects/$PROJECT_NUM/locations/$REGION/workerPools/$PRIVATE_POOL_NAME'
  logging: CLOUD_LOGGING_ONLY
images: [${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_A/team-a-app:v1]

$ gcloud builds submit . --config=build-app-a.yaml

$ cat << EOF > bin/build-app-b.yaml
steps:
  - name: gcr.io/cloud-builders/docker
    id: Build container image
    args: ['build', '-t', '${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_B/team-b-app:v1',  '.']
images: [${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_B/team-b-app:v1]
serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/${GCP_SA_NAME_02}@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  requestedVerifyOption: VERIFIED
  workerPool: 'projects/$PROJECT_NUM/locations/$REGION/workerPools/$PRIVATE_POOL_NAME'
  logging: CLOUD_LOGGING_ONLY
images: [${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_B/team-b-app:v1]

$ gcloud builds submit . --config=build-app-b.yaml
```

## Create Cloud Build triggers
```
$ gcloud beta builds triggers create github \
--name=team-a \
--region=$REGION \
--repo-name=$GH_A \
--repo-owner=$GH_USERNAME \
--branch-pattern=master --build-config=cloudbuild.yaml \
--service-account=projects/$PROJECT_ID/serviceAccounts/${GCP_SA_NAME_01}@${PROJECT_ID}.iam.gserviceaccount.com \
--require-approval 
 
$ gcloud beta builds triggers create github \
--name=team-b \
--region=$REGION \
--repo-name=$GH_B \
--repo-owner=$GH_USERNAME \
--branch-pattern=master --build-config=cloudbuild.yaml \
--service-account=projects/$PROJECT_ID/serviceAccounts/${GCP_SA_NAME_02}@${PROJECT_ID}.iam.gserviceaccount.com \
--require-approval
```

## Create Cloud Build build configs
```
$ cat << EOF > bin/$GH_A/cloudbuild.yaml
steps:
  - name: gcr.io/cloud-builders/docker
    id: Build container image
    args: ['build', '-t', '${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_A/team-a-app:v1',  '.']
  - name: gcr.io/cloud-builders/gke-deploy
    id: Prep k8s manifests
    args:
      - 'prepare'
      - '--filename=k8s.yaml'
      - '--image=${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_A/team-a-app:v1'
      - '--version=v1'
  - name: gcr.io/google.com/cloudsdktool/cloud-sdk
    id: Get kubeconfig and apply manifests
    entrypoint: sh
    args:
      - '-c'
      - |
        gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID
        kubectl apply -f output/expanded/aggregated-resources.yaml -n $NAMESPACE_01
serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/${GCP_SA_NAME_01}@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  requestedVerifyOption: VERIFIED
  workerPool: 'projects/$PROJECT_NUM/locations/$REGION/workerPools/$PRIVATE_POOL_NAME'
  logging: CLOUD_LOGGING_ONLY
images: [${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_A/team-a-app:v1]
EOF

$ cat << EOF > bin/$GH_B/cloudbuild.yaml
steps:
  - name: gcr.io/cloud-builders/docker
    id: Build container image
    args: ['build', '-t', '${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_B/team-b-app:v1',  '.']
  - name: gcr.io/cloud-builders/gke-deploy
    id: Prep k8s manifests
    args:
      - 'prepare'
      - '--filename=k8s.yaml'
      - '--image=${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_A/team-b-app:v1'
      - '--version=v1'
  - name: gcr.io/google.com/cloudsdktool/cloud-sdk
    id: Get kubeconfig and apply manifests
    entrypoint: sh
    args:
      - '-c'
      - |
        gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID
        kubectl apply -f output/expanded/aggregated-resources.yaml -n $NAMESPACE_02
serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/${GCP_SA_NAME_02}@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  requestedVerifyOption: VERIFIED
  workerPool: 'projects/$PROJECT_NUM/locations/$REGION/workerPools/$PRIVATE_POOL_NAME'
  logging: CLOUD_LOGGING_ONLY
images: [${REGION}-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_B/team-b-app:v1]
EOF
```

## Test build config
```
$ cd bin/$GH_A
 
$ gcloud builds submit . --config=cloudbuild.yaml
```

## Test triggers
```
$ cd bin/$GH_A
$ git add .
$ git commit -m "Add Cloud Build YAML."
$ git push --set-upstream origin HEAD
$ cd ../$GH_B

$ git add .
$ git commit -m "Add Cloud Build YAML."
$ git push --set-upstream origin HEAD
$ cd ../..
```

# Enabling verifiable trust in artifacts from builds

## Create GKE binary authorization policy
```
$ gcloud artifacts docker images describe \
$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSISTORY_A/team-a-app:latest \
--show-provenance

$ cat << EOF > infra/policy.yaml
globalPolicyEvaluationMode: ENABLE
defaultAdmissionRule:
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    requireAttestationsBy:
    - projects/${PROJECT_ID}/attestors/${ATTESTOR_ID}
EOF

$ gcloud container binauthz policy import infra/policy.yaml
```

## Test deploying an image out-of-band
```

$ gcloud auth configure-docker $REGION-docker.pkg.dev
$ docker pull us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
$ docker tag us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0 $REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_A/out-of-band-app:tag1 
$ docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_A/out-of-band-app:tag1

$ gcloud artifacts repositories add-iam-policy-binding $REPOSITORY_A \
--location $REGION --member=user:$(gcloud config list account --format "value(core.account)") --role=roles/artifactregistry.admin

$ cd bin
$ mkdir out-of-band && cd out-of-band

$ cat << EOF > k8s.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: out-of-band-app
spec:
  selector:
    matchLabels:
      app: out-of-band
  replicas: 1
  template:
    metadata:
      labels:
        app: out-of-band
    spec:
      containers:
      - name: app
        image: $REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_A/quickstart-image@sha256:88b205d7995332e10e836514fbfd59ecaf8976fc15060cd66e85cdcebe7fb356
        imagePullPolicy: Always
EOF

$ cat << EOF > cloudbuild.yaml
steps:
  - name: gcr.io/google.com/cloudsdktool/cloud-sdk
    id: Get kubeconfig and apply manifests
    entrypoint: sh
    args:
      - '-c'
      - |
        gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID
        kubectl delete -f k8s.yaml -n $NAMESPACE_01
        kubectl apply -f k8s.yaml -n $NAMESPACE_01
serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/${GCP_SA_NAME_01}@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  workerPool: 'projects/$PROJECT_NUM/locations/$REGION/workerPools/$PRIVATE_POOL_NAME'
  logging: CLOUD_LOGGING_ONLY
EOF
```