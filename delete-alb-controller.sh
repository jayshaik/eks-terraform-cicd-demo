#!/bin/bash

set -e

if [ $# -ne 3 ]; then
  echo "Usage: $0 <cluster-name> <region> <account-id>"
  exit 1
fi

cluster_name=$1
region=$2
account_id=$3

echo "=== Uninstalling AWS Load Balancer Controller ==="
helm uninstall aws-load-balancer-controller -n kube-system || echo "Helm release not found"

echo "=== Detaching IAM policy from role ==="
aws iam detach-role-policy \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::$account_id:policy/AWSLoadBalancerControllerIAMPolicy || echo "Policy already detached"

echo "=== Deleting IAM role ==="
aws iam delete-role \
  --role-name AmazonEKSLoadBalancerControllerRole || echo "Role already deleted"

echo "=== Deleting IAM policy ==="
aws iam delete-policy \
  --policy-arn arn:aws:iam::$account_id:policy/AWSLoadBalancerControllerIAMPolicy || echo "Policy already deleted"

echo "=== Detecting ACTIVE OIDC provider for cluster ==="
active_oidc_id=$(aws eks describe-cluster --name $cluster_name --region $region --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
echo "Active OIDC ID: $active_oidc_id"

echo "=== Listing all OIDC providers ==="
all_oidc_arns=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[].Arn" --output text)

echo "=== Checking for OLD OIDC providers to delete ==="
for arn in $all_oidc_arns; do
    oidc_id=$(echo $arn | awk -F'/' '{print $NF}')
    
    if [ "$oidc_id" != "$active_oidc_id" ]; then
        echo "Deleting OLD OIDC provider: $arn"
        aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $arn || echo "Failed to delete $arn"
    else
        echo "Keeping ACTIVE OIDC provider: $arn"
    fi
done

echo "=== Cleanup complete ==="