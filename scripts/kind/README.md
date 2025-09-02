# Create Kind Cluster

These scripts help you spin up a local [kind](https://kind.sigs.k8s.io/) cluster

---

## 1. Setup

Clone this repo, then copy and configure environment variables:

```bash
cd scripts/kind

cp env-vars-template.sh env-vars.sh
# edit env-vars.sh as needed
```

Key variables in `env-vars.sh`:

- `CLUSTER_NAME_PREFIX` – prefix for cluster names (timestamp appended automatically).
- `KIND_NODE_IMAGE` – override the node image (e.g. `kindest/node:v1.30.0`).
- `EXTRA_PORT_MAPPINGS` – comma-separated host:container/PROTO mappings (defaults `80:80/TCP,443:443/TCP`).
- `EXTRA_MOUNTS_DIR` – directory containing `*.pem` files to mount into `/etc/ssl/certs/`. Any optional CA's that needs to be made availalble in the cluster.

---

## 2. Create a cluster

```bash
./create-cluster.sh
```

- The cluster will be named like: `mis-demo-cluster-2010033108`.
- Any PEM files in `extra-mounts/` will be mounted inside the nodes at `/etc/ssl/certs/<filename>.pem`.
- Ports defined in `EXTRA_PORT_MAPPINGS` will be mapped from host → container.

👉 To preview the actual config sent to kind without creating:
```bash
SHOW_CONFIG=1 ./create-cluster.sh
```

---

## 3. Destroy the cluster

To tear down manually:

```bash
kind delete cluster --name <cluster-name>
```

Example:

```bash
kind delete cluster --name mis-demo-cluster-2010033108
```

*(You can list clusters with `kind get clusters`.)*

---

## 4. Remove clusters (helper script)

Instead of manually typing the cluster name, you can use:

```bash
./remove-cluster.sh
```

- By default it will delete all clusters with prefix value `CLUSTER_NAME_PREFIX`.
- You’ll be asked to confirm before deletion.

To remove **all** matching clusters without confirmation:

```bash
./remove-cluster.sh --no-prompt
```

---

## 6. Quick summary

Typical workflow for testing:

```bash
# 1. Create cluster
./create-cluster.sh

# Switch to kuberentes-demos/main/ directory and run ./cloud-demo.sh 

# 3. Destroy when done
./remove-cluster.sh
```
