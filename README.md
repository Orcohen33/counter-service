# Counter Service - Cloud Native Microservice

A production-ready counter service that tracks POST requests and returns the count on GET requests, deployed on AWS EKS with GitOps practices.

## Architecture

This project implements a cloud-native microservice with the following components:

- **Python Flask Application**: Enhanced with health checks, metrics, and Redis persistence
- **AWS EKS Cluster**: Managed Kubernetes environment with auto-scaling
- **Redis Database**: Persistent storage for counter data
- **GitOps with ArgoCD**: Automated deployment and configuration management
- **CI/CD Pipeline**: GitHub Actions for automated testing and deployment

## Features

### Application Features
- **Persistent Counter**: Survives pod restarts and scaling events
- **Health Endpoints**: `/health` (liveness) and `/ready` (readiness)
- **Metrics Endpoint**: `/metrics` for monitoring integration
- **Auto-scaling**: Horizontal Pod Autoscaler (2-10 replicas)
- **High Availability**: Multi-replica deployment with load balancing

### Operational Features
- **Infrastructure as Code**: Complete Terraform deployment
- **GitOps Deployment**: ArgoCD-managed continuous deployment
- **Automated CI/CD**: GitHub Actions pipeline
- **Monitoring Ready**: Prometheus metrics and health checks
- **Security Hardened**: IRSA, non-root containers, encrypted storage

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.12.0
- kubectl
- Docker

### Deployment

1. **Deploy Infrastructure**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

2. **Deploy Applications via ArgoCD**
   ```bash
   kubectl apply -f argocd/projects/production.yaml
   ```

3. **Access the Service**
   ```bash
   # Get ingress endpoint
   kubectl get ingress -n prod
   
   # Test the service
   curl http://<ingress-endpoint>/
   curl -X POST http://<ingress-endpoint>/
   ```

## Project Structure

```
counter-service/
├── app/                          # Python application
│   ├── counter-service.py        # Main Flask application
│   ├── requirements.txt          # Python dependencies
│   └── Dockerfile               # Container build configuration
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                 # Main Terraform configuration
│   ├── variables.tf            # Variable definitions
│   ├── providers.tf            # Provider configurations
│   └── values/                 # Helm chart values
├── k8s/                        # Kubernetes manifests
│   ├── namespace.yaml          # Namespace definition
│   ├── deployment.yaml         # Application deployment
│   ├── service.yaml           # Service definition
│   ├── ingress.yaml           # Ingress configuration
│   ├── hpa.yaml              # Horizontal Pod Autoscaler
│   └── configmap.yaml        # Configuration data
├── argocd/                    # GitOps configuration
│   ├── projects/             # ArgoCD projects
│   └── apps/                # ArgoCD applications
└── .github/workflows/        # CI/CD pipeline
    └── ci.yaml              # GitHub Actions workflow
```

## Deployment Flow

1. **Code Push**: Developer pushes changes to main branch
2. **CI Pipeline**: GitHub Actions executes automated pipeline:
   - Code linting and testing
   - Docker image build and push
   - Kubernetes manifest updates
3. **GitOps Sync**: ArgoCD detects repository changes
4. **Deployment**: ArgoCD applies changes to Kubernetes cluster
5. **Health Validation**: Kubernetes validates application health
6. **Traffic Routing**: Ingress controller routes traffic to healthy pods

## API Endpoints

- `GET /`: Returns current counter value
- `POST /`: Increments counter and returns new value
- `GET /health`: Liveness probe endpoint
- `GET /ready`: Readiness probe endpoint
- `GET /metrics`: Prometheus metrics endpoint

## Monitoring & Operations

### Health Checks
```bash
# Check application health
curl http://<endpoint>/health

# Check readiness
curl http://<endpoint>/ready

# View metrics
curl http://<endpoint>/metrics
```

### Scaling
```bash
# Check current replicas
kubectl get hpa -n prod

# Manual scaling
kubectl scale deployment counter-service --replicas=5 -n prod
```

### Logs
```bash
# View application logs
kubectl logs -f deployment/counter-service -n prod

# View ArgoCD logs
kubectl logs -f deployment/argocd-server -n argocd
```

## Security Features

- **IRSA**: IAM Roles for Service Accounts for secure AWS access
- **Encrypted Storage**: GP3 encrypted volumes for persistent data
- **Network Policies**: Isolated pod networking
- **Non-root Containers**: Security-hardened container execution
- **Secret Management**: Kubernetes secrets for sensitive data

## Configuration

### Environment Variables
- `REDIS_HOST`: Redis server hostname (default: redis-master)
- `REDIS_PORT`: Redis server port (default: 6379)
- `REDIS_PASSWORD`: Redis authentication password
- `PORT`: Application port (default: 5000)

### Scaling Configuration
- **Min Replicas**: 2
- **Max Replicas**: 10
- **Target CPU**: 70%
- **Target Memory**: 80%

## Troubleshooting

### Common Issues

1. **Pod Not Starting**
   ```bash
   kubectl describe pod <pod-name> -n prod
   kubectl logs <pod-name> -n prod
   ```

2. **Redis Connection Issues**
   ```bash
   kubectl get pods -n prod | grep redis
   kubectl logs deployment/redis-master -n prod
   ```

3. **Ingress Not Working**
   ```bash
   kubectl get ingress -n prod
   kubectl describe ingress counter-service-ingress -n prod
   ```