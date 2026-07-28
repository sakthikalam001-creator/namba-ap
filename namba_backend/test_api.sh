#!/bin/bash
# Test login and orders API
echo "=== Testing Login ==="
curl -s -X POST http://localhost:5000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"9876543212","password":"vendor123"}'

echo ""
echo ""
echo "=== Testing Orders for OM Muruga Mess ==="
curl -s http://localhost:5000/api/v1/orders/vendor/6a57aefb16962c32adc0341c | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('success:', d.get('success'))
print('count:', d.get('count'))
orders = d.get('data', [])
statuses = {}
for o in orders:
    s = o.get('status', 'Unknown')
    statuses[s] = statuses.get(s, 0) + 1
print('status breakdown:', statuses)
"
