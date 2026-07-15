import re

filepath = 'lib/super_admin_dashboard.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# The code that was wrongly injected at the end of the file:
start_marker = "  bool _isFailedPaymentsLoading = false;"
end_marker = "    );\n  }\n}"

if start_marker in content:
    idx_start = content.find(start_marker)
    # find the very last } of the file, since we appended it there
    
    # extract the injected code
    injected_code = content[idx_start:]
    # remove the extra '}' that we added for the file
    injected_code = injected_code.strip()
    if injected_code.endswith('}'):
        injected_code = injected_code[:-1].strip() # remove the last }
    
    # remove it from the end of the file
    content = content[:idx_start]
    
    # now inject it right before `Widget _buildFinancialIntelligence() {`
    target_marker = "  Widget _buildFinancialIntelligence() {"
    
    content = content.replace(target_marker, injected_code + "\n\n" + target_marker)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Fixed successfully")
else:
    print("Not found")
