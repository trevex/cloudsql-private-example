# CloudSQL (and Redis) with private IPs

## Prerequisites
```
terraform
gcloud
kubectl
jq
```

Create a project and pick a region and export them for the following code snippets, e.g.:
```bash
export PROJECT="nvoss-cloudsql-paris"
export REGION="europe-west9"
```

## Bucket for terraform state

```bash
gsutil mb -p ${PROJECT} -l ${REGION} -b on gs://${PROJECT}-tf-state
gsutil versioning set on gs://${PROJECT}-tf-state
# Make sure terraform is able to use your credentials (only required if not already the case)
gcloud auth application-default login --project ${PROJECT}
```

## Update terraform code

You'll have to update references to the Google Cloud project and region as well as newly created bucket in these files:
```bash
0-cluster/cluster.auto.tfvars
0-cluster/main.tf # backend config at top of file
1-services/services.auto.tfvars
1-services/main.tf # backend config at top of file
```

## Deploy the cluster and services

```bash
terraform -chdir=0-cluster init
terraform -chdir=0-cluster apply
terraform -chdir=1-services init
terraform -chdir=1-services apply
```

## Connect to the cluster

```bash
gcloud container clusters get-credentials mycluster --region ${REGION} --project ${PROJECT}
```

## Test connections 

```bash
kubectl run redis --rm -i --tty --image busybox:latest -- telnet $(terraform -chdir=1-services output -json | jq -r '.redis_private_ip.value') 6379
kubectl run postgres --rm -i --tty --image busybox:latest -- telnet $(terraform -chdir=1-services output -json | jq -r '.postgres_private_ip.value') 5432
```

