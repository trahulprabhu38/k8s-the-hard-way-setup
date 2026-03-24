# Kubernetes The Hard Way — Complete Setup Guide

This guide explains every component of the cluster you just built, how traffic flows, how to access it from your Mac, and how pods reach the internet.

---

## Table of Contents

1. [What Was Built](#1-what-was-built)
2. [Network Layout](#2-network-layout)
3. [Component Deep-Dive](#3-component-deep-dive)
   - [etcd](#etcd)
   - [kube-apiserver](#kube-apiserver)
   - [kube-controller-manager](#kube-controller-manager)
   - [kube-scheduler](#kube-scheduler)
   - [HAProxy (Load Balancer)](#haproxy-load-balancer)
   - [containerd (Container Runtime)](#containerd-container-runtime)
   - [kubelet](#kubelet)
   - [kube-proxy](#kube-proxy)
   - [Weave Net (CNI)](#weave-net-cni)
   - [CoreDNS](#coredns)
4. [How All Components Talk to Each Other](#4-how-all-components-talk-to-each-other)
5. [Accessing the Cluster from Your Mac](#5-accessing-the-cluster-from-your-mac)
6. [Running an Nginx Pod and Accessing It](#6-running-an-nginx-pod-and-accessing-it)
7. [How Internet Access Works for Pods](#7-how-internet-access-works-for-pods)
8. [IP Address Reference](#8-ip-address-reference)

---

## 1. What Was Built

The setup script created **5 VMs** inside VirtualBox on your Mac:

```
Your Mac (host)
│
├── controlplane01  (192.168.56.11)  ← runs: etcd, kube-apiserver, kube-controller-manager, kube-scheduler
├── controlplane02  (192.168.56.12)  ← runs: etcd, kube-apiserver, kube-controller-manager, kube-scheduler
├── loadbalancer    (192.168.56.30)  ← runs: HAProxy (forwards :6443 to both control planes)
├── node01          (192.168.56.21)  ← runs: containerd, kubelet, kube-proxy, Weave Net
└── node02          (192.168.56.22)  ← runs: containerd, kubelet, kube-proxy, Weave Net
```

This is a **production-like, high-availability** setup with two control plane nodes and two worker nodes. Nothing uses `kubeadm` — every binary is configured by hand, which is why it is called "the hard way".

---

## 2. Network Layout

There are **three distinct network layers** in this setup. Understanding them is key.

### Layer 1 — VirtualBox Host-Only Network (`192.168.56.0/24`)

This is the network that connects all VMs to each other **and to your Mac**.

```
Mac                     192.168.56.1   (VirtualBox virtual NIC — vboxnet0)
controlplane01          192.168.56.11
controlplane02          192.168.56.12
loadbalancer            192.168.56.30
node01                  192.168.56.21
node02                  192.168.56.22
```

- Every VM has interface `enp0s8` on this network.
- **Your Mac can ping any of these IPs directly** — no SSH tunnel needed.
- This is how you will access NodePort services from your browser on Mac.

### Layer 2 — Kubernetes Service Network (`10.96.0.0/16`)

Virtual IPs that Kubernetes assigns to Services. These IPs do **not** exist on any real interface. kube-proxy creates `iptables` rules on every node so that when a pod (or node) tries to reach a Service IP, it gets silently redirected to a real pod IP.

```
10.96.0.1     kubernetes (the API server itself as a Service)
10.96.0.10    kube-dns   (CoreDNS)
10.96.x.x     any Service you create
```

### Layer 3 — Pod Network (`10.244.0.0/16`)

Each node gets a `/24` subnet from this range. Weave Net assigns an IP from that subnet to each pod.

```
node01 pods live in  10.244.1.0/24
node02 pods live in  10.244.2.0/24
```

Pods on different nodes can talk to each other via Weave Net's overlay network (explained later).

---

## 3. Component Deep-Dive

### etcd

**What it is:** A distributed, strongly-consistent key-value store. It is the **database** of Kubernetes — the only place where all cluster state is persisted.

**What is stored:** Every object you create (Pods, Services, Deployments, Secrets, ConfigMaps, etc.) is stored as a key-value pair in etcd.

**Why two instances:** Running etcd on both controlplane01 and controlplane02 gives you a **Raft consensus cluster**. As long as a majority (1 out of 2... technically you need 3 for true HA quorum, but 2 still tolerates single-node reads) are alive, the cluster continues to operate. All writes go through a leader elected by Raft.

**Port:** `2379` (client), `2380` (peer-to-peer between etcd nodes)

```
kube-apiserver  ──HTTPS──►  etcd :2379 (on both control planes)
```

---

### kube-apiserver

**What it is:** The **front door** of Kubernetes. Every single operation — `kubectl get pods`, a pod being scheduled, a controller updating a Deployment — goes through the API server. It is a stateless REST API.

**What it does:**
- Authenticates requests (checks TLS client certs or tokens)
- Authorizes them (RBAC rules)
- Validates and stores objects in etcd
- Serves as the only component that writes to etcd

**Port:** `6443` (HTTPS)

**In this setup:** Runs on both controlplane01 and controlplane02. HAProxy sits in front of both and balances traffic across them.

---

### kube-controller-manager

**What it is:** A single binary that runs dozens of **control loops** (controllers). A control loop watches the current state of the cluster and tries to make it match the desired state.

**Examples of controllers inside it:**
- **Node Controller** — watches nodes; if a node stops sending heartbeats, marks its pods as evicted after a timeout
- **Deployment Controller** — if you say "I want 3 replicas", it watches and creates/deletes ReplicaSets to match
- **ReplicaSet Controller** — creates/deletes Pods to match the desired replica count
- **ServiceAccount Controller** — creates default ServiceAccounts in new namespaces
- **EndpointSlice Controller** — keeps track of which pod IPs back a given Service

**Port:** Listens on `127.0.0.1` only (not reachable externally by design)

**In this setup:** Runs on both control planes. Only **one** is active at a time — the other is in standby. They use `--leader-elect=true` so they hold a distributed lock via etcd to decide who is active.

---

### kube-scheduler

**What it is:** Decides **which node** a newly created Pod should run on.

**How it works:**
1. Watches for Pods with no `nodeName` set (unscheduled pods)
2. Runs a two-phase algorithm:
   - **Filter** — eliminates nodes that can't run the pod (not enough CPU/memory, taint mismatch, etc.)
   - **Score** — ranks remaining nodes by how good a fit they are
3. Sets `pod.spec.nodeName` to the winner

The scheduler never starts the pod itself. It just writes the node assignment back to the API server, and the kubelet on that node picks it up.

**In this setup:** Also leader-elected across both control planes.

---

### HAProxy (Load Balancer)

**What it is:** A battle-tested, open-source **TCP/HTTP load balancer**. In this setup it runs on the `loadbalancer` VM.

**Why it is needed:** You have two API servers (controlplane01, controlplane02). Any client (kubectl, worker nodes, etc.) needs a single stable endpoint to talk to. HAProxy provides that at `192.168.56.30:6443`.

**How it is configured (from `08-haproxy.sh`):**

```
Client ──TCP:6443──► HAProxy @ 192.168.56.30
                         │
                         ├──► controlplane01 @ 192.168.56.11:6443  (round-robin)
                         └──► controlplane02 @ 192.168.56.12:6443
```

It uses **TCP passthrough mode** (`mode tcp`) — it does NOT decrypt TLS. The raw encrypted stream is forwarded as-is to one of the API servers. The API server handles TLS itself.

**Health checking:** HAProxy does a TCP check every few seconds. If one API server goes down, all traffic automatically routes to the other — no manual intervention needed.

---

### containerd (Container Runtime)

**What it is:** The low-level **container runtime** — the thing that actually pulls images, creates namespaces, and starts container processes.

**Why not Docker?** Kubernetes deprecated its direct Docker support. `containerd` is what Docker itself uses internally, but it is lighter and exposes the CRI (Container Runtime Interface) that Kubernetes requires.

**What it does:**
- Pulls container images from registries (Docker Hub, etc.)
- Unpacks images into a filesystem
- Creates Linux namespaces (pid, net, mnt, uts) to isolate the container
- Starts the container process

**Runs on:** node01 and node02 (worker nodes only)

**Socket:** `/var/run/containerd/containerd.sock` — kubelet talks to containerd through this Unix socket.

---

### kubelet

**What it is:** The **node agent** — runs on every worker node and is responsible for making sure that containers described in Pod specs are actually running and healthy.

**What it does:**
1. Registers the node with the API server (sends heartbeats every 10s)
2. Watches for Pods that have been scheduled to its node
3. Calls containerd to start/stop/restart containers
4. Reports pod and node status back to the API server
5. Runs **liveness** and **readiness probes**
6. Mounts volumes into pods

**Runs on:** node01, node02

**Port:** `10250` (HTTPS) — the API server calls back to kubelet on this port to get logs, exec into pods, etc.

---

### kube-proxy

**What it is:** A network proxy that runs on every node. It implements the Kubernetes **Service** abstraction.

**The problem it solves:** Pods come and go — their IPs change. A Service gives you a stable virtual IP (ClusterIP). kube-proxy makes that virtual IP actually work.

**How it works (iptables mode, used here):**

When you create a Service with ClusterIP `10.96.5.10` backed by two pods at `10.244.1.5` and `10.244.2.7`, kube-proxy writes iptables rules like:

```
PREROUTING: if dst == 10.96.5.10:80 → randomly pick one of:
  → DNAT to 10.244.1.5:8080
  → DNAT to 10.244.2.7:8080
```

These rules exist on **every node**, so any pod on any node can reach a Service. kube-proxy watches the API server for changes and updates iptables rules in real-time as pods are added/removed.

**NodePort:** When you create a Service of type `NodePort`, kube-proxy additionally adds rules so that traffic arriving at `<any-node-IP>:<nodePort>` is forwarded to the right pods.

---

### Weave Net (CNI)

**What it is:** The **Container Network Interface** plugin. CNI is a spec that Kubernetes calls to set up networking for every new pod.

**The problem it solves:** Pods on node01 (10.244.1.x) need to talk to pods on node02 (10.244.2.x). These are different physical machines. How does a packet from `10.244.1.5` reach `10.244.2.7`?

**How Weave Net works:**

Weave creates a virtual network device (`weave`) on each node and builds an **overlay network** using VXLAN (or PCAP encapsulation). Think of it as a virtual Ethernet cable connecting all nodes.

```
Pod A (10.244.1.5) on node01
  │
  └──► weave interface (10.244.1.1) on node01
         │
         │   ← Weave wraps the original packet inside a UDP packet
         │
  node01 (192.168.56.21) ──UDP:6783──► node02 (192.168.56.22)
                                              │
                                              └──► weave interface (10.244.2.1) on node02
                                                       │
                                                       └──► Pod B (10.244.2.7) on node02
```

From the pods' perspective, they are on the same flat network (`10.244.0.0/16`) and can talk directly. The encapsulation is completely transparent.

Weave runs as a **DaemonSet** — one pod on every node.

---

### CoreDNS

**What it is:** The **cluster DNS server**. It runs as a Deployment inside Kubernetes (`kube-system` namespace) and gives every Service and Pod in the cluster a DNS name.

**Why you need it:** kube-proxy gives you stable IPs for Services, but remembering IPs is hard. CoreDNS lets you use names instead.

**How it works:**

CoreDNS gets the ClusterIP `10.96.0.10`. Every kubelet is configured with `clusterDNS: 10.96.0.10`, so every pod's `/etc/resolv.conf` points to CoreDNS.

When a pod does `curl http://my-service`, the OS sends a DNS query to `10.96.0.10`. CoreDNS:
1. Checks if the name matches a Kubernetes Service
2. Returns the Service's ClusterIP

**DNS naming convention:**

```
<service-name>.<namespace>.svc.cluster.local

Examples:
  nginx-service.default.svc.cluster.local   → 10.96.x.x
  kube-dns.kube-system.svc.cluster.local     → 10.96.0.10
```

Pods in the same namespace can just use `<service-name>` — CoreDNS appends the search domains automatically.

**What CoreDNS is NOT:** It is not the DNS server for the internet. It only knows about cluster-internal names. For anything else (e.g., `google.com`), CoreDNS **forwards** the query to the upstream DNS server (typically the node's DNS, which is the internet).

---

## 4. How All Components Talk to Each Other

Here is the full picture of how a pod gets created from the moment you run `kubectl apply`:

```
kubectl apply -f nginx.yaml
    │
    │ HTTPS to 192.168.56.30:6443
    ▼
HAProxy (loadbalancer)
    │
    │ TCP forward to controlplane01 or controlplane02
    ▼
kube-apiserver
    │  1. Authenticates (checks TLS cert)
    │  2. Authorizes (RBAC)
    │  3. Validates the manifest
    │  4. Writes Pod object to etcd (status: Pending, nodeName: "")
    ▼
etcd  ← stores the Pod object

kube-scheduler (watching apiserver via long-poll / watch)
    │  1. Sees new Pod with no nodeName
    │  2. Filters nodes (enough CPU/memory?)
    │  3. Scores nodes
    │  4. Picks node01
    │  5. Patches the Pod object: nodeName = "node01"
    ▼
etcd  ← updated Pod object

kubelet on node01 (watching apiserver)
    │  1. Sees Pod assigned to it
    │  2. Calls containerd via CRI to pull nginx image
    │  3. containerd pulls image, creates container
    │  4. Calls Weave Net CNI to set up pod networking (assigns 10.244.1.x IP)
    │  5. Starts the container
    │  6. Reports back to apiserver: Pod is Running
    ▼
Pod is running on node01 with IP 10.244.1.x

kube-controller-manager (if this is a Deployment)
    │  Watches ReplicaSet — confirms 1 replica is running
    │  If pod dies → creates a new one → back to kube-scheduler
```

---

## 5. Accessing the Cluster from Your Mac

### Option A — SSH into controlplane01 (simplest)

```bash
vagrant ssh controlplane01
kubectl get nodes
kubectl get pods -A
```

### Option B — Use kubectl directly from your Mac

The VirtualBox host-only network (`192.168.56.x`) is reachable from your Mac. You just need the kubeconfig.

**Step 1 — Copy the kubeconfig from controlplane01:**

```bash
# From the vagrant/ directory on your Mac
vagrant ssh controlplane01 -- "cat ~/admin.kubeconfig" > ~/.kube/k8s-hard-way.yaml
```

**Step 2 — Point kubectl to the load balancer:**

The kubeconfig already points to `https://192.168.56.30:6443` (HAProxy). Since your Mac can reach that IP directly, it just works.

**Step 3 — Use it:**

```bash
export KUBECONFIG=~/.kube/k8s-hard-way.yaml
kubectl get nodes -o wide
```

You should see:

```
NAME       STATUS   ROLES    AGE   VERSION   INTERNAL-IP
node01     Ready    <none>   ...   v1.x.x    192.168.56.21
node02     Ready    <none>   ...   v1.x.x    192.168.56.22
```

---

## 6. Running an Nginx Pod and Accessing It

### Step 1 — Deploy nginx

```bash
kubectl create deployment nginx --image=nginx --replicas=2
```

### Step 2 — Expose it as a NodePort Service

```bash
kubectl expose deployment nginx --type=NodePort --port=80
```

### Step 3 — Find out which port was assigned

```bash
kubectl get svc nginx
```

Output example:
```
NAME    TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
nginx   NodePort   10.96.45.12   <none>        80:31234/TCP   5s
```

The number after the `:` (e.g., `31234`) is the **NodePort**. Kubernetes picks a random port from the range `30000–32767`.

### Step 4 — Access from your Mac browser

Open your browser and go to:

```
http://192.168.56.21:31234
```

or

```
http://192.168.56.22:31234
```

**Both work.** Thanks to kube-proxy's iptables rules, traffic arriving at **any node's** NodePort gets forwarded to the nginx pods, regardless of which node they are actually running on.

```
Mac Browser
  │
  │  HTTP to 192.168.56.21:31234
  ▼
node01 iptables (kube-proxy rules)
  │   DNAT → nginx pod IP (wherever it is)
  ▼
nginx pod responds with "Welcome to nginx!"
```

### To pin the port (optional)

If you want a specific port every time:

```bash
kubectl expose deployment nginx --type=NodePort --port=80 --name=nginx-fixed \
  --overrides='{"spec":{"ports":[{"port":80,"nodePort":31000,"targetPort":80,"protocol":"TCP"}]}}'
```

Then access via `http://192.168.56.21:31000`.

### Why can't you access ClusterIP directly from Mac?

The `10.96.x.x` Service IPs and `10.244.x.x` Pod IPs only exist inside the cluster's iptables and Weave overlay. Your Mac does not have routes to those ranges. Only traffic that enters via a **NodePort** or **hostPort** is bridged to your Mac's network.

---

## 7. How Internet Access Works for Pods

Every Vagrant VM has **two network interfaces**:

```
eth0  (NAT)         ← VirtualBox manages this; provides internet access via your Mac's internet
enp0s8 (host-only)  ← 192.168.56.x — for cluster communication
```

### When a pod in the cluster tries to reach the internet (e.g., curl google.com):

```
Pod (10.244.1.5)
  │
  │  packet: src=10.244.1.5, dst=142.250.x.x (google)
  ▼
Weave Net on node01
  │  Pod is local → doesn't need overlay tunneling
  │  Routes packet out via the node's default gateway
  ▼
node01's kernel
  │
  │  Linux MASQUERADE iptables rule (set up by Weave):
  │    src=10.244.1.5 → SNAT → src=192.168.56.21
  │  (or uses eth0's NAT IP)
  ▼
VirtualBox NAT (eth0 on the VM)
  │  Another SNAT: src=192.168.56.21 → src=<your Mac's public IP>
  ▼
Your Mac's network interface
  │
  ▼
Internet  ←→  google.com
```

**Key point:** Weave Net installs a `MASQUERADE` iptables rule so pod IPs are hidden behind the node's real IP. VirtualBox's NAT does a second layer of masquerading so the node's IP is hidden behind your Mac's IP. The pod sees the response come back through this chain in reverse.

### DNS resolution for external names

```
Pod wants to resolve "google.com"
  │
  │  DNS query to 10.96.0.10 (CoreDNS, from /etc/resolv.conf)
  ▼
CoreDNS
  │  "google.com" is not a cluster Service
  │  Forwards to upstream DNS (node's /etc/resolv.conf → typically 8.8.8.8 or your router)
  ▼
kube-proxy routes 10.96.0.10 → actual CoreDNS pod IP
  ▼
CoreDNS pod queries 8.8.8.8 (via the same internet path described above)
  ▼
Returns IP to the pod
```

---

## 8. IP Address Reference

| Host | IP | Interface | Role |
|---|---|---|---|
| Your Mac | 192.168.56.1 | vboxnet0 | VirtualBox host gateway |
| controlplane01 | 192.168.56.11 | enp0s8 | etcd, kube-apiserver, controller-manager, scheduler |
| controlplane02 | 192.168.56.12 | enp0s8 | etcd, kube-apiserver, controller-manager, scheduler |
| loadbalancer | 192.168.56.30 | enp0s8 | HAProxy → forwards :6443 to both control planes |
| node01 | 192.168.56.21 | enp0s8 | kubelet, kube-proxy, containerd, Weave |
| node02 | 192.168.56.22 | enp0s8 | kubelet, kube-proxy, containerd, Weave |
| kubernetes Service | 10.96.0.1 | virtual | kube-apiserver Service ClusterIP |
| CoreDNS Service | 10.96.0.10 | virtual | cluster DNS |
| Pod network | 10.244.0.0/16 | Weave overlay | all pod IPs |

### Port Reference

| Port | On | Used By |
|---|---|---|
| 6443 | controlplane01/02, loadbalancer | kube-apiserver / HAProxy frontend |
| 2379 | controlplane01/02 | etcd client port |
| 2380 | controlplane01/02 | etcd peer (Raft) port |
| 10250 | node01/02 | kubelet API (used by apiserver for logs/exec) |
| 30000–32767 | node01/02 | NodePort Services (accessible from Mac) |

---

## Quick Cheat Sheet

```bash
# SSH into any node
vagrant ssh controlplane01
vagrant ssh node01

# Check cluster health
kubectl get nodes -o wide
kubectl get pods -A

# Deploy nginx and access from Mac
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --type=NodePort --port=80
kubectl get svc nginx   # note the NodePort
open http://192.168.56.21:<NodePort>

# Check HAProxy status (on loadbalancer)
vagrant ssh loadbalancer -- "sudo systemctl status haproxy"

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check Weave Net
kubectl get pods -n kube-system -l name=weave-net
```
