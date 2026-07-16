#!/bin/bash
echo "=== Creating Admin with sakthikalam001@gmail.com ==="
curl -s -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Sakthikalam Admin","phone":"9000000001","email":"sakthikalam001@gmail.com","password":"Admin@123","role":"superadmin"}'
echo ""
echo "=== Testing Login ==="
curl -s -X POST http://localhost:5000/api/v1/auth/admin-login \
  -H "Content-Type: application/json" \
  -d '{"email":"sakthikalam001@gmail.com","password":"Admin@123"}'
echo ""
