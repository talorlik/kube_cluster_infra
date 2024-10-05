## Install ArgoCD Cli
```bash
VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

## Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Local expose UI
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Get the pass word
1. Option one
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode
```
2. Option two
```bash
argocd admin initial-password -n argocd
```

### Login
```bash
argocd login <ARGOCD_SERVER>
```

### Update password
```bash
argocd account update-password
```

### Get current-context
```bash
kubectl config current-context -o name
```

### Set context in Argo
```bash
argocd cluster add <context-name>
```

### Create application via cli
```bash
kubectl config set-context --current --namespace=argocd

argocd app create polybot --repo https://github.com/talorlik/polybot_service.git --path app --dest-server https://kubernetes.default.svc --dest-namespace polybot

argocd app create yolo5 --repo https://github.com/talorlik/yolo5_service.git --path app --dest-server https://kubernetes.default.svc --dest-namespace yolo5
```

### Get projects
```bash
argocd app get polybot

argocd app get yolo5
```

### Sync projects
```bash
argocd app sync polybot

argocd app sync yolo5
```

## Not sure if I need the below

### Create a second service for gRPC traffic to ArgoCD
```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    alb.ingress.kubernetes.io/backend-protocol-version: HTTP2 #This tells AWS to send traffic from the ALB using HTTP2. Can use GRPC as well if you want to leverage GRPC specific features
  labels:
    app: argogrpc
  name: argogrpc
  namespace: argocd
spec:
  ports:
  - name: "443"
    port: 443
    protocol: TCP
    targetPort: 8080
  selector:
    app.kubernetes.io/name: argocd-server
  sessionAffinity: None
  type: NodePort
```

### Create an Ingress for gRPC traffic to ArgoCD
```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    annotations:
      alb.ingress.kubernetes.io/backend-protocol: HTTPS
      # Use this annotation (which must match a service name) to route traffic to HTTP2 backends.
      alb.ingress.kubernetes.io/conditions.argogrpc: |
        [{"field":"http-header","httpHeaderConfig":{"httpHeaderName": "Content-Type", "values":["application/grpc"]}}]
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    name: argocd
    namespace: argocd
  spec:
    rules:
    - host: argocd.argoproj.io
      http:
        paths:
        - path: /
          backend:
            service:
              name: argogrpc
              port:
                number: 443
          pathType: Prefix
        - path: /
          backend:
            service:
              name: argocd-server
              port:
                number: 443
          pathType: Prefix
    tls:
    - hosts:
      - argocd.argoproj.io
```