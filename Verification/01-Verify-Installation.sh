#!/bin/bash
echo "=== Pods (should be 3 - one per worker) ==="
kubectl get pods -n ingress-nginx -o wide

echo ""
echo "=== DaemonSet status ==="
kubectl get daemonset -n ingress-nginx

echo ""
echo "=== IngressClass ==="
kubectl get ingressclass

echo ""
echo "=== Services ==="
kubectl get svc -n ingress-nginx
