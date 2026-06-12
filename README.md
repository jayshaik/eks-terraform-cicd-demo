# EKS Terraform CI/CD Demo

This repository demonstrates how to provision an Amazon EKS cluster with Terraform and deploy a sample Kubernetes-based application stack on top of it.

## Overview

The project is split into two main parts:

- eks-install/: Terraform code to create the AWS VPC, EKS cluster, and node groups.
- kubernetes/: Kubernetes manifests and deployment resources for the sample microservices application.

## What this repo does

1. Creates a VPC and EKS cluster in AWS.
2. Configures EKS managed node groups using Terraform.
3. Deploys the sample application manifests under the kubernetes folder.
4. Provides a simple demo setup for learning infrastructure automation and Kubernetes deployment.

## Prerequisites

Before you begin, make sure you have:

- An AWS account with permissions to create VPC, IAM, EKS, and EC2 resources
- Terraform installed on your machine
- AWS CLI installed and configured
- kubectl installed
- Optional: an Ubuntu EC2 instance (recommended for running the deployment from a clean environment)

## Recommended setup

For a Windows machine, use PuTTY or Windows Terminal to connect to an EC2 instance.
For macOS/Linux, use your terminal directly.

A good starting point is:

- EC2 instance type: t3.large
- AMI: Ubuntu
- Region: us-east-2 (default in the Terraform configuration)

## Quick start

1. Launch an Ubuntu EC2 instance and connect to it.
2. Install the required tools:
   - Terraform
   - AWS CLI
   - kubectl
3. Clone this repository on the EC2 instance.
4. Change into the Terraform folder:

   cd eks-terraform-cicd-demo/eks-install

5. Initialize Terraform:

   terraform init

6. Review the plan:

   terraform plan

7. Apply the infrastructure:

   terraform apply

   This will take around 15-25 minutes depending on your AWS environment.

8. Configure kubectl to access the cluster:

   aws eks update-kubeconfig --region us-east-2 --name my-eks-cluster

9. Deploy the Kubernetes resources:

   kubectl apply -f ../kubernetes/complete-deploy.yaml

   Or apply individual manifests from the kubernetes folder as needed.

## Important note about Terraform state

The Terraform configuration in eks-install uses an S3 backend with the following settings:

- Bucket: tf-eks-state-demo-bucket
- Key: terraform.tfstate
- Region: us-east-2
- DynamoDB table: tf-eks-state-demo-lock-table

Make sure these resources exist in your AWS account before running terraform init/apply, or update the backend configuration to match your environment.

## Repository structure

- eks-install/ - Terraform files for VPC, EKS, and node groups
- kubernetes/ - Application deployment manifests
- kubernetes/README.md - Additional Kubernetes notes

## Cleanup

When you are done testing, remove the infrastructure to avoid AWS charges:

cd eks-install
terraform destroy

## CI/CD setup

This repository already includes a GitHub Actions workflow for the product-catalog microservice:

- .github/workflows/ci-productcatalog.yaml

### GitHub Actions (CI)

The CI pipeline currently runs for the product-catalog service and performs the following:

1. Checks out the code
2. Sets up Go
3. Builds the service
4. Runs unit tests
5. Runs golangci-lint
6. Builds and pushes the Docker image to Docker Hub
7. Updates the image tag in kubernetes/productcatalog/deploy.yaml
8. Commits the updated manifest back to the main branch

### GitHub secrets

For the workflow to work, add the required repository secrets under:

Settings -> Secrets and variables -> Actions -> New repository secret

Add the following values if they are used by your workflow:

- DOCKER_USERNAME
- DOCKER_TOKEN

You can also keep the default GitHub token for the push step if your workflow uses it.

### Continuous deployment with Argo CD

For CD, use Argo CD to sync the Kubernetes manifests from Git to your EKS cluster.

1. Install Argo CD in your cluster using the official Argo CD installation guide.
2. Apply the Argo CD manifests:

   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

3. Wait for the Argo CD pods to become ready.
4. Access the Argo CD UI:
   - The UI is served by the argocd-server service/pod.
   - You can use port-forwarding for local access:

     kubectl port-forward svc/argocd-server -n argocd 8080:443

   Then open http://localhost:8080 in your browser.

5. Log in to the Argo CD UI:
   - Username: admin
   - Password: get the initial password from the argocd namespace secret and decode it.

   Example:

   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode

   If your setup uses the secret view in the Kubernetes dashboard, you can also copy the secret value and run the same decode command locally.

6. Once logged in, create an application in Argo CD and point it to the repository and the Kubernetes manifests you want to deploy.

### Recommended workflow

- Push code to the repository
- GitHub Actions runs the CI checks and updates the image tag
- Argo CD detects the updated manifest and deploys the new version to EKS

## Next steps

You can extend this repo by:

- Adding CI/CD pipelines for other microservices
- Integrating GitHub Actions or Jenkins for automated deployment
- Adding Helm charts for deployment management
- Connecting the cluster to monitoring and logging tools


