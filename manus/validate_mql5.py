#!/usr/bin/env python3
"""
MQL5 Code Validation Script
Validates the structure and syntax of the TokyoFVG_EA.mq5 file
"""

import re
import sys

def validate_mql5_file(filename):
    """Validate MQL5 file structure and basic syntax"""
    
    print(f"Validating MQL5 file: {filename}")
    print("=" * 50)
    
    try:
        with open(filename, 'r', encoding='utf-8') as file:
            content = file.read()
    except FileNotFoundError:
        print(f"ERROR: File {filename} not found!")
        return False
    except Exception as e:
        print(f"ERROR: Could not read file {filename}: {e}")
        return False
    
    validation_results = []
    
    # Check 1: File header and metadata
    print("1. Checking file header and metadata...")
    if re.search(r'#property\s+copyright', content):
        validation_results.append("✓ Copyright property found")
    else:
        validation_results.append("✗ Copyright property missing")
    
    if re.search(r'#property\s+version', content):
        validation_results.append("✓ Version property found")
    else:
        validation_results.append("✗ Version property missing")
    
    # Check 2: Input parameters
    print("2. Checking input parameters...")
    input_groups = re.findall(r'input\s+group\s+"([^"]+)"', content)
    if len(input_groups) >= 5:
        validation_results.append(f"✓ Found {len(input_groups)} input parameter groups")
        for group in input_groups:
            validation_results.append(f"  - {group}")
    else:
        validation_results.append("✗ Insufficient input parameter groups")
    
    # Check 3: Required MQL5 functions
    print("3. Checking required MQL5 functions...")
    required_functions = [
        'OnInit',
        'OnDeinit', 
        'OnTick'
    ]
    
    for func in required_functions:
        if re.search(rf'int\s+{func}\s*\(', content) or re.search(rf'void\s+{func}\s*\(', content):
            validation_results.append(f"✓ {func}() function found")
        else:
            validation_results.append(f"✗ {func}() function missing")
    
    # Check 4: Custom functions
    print("4. Checking custom functions...")
    custom_functions = [
        'UpdateTokyoSession',
        'CheckBreakouts',
        'DetectFairValueGaps',
        'PlaceFVGTrade',
        'CalculatePositionSize',
        'DrawTokyoLines',
        'DrawFVGRectangle'
    ]
    
    found_functions = 0
    for func in custom_functions:
        if re.search(rf'void\s+{func}\s*\(', content) or re.search(rf'bool\s+{func}\s*\(', content) or re.search(rf'double\s+{func}\s*\(', content):
            validation_results.append(f"✓ {func}() function found")
            found_functions += 1
        else:
            validation_results.append(f"✗ {func}() function missing")
    
    # Check 5: Global variables and structures
    print("5. Checking global variables and structures...")
    if re.search(r'struct\s+FVGPattern', content):
        validation_results.append("✓ FVGPattern structure defined")
    else:
        validation_results.append("✗ FVGPattern structure missing")
    
    if re.search(r'enum\s+TRADE_BIAS', content):
        validation_results.append("✓ TRADE_BIAS enum defined")
    else:
        validation_results.append("✗ TRADE_BIAS enum missing")
    
    # Check 6: Trading logic components
    print("6. Checking trading logic components...")
    trading_components = [
        'OrderSend',
        'PositionSelect',
        'AccountInfoDouble',
        'SymbolInfoDouble'
    ]
    
    for component in trading_components:
        if component in content:
            validation_results.append(f"✓ {component} usage found")
        else:
            validation_results.append(f"✗ {component} usage missing")
    
    # Check 7: Visual elements
    print("7. Checking visual elements...")
    visual_functions = [
        'ObjectCreate',
        'ObjectSetInteger',
        'ObjectSetString',
        'ObjectDelete'
    ]
    
    for func in visual_functions:
        if func in content:
            validation_results.append(f"✓ {func} usage found")
        else:
            validation_results.append(f"✗ {func} usage missing")
    
    # Check 8: Error handling and logging
    print("8. Checking error handling and logging...")
    if 'Print(' in content:
        print_count = len(re.findall(r'Print\s*\(', content))
        validation_results.append(f"✓ Found {print_count} Print() statements for logging")
    else:
        validation_results.append("✗ No Print() statements found")
    
    if 'Alert(' in content:
        alert_count = len(re.findall(r'Alert\s*\(', content))
        validation_results.append(f"✓ Found {alert_count} Alert() statements")
    else:
        validation_results.append("✗ No Alert() statements found")
    
    # Check 9: Syntax validation (basic)
    print("9. Checking basic syntax...")
    
    # Count braces
    open_braces = content.count('{')
    close_braces = content.count('}')
    if open_braces == close_braces:
        validation_results.append(f"✓ Balanced braces ({open_braces} pairs)")
    else:
        validation_results.append(f"✗ Unbalanced braces (open: {open_braces}, close: {close_braces})")
    
    # Count parentheses in function definitions
    function_defs = re.findall(r'\w+\s+\w+\s*\([^)]*\)\s*{', content)
    validation_results.append(f"✓ Found {len(function_defs)} function definitions")
    
    # Check 10: Code statistics
    print("10. Code statistics...")
    lines = content.split('\n')
    total_lines = len(lines)
    code_lines = len([line for line in lines if line.strip() and not line.strip().startswith('//')])
    comment_lines = len([line for line in lines if line.strip().startswith('//')])
    
    validation_results.append(f"✓ Total lines: {total_lines}")
    validation_results.append(f"✓ Code lines: {code_lines}")
    validation_results.append(f"✓ Comment lines: {comment_lines}")
    validation_results.append(f"✓ Comment ratio: {comment_lines/total_lines*100:.1f}%")
    
    # Print results
    print("\nValidation Results:")
    print("=" * 50)
    
    success_count = 0
    total_checks = 0
    
    for result in validation_results:
        print(result)
        total_checks += 1
        if result.startswith('✓'):
            success_count += 1
    
    print("\n" + "=" * 50)
    print(f"Validation Summary: {success_count}/{total_checks} checks passed")
    
    if success_count >= total_checks * 0.8:  # 80% pass rate
        print("✓ VALIDATION PASSED - Code structure looks good!")
        return True
    else:
        print("✗ VALIDATION FAILED - Code needs review")
        return False

if __name__ == "__main__":
    filename = "TokyoFVG_EA.mq5"
    success = validate_mql5_file(filename)
    sys.exit(0 if success else 1)

