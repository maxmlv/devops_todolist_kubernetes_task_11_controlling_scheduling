# Validation Instructions

This document describes how to validate node taints/labels, StatefulSet and Deployment scheduling rules, and the `bootstrap.sh` deployment script.

## Prerequisites

- Cluster created via `kind create cluster --config cluster.yml`
- `bootstrap.sh` has been executed successfully

---

## 1. Inspect Nodes for Labels and Taints

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels,TAINTS:.spec.taints
```

**Expected:** Two nodes labeled `app=mysql`, three nodes labeled `app=todoapp`, with taints shown after step 2 is applied.

---

## 2. Verify Taint on `app=mysql` Nodes

```bash
kubectl get nodes -l app=mysql -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.taints}{"\n"}{end}'
```

**Expected:** Both nodes show a taint equivalent to `app=mysql:NoSchedule`.

---

## 3. StatefulSet (MySQL) Validation

### 3.1 Toleration — pods scheduled despite the taint

```bash
kubectl get pods -n mysql -o wide
```

**Expected:** All mysql pods `Running`, none `Pending`.

### 3.2 Pod Anti-Affinity — no two mysql pods on the same node

```bash
kubectl get pods -n mysql -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}'
```

**Expected:** Two distinct node names printed (no duplicates).

### 3.3 Node Affinity — mysql pods only on `app=mysql` nodes

```bash
kubectl get pods -n mysql -o wide
kubectl get nodes -l app=mysql
```

**Expected:** Every node listed in the first command's `NODE` column also appears in the second command's output.

---

## 4. Deployment (todoapp) Validation

### 4.1 Node Affinity (preferred) — todoapp pods on `app=todoapp` nodes

```bash
kubectl get pods -n todoapp -o wide
kubectl get nodes -l app=todoapp
```

**Expected:** Both todoapp pods' nodes appear in the second command's output. (This is a soft/preferred rule, so this confirms expected behavior under normal capacity, not a hard guarantee.)

### 4.2 Pod Anti-Affinity — no two todoapp pods on the same node

```bash
kubectl get pods -n todoapp -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}'
```

**Expected:** Two distinct node names printed (no duplicates).

---

## 5. Standalone ToDo App Pod Validation

```bash
kubectl get pod todoapp-pod -n todoapp -o wide
```

**Expected:** `STATUS` is `Running`, `READY` is `1/1`.

```bash
kubectl describe pod todoapp-pod -n todoapp
```

**Expected:** No `FailedScheduling` or `FailedMount` events; container image, env vars, and volume mounts match the Deployment's container spec.

```bash
kubectl exec -n todoapp todoapp-pod -- curl -sv http://localhost:8080/api/health
```

**Expected:** `HTTP/1.1 200 OK` response, confirming the app inside the standalone Pod is healthy independent of the Deployment.

---

## 6. Validate `bootstrap.sh`

```bash
./bootstrap.sh
kubectl get all -n mysql
kubectl get all -n todoapp
```

**Expected:** Script exits without errors; all expected resources (StatefulSet, Deployment, Services, etc.) are present and running in both namespaces.