#!/bin/bash

echo "=== Creating Super Admin ==="
curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Super Admin","phone":"9000000000","email":"admin@namba.com","password":"Admin@123","role":"superadmin"}'
echo ""

echo "=== Admin Login ==="
ADMIN_RESPONSE=$(curl -s -X POST http://localhost:5000/api/v1/auth/admin-login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@namba.com","password":"Admin@123"}')
echo "$ADMIN_RESPONSE"

TOKEN=$(echo $ADMIN_RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null)
echo "Token: $TOKEN"

echo ""
echo "=== Getting All Vendors ==="
VENDORS=$(curl -s "http://localhost:5000/api/v1/admin/vendors" \
  -H "Authorization: Bearer $TOKEN")
echo "$VENDORS" | python3 -c "
import sys,json
d=json.load(sys.stdin)
vendors = d.get('data',[])
print('Total vendors:', len(vendors))
for v in vendors:
    print('  -', v.get('_id'), v.get('storeName'), v.get('approvalStatus'))
" 2>/dev/null

echo ""
echo "=== Approving All Vendors ==="
VENDOR_IDS=$(echo $VENDORS | python3 -c "
import sys,json
d=json.load(sys.stdin)
vendors = d.get('data',[])
for v in vendors:
    print(v.get('_id',''))
" 2>/dev/null)

for VID in $VENDOR_IDS; do
  if [ -n "$VID" ]; then
    echo "Approving: $VID"
    curl -s -X PUT "http://localhost:5000/api/v1/admin/vendors/$VID/approve" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json"
    echo ""
  fi
done

echo ""
echo "=== Testing Nearby Vendors API ==="
curl -s "http://localhost:5000/api/v1/vendors/nearby?lat=13.0827&lng=80.2707&radius=100" | python3 -c "
import sys,json
d=json.load(sys.stdin)
vendors = d.get('data',[])
print('Nearby vendors found:', len(vendors))
for v in vendors:
    print('  -', v.get('storeName',''), '|', v.get('approvalStatus',''))
" 2>/dev/null
