#!/bin/bash

set -e

if [ $# -ne 4 ]; then
  echo "Usage: $0 <cluster-name> <region> <vpc-id> <account-id>"
  exit 1
fi

cluster_name=$1
region=$2
cluster_vpc_id=$3
account_id=$4

echo "=== Getting OIDC ID for cluster: $cluster_name ==="
oidc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
echo "OIDC ID: $oidc_id"

echo "=== Checking if OIDC provider already exists ==="
existing_oidc=$(aws iam list-open-id-connect-providers | grep $oidc_id || true)

if [ -z "$existing_oidc" ]; then
    echo "OIDC provider not found. Creating..."
    eksctl utils associate-iam-oidc-provider --cluster $cluster_name --approve
else
    echo "OIDC provider already exists."
fi

echo "=== Downloading IAM policy ==="
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.4.0/docs/install/iam_policy.json

echo "=== Creating IAM policy ==="
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json || echo "Policy already exists"

echo "=== Creating IAM service account and role ==="
eksctl create iamserviceaccount \
  --cluster=$cluster_name \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::$account_id:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --override-existing-serviceaccounts

echo "=== Adding Helm repo ==="
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo "=== Installing AWS Load Balancer Controller ==="
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$cluster_name \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$region \
  --set vpcId=$cluster_vpc_id

echo "=== Verifying deployment ==="
kubectl get deployment -n kube-system aws-load-balancer-controller

echo "=== ALB Controller setup complete ==="