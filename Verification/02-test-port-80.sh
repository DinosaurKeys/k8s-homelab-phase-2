#!/bin/bash
# Test port 80 on each worker
echo "=== Testing port 80 on workers ==="

echo ""
echo "=== Testing port 443 on workers ==="
for worker in worker-1 worker-2 worker-3; do
  echo -n "$worker:443 - "
  curl -sk -o /dev/null -w "%{http_code}" https://$worker:443 --max-time 2 || echo "failed"
  echo ""
done
