#!/bin/bash
#Test Routing

echo "=== Testing Ingress routing ==="
curl -H "Host: hello.local" http://worker-1:80
