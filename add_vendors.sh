#!/bin/bash

echo "=== Registering Vendors on AWS Server ==="

echo "1. Registering Venkateshwara Store..."
curl -s -X POST http://localhost:5000/api/v1/auth/register-vendor \
  -H "Content-Type: application/json" \
  -d '{"ownerName":"Venkat Raja","phone":"9876543210","password":"Test@123","storeName":"Venkateshwara Store","storeAddress":"12, Anna Salai, Chennai","category":"Bakery","email":"venkat@store.com"}'
echo ""

echo "2. Registering Nelai Store..."
curl -s -X POST http://localhost:5000/api/v1/auth/register-vendor \
  -H "Content-Type: application/json" \
  -d '{"ownerName":"Nelai Kumar","phone":"9876543211","password":"Test@123","storeName":"Nelai Store","storeAddress":"45, Mount Road, Chennai","category":"Grocery","email":"nelai@store.com"}'
echo ""

echo "3. Registering OM Muruga Mess..."
curl -s -X POST http://localhost:5000/api/v1/auth/register-vendor \
  -H "Content-Type: application/json" \
  -d '{"ownerName":"Muruga Raj","phone":"9876543212","password":"Test@123","storeName":"OM Muruga Mess","storeAddress":"78, T Nagar, Chennai","category":"Food","email":"om@mess.com"}'
echo ""

echo "=== Done! ==="
