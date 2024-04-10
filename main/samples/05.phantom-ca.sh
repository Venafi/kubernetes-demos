kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: phantom-ca-issued-nginx
  namespace: sandbox
spec:
  type: NodePort
  ports:
    - port: 80
  selector:
    app: phantom-ca-issued-nginx
---
apiVersion:  apps/v1
kind: Deployment 
metadata:
  labels:
    app: phantom-ca-issued-nginx
  name: phantom-ca-issued-nginx
  namespace: sandbox
spec:
  replicas: 2
  selector:
    matchLabels:
      app: phantom-ca-issued-nginx
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: phantom-ca-issued-nginx
    spec:
      containers:
      - image: nginx:latest
        name: phantom-ca-issued-nginx
        volumeMounts:
          - mountPath: "/etc/phantom-ca-issued-nginx/ssl"
            name: phantom-ca-issued-nginx-ssl
            readOnly: true
        ports:
        - containerPort: 80
      volumes:
        - name: phantom-ca-issued-nginx-ssl
          secret:
            secretName: phantom-ca-issued.svc.cluster.local
      restartPolicy: Always
EOF