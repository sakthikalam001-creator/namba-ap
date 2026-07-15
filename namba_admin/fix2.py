import re

filepath = 'lib/super_admin_dashboard.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

target = "Text('Customer: $customerName\nVendor: $vendorName',"
replacement = "Text('Customer: $customerName\\nVendor: $vendorName',"

content = content.replace(target, replacement)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed newline")
