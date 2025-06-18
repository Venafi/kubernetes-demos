	openssl req -x509 \
        -nodes -days 91 \
        -newkey rsa:2048 \
        -keyout artifacts/samples/unmanaged-kid.svc.cluster.local.key \
        -out artifacts/samples/unmanaged-kid.svc.cluster.local.crt \
        -subj "/C=US/ST=Utah/L=Salt Lake City/O=MIM Lab/OU=App Team 1/CN=unmanaged-kid.svc.cluster.local"

  kubectl -n sandbox create secret tls \
        unmanaged-kid.svc.cluster.local \
        --key="artifacts/samples/unmanaged-kid.svc.cluster.local.key" \
        --cert="artifacts/samples/unmanaged-kid.svc.cluster.local.crt" 

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: unmanaged-kid-nginx
  namespace: sandbox
spec:
  type: NodePort
  ports:
    - port: 80
  selector:
    app: unmanaged-kid-nginx
---
apiVersion:  apps/v1
kind: Deployment 
metadata:
  labels:
    app: unmanaged-kid-nginx
  name: unmanaged-kid-nginx
  namespace: sandbox
spec:
  replicas: 2
  selector:
    matchLabels:
      app: unmanaged-kid-nginx
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: unmanaged-kid-nginx
    spec:
      containers:
      - image: nginx:latest
        name: unmanaged-kid-nginx
        volumeMounts:
          - mountPath: "/etc/unmanaged-kid-nginx/ssl"
            name: unmanaged-kid-nginx-ssl
            readOnly: true
        ports:
        - containerPort: 80
      volumes:
        - name: unmanaged-kid-nginx-ssl
          secret:
            secretName: unmanaged-kid.svc.cluster.local
      restartPolicy: Always
EOF