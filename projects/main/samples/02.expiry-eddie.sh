kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: expiry-eddie-nginx
  namespace: sandbox
spec:
  type: NodePort
  ports:
    - port: 80
  selector:
    app: expiry-eddie-nginx
---
apiVersion:  apps/v1
kind: Deployment 
metadata:
  labels:
    app: expiry-eddie-nginx
  name: expiry-eddie-nginx
  namespace: sandbox
spec:
  replicas: 2
  selector:
    matchLabels:
      app: expiry-eddie-nginx
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: expiry-eddie-nginx
    spec:
      containers:
      - image: nginx:latest
        name: expiry-eddie-nginx
        volumeMounts:
          - mountPath: "/etc/expiry-eddie-nginx/ssl"
            name: expiry-eddie-nginx-ssl
            readOnly: true
        ports:
        - containerPort: 80
      volumes:
        - name: expiry-eddie-nginx-ssl
          secret:
            secretName: expiry-eddie.svc.cluster.local
      restartPolicy: Always
EOF