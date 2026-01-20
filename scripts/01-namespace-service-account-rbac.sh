#!/bin/bash
#Create namespace + service account + RBAC

kubectl apply -f k8s-homelab-phase-2/manifests/00-namespace.yaml
kubectl apply -f k8s-homelab-phase-2/manifests/01-serviceaccount.yaml
kubectl apply -f k8s-homelab-phase-2/manifests/02-rbac.yaml
