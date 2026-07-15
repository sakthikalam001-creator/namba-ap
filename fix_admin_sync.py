import re

file_path = r'C:\Users\Admin\.gemini\antigravity\scratch\namaba_admin\lib\super_admin_dashboard.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the refresh logic in both approve and reject functions
new_content = re.sub(
    r'_fetchPendingVendors\(\);\s*//\s*Refresh\s*list',
    '_fetchPendingVendors(); _fetchAllVendors();',
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Successfully updated refresh logic!")
