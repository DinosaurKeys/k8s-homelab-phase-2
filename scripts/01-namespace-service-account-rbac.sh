#!/bin/bash
#Create namespace + service account + RBAC

kubectl apply -f manifests/ingress-nginx/00-namespace.yaml
kubectl apply -f manifests/ingress-nginx/01-serviceaccount.yaml
kubectl apply -f manifests/ingress-nginx/02-rbac.yaml
