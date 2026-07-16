#!/bin/bash
curl -s -X POST http://localhost:5000/api/v1/auth/register-vendor \
  -H "Content-Type: application/json" \
  -d '{"ownerName":"Test User","phone":"9111111111","password":"Test@123","storeName":"Test Store","category":"Food"}'
echo ""
