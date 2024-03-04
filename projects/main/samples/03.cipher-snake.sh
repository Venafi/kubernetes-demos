	openssl req -x509 \
        -nodes -days 91 \
        -newkey rsa:1024 \
        -keyout artifacts/samples/cipher-snake.svc.cluster.local.key \
        -out artifacts/samples/cipher-snake.svc.cluster.local.crt \
        -subj "/C=US/ST=Utah/L=Salt Lake City/O=MIM Lab/OU=App Team 2/CN=cipher-snake.svc.cluster.local"

    kubectl -n sandbox create secret tls \
        cipher-snake.svc.cluster.local \
        --key="artifacts/samples/cipher-snake.svc.cluster.local.key" \
        --cert="artifacts/samples/cipher-snake.svc.cluster.local.crt" 


kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: cipher-snake-nginx
  namespace: sandbox
spec:
  type: NodePort
  ports:
    - port: 80
  selector:
    app: cipher-snake-nginx
---
apiVersion:  apps/v1
kind: Deployment 
metadata:
  labels:
    app: cipher-snake-nginx
  name: cipher-snake-nginx
  namespace: sandbox
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cipher-snake-nginx
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: cipher-snake-nginx
    spec:
      containers:
      - image: nginx:latest
        name: cipher-snake-nginx
        volumeMounts:
          - mountPath: "/etc/cipher-snake-nginx/ssl"
            name: cipher-snake-nginx-ssl
            readOnly: true
        ports:
        - containerPort: 80
      volumes:
        - name: cipher-snake-nginx-ssl
          secret:
            secretName: cipher-snake.svc.cluster.local
      restartPolicy: Always
EOF