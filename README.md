# Petclinic EKS Portfolio

End-to-end runbook to bring the project up from scratch, verify CI/CD, and shut it down to save cost.

## 1) Prerequisites

Install these tools locally:

- `aws` CLI
- `terraform`
- `kubectl`
- `helm`
- `eksctl`
- `docker`

Optional but useful:

- `jq`
- `git`

## 2) Set AWS profile/account once

This repo expects AWS profile `myaccount` and region `us-east-1`.

```bash
export AWS_PROFILE=myaccount
export AWS_REGION=us-east-1
export ACCOUNT_ID=479407618698

aws sts get-caller-identity
aws configure list
```

Expected account: `479407618698`.

## 3) Provision infrastructure (Terraform)

From repo root:

```bash
cd terraform
terraform init -input=false
terraform plan
terraform apply -auto-approve
```

Capture outputs:

```bash
CLUSTER_NAME=$(terraform output -raw cluster_name)
echo "$CLUSTER_NAME"
```

Expected default cluster name from this repo: `demo-eks-cluster`.

## 4) Configure kubectl for EKS

```bash
cd ..
aws eks update-kubeconfig \
  --name demo-eks-cluster \
  --region us-east-1 \
  --profile myaccount

kubectl get nodes -o wide
```

## 5) Install AWS Load Balancer Controller (ALB Ingress Controller)

### 5.1 Associate OIDC provider

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster demo-eks-cluster \
  --region us-east-1 \
  --approve
```

### 5.2 Create IAM policy for controller

This repo already includes `iam_policy.json` at root.

```bash
POLICY_ARN=$(aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || true)

if [ -z "$POLICY_ARN" ] || [ "$POLICY_ARN" = "None" ]; then
  POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
fi

echo "$POLICY_ARN"
```

### 5.3 Create/refresh IAM service account (IRSA)

```bash
eksctl create iamserviceaccount \
  --cluster demo-eks-cluster \
  --region us-east-1 \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn "$POLICY_ARN" \
  --approve \
  --override-existing-serviceaccounts
```

### 5.4 Install/upgrade controller via Helm

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=tag:Name,Values=demo-eks-cluster-vpc \
  --query 'Vpcs[0].VpcId' \
  --output text)

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId="$VPC_ID"

kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
kubectl -n kube-system get deploy aws-load-balancer-controller
```

If controller stays `0/2`, check:

```bash
kubectl -n kube-system describe deploy aws-load-balancer-controller
kubectl -n kube-system get sa aws-load-balancer-controller -o yaml
kubectl -n kube-system get rs,pods -l app.kubernetes.io/name=aws-load-balancer-controller -o wide
```

## 6) Deploy Petclinic workloads and ingress

Create namespace:

```bash
kubectl create namespace petclinic --dry-run=client -o yaml | kubectl apply -f -
```

Apply manifests:

```bash
kubectl apply -f kubernetes/mysql/
kubectl apply -f kubernetes/discovery-server/
kubectl apply -f kubernetes/config-server/
kubectl apply -f kubernetes/customers-service/
kubectl apply -f kubernetes/vets-service/
kubectl apply -f kubernetes/visits-service/
kubectl apply -f kubernetes/admin-server/
kubectl apply -f kubernetes/api-gateway/
```

Verify:

```bash
kubectl get pods -n petclinic
kubectl get svc -n petclinic
kubectl get ingress -n petclinic -o wide
kubectl describe ingress frontend-proxyr -n petclinic
```

Expected ingress host in this repo: `petclinic.local` (`kubernetes/api-gateway/ingress.yaml`).

## 7) Local domain mapping for browser testing

Get ALB DNS:

```bash
ALB_HOST=$(kubectl get ingress frontend-proxyr -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "$ALB_HOST"
```

Get current ALB IPs:

```bash
nslookup "$ALB_HOST"
```

Map local hostnames in `/etc/hosts` using returned IPs:

```bash
sudo sh -c 'cat >> /etc/hosts <<EOF
<ALB_IP_1> petclinic.local
<ALB_IP_2> petclinic.local
<ALB_IP_3> petclinic.local
EOF'
```

Test:

```bash
curl -I http://petclinic.local
curl -I -H "Host: petclinic.local" "http://${ALB_HOST}"
```

## 8) Install Argo CD and expose with ingress

Install Argo CD:

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
```

Apply Argo CD config for ALB HTTP mode:

```bash
kubectl apply -f kubernetes/argocd/cmd-params-cm.yaml
kubectl -n argocd rollout restart deploy/argocd-server
kubectl -n argocd rollout status deploy/argocd-server
```

Create Argo CD ingress:

```bash
kubectl apply -f kubernetes/argocd/ingress.yaml
kubectl get ingress -n argocd -o wide
```

Map `argocd.local` in `/etc/hosts` using ALB IPs (same pattern as above), then test:

```bash
ARGO_ALB=$(kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -I -H "Host: argocd.local" "http://${ARGO_ALB}"
```

Get initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode; echo
```

Create the Argo CD app for vets-service:

```bash
kubectl apply -f kubernetes/argocd/vets-service-application.yaml
kubectl get applications -n argocd
```

## 9) GitHub Actions CI/CD trigger flow

Workflow file: `.github/workflows/ci.yaml`.

Current behavior:

- `pull_request` to `main`: runs build/test/docker checks.
- `push` to `main` or `githubcicheck`: runs checks and `updatek8s`.
- `updatek8s` runs only on `push` by condition:
  `github.event_name == 'push'`.

Required GitHub secrets:

- `DOCKER_USERNAME`
- `DOCKER_TOKEN`

Trigger steps:

```bash
git checkout -b feature/ci-test
# make change under app/** or kubernetes/vets-service/** or .github/workflows/ci.yaml
git add .
git commit -m "test: trigger vets-service-ci"
git push -u origin feature/ci-test
```

Open PR to `main`:

- PR run executes checks.
- Merge PR to `main` triggers push run.
- Push run updates `kubernetes/vets-service/deployment.yaml` image tag.

Verify latest image:

```bash
kubectl -n petclinic get deploy vets-service -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n petclinic get pods -l app.kubernetes.io/name=vets-service -o wide
```

## 10) Daily stop/start to save money

### Stop for the day (keep infra)

```bash
kubectl scale deploy --all --replicas=0 -n petclinic
kubectl delete ingress frontend-proxyr -n petclinic --ignore-not-found
kubectl delete ingress argocd-server -n argocd --ignore-not-found
```

### Hibernate fully (max savings)

```bash
cd terraform
terraform destroy -auto-approve
```

### Start again tomorrow

Run sections `3` through `9` in order.

## 11) Useful troubleshooting commands

```bash
kubectl get ingress -A -o wide
kubectl describe ingress frontend-proxyr -n petclinic
kubectl describe ingress argocd-server -n argocd
kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=200
kubectl get events -A --sort-by=.metadata.creationTimestamp | tail -n 50
```

## 12) Portfolio completion checklist

Use this checklist before marking the project complete:

- Terraform apply succeeds with no errors.
- `kubectl get nodes` shows Ready nodes in EKS.
- ALB controller is healthy (`2/2` available in `kube-system`).
- `frontend-proxyr` ingress has an ADDRESS and Petclinic is reachable via `petclinic.local`.
- Argo CD is reachable via `argocd.local`, and login works.
- Argo CD `vets-service` application is `Synced` and `Healthy`.
- GitHub Actions workflow runs on PR and push as expected.
- `updatek8s` updates `kubernetes/vets-service/deployment.yaml` with latest run ID image tag.
- Cluster deployment image and manifest image tag match.

Destroy verification checklist:

```bash
cd terraform
terraform destroy -auto-approve
terraform state list
```

Expected after destroy:

- `terraform state list` returns no resources.
- `aws eks describe-cluster --name demo-eks-cluster --region us-east-1 --profile myaccount` fails with `ResourceNotFoundException`.
