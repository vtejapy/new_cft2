#!/bin/bash

# Validation script for CloudFormation templates
# Usage: ./validate.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_message $RED "AWS CLI is not installed. Please install it first."
        exit 1
    fi
}

# Function to check if cfn-lint is installed
check_cfn_lint() {
    if ! command -v cfn-lint &> /dev/null; then
        print_message $YELLOW "cfn-lint is not installed. Installing..."
        pip install cfn-lint
    fi
}

# Function to validate a single template
validate_template() {
    local template=$1
    local errors=0
    
    print_message $YELLOW "Validating: $template"
    
    # AWS CloudFormation validation
    if aws cloudformation validate-template --template-body file://$template &> /dev/null; then
        print_message $GREEN "  ✓ AWS validation passed"
    else
        print_message $RED "  ✗ AWS validation failed"
        aws cloudformation validate-template --template-body file://$template
        ((errors++))
    fi
    
    # cfn-lint validation
    if cfn-lint $template &> /dev/null; then
        print_message $GREEN "  ✓ cfn-lint validation passed"
    else
        print_message $RED "  ✗ cfn-lint validation failed"
        cfn-lint $template
        ((errors++))
    fi
    
    return $errors
}

# Function to check template dependencies
check_dependencies() {
    local template=$1
    
    print_message $YELLOW "Checking dependencies for: $template"
    
    # Check for Ref and GetAtt references
    local refs=$(grep -E "!Ref|Ref:" $template | wc -l)
    local getatts=$(grep -E "!GetAtt|GetAtt:" $template | wc -l)
    local imports=$(grep -E "!ImportValue|ImportValue:" $template | wc -l)
    
    print_message $GREEN "  - References: $refs"
    print_message $GREEN "  - GetAtt calls: $getatts"
    print_message $GREEN "  - Import values: $imports"
}

# Function to check parameter files
check_parameter_files() {
    print_message $YELLOW "\nChecking parameter files..."
    
    for env in dev stg prod; do
        local param_file="parameters/${env}.json"
        if [ -f "$param_file" ]; then
            if jq empty $param_file 2>/dev/null; then
                print_message $GREEN "  ✓ $param_file is valid JSON"
                
                # Check if all required parameters are present
                local params=$(jq -r '.Parameters | keys[]' $param_file)
                print_message $GREEN "    Parameters defined: $(echo $params | wc -w)"
            else
                print_message $RED "  ✗ $param_file is not valid JSON"
            fi
        else
            print_message $RED "  ✗ $param_file not found"
        fi
    done
}

# Function to check template size
check_template_size() {
    local template=$1
    local size=$(stat -f%z "$template" 2>/dev/null || stat -c%s "$template" 2>/dev/null)
    local size_kb=$((size / 1024))
    
    if [ $size -gt 51200 ]; then  # 50KB limit for inline templates
        print_message $YELLOW "  ⚠ Template size: ${size_kb}KB (exceeds 50KB limit for inline templates)"
    else
        print_message $GREEN "  ✓ Template size: ${size_kb}KB"
    fi
}

# Function to check for hardcoded values
check_hardcoded_values() {
    local template=$1
    
    # Check for hardcoded account IDs
    if grep -q "[0-9]\{12\}" $template; then
        print_message $YELLOW "  ⚠ Possible hardcoded AWS account ID found"
    fi
    
    # Check for hardcoded regions
    if grep -qE "us-east-1|us-west-2|eu-west-1" $template; then
        print_message $YELLOW "  ⚠ Possible hardcoded region found"
    fi
    
    # Check for hardcoded IPs
    if grep -qE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" $template; then
        print_message $YELLOW "  ⚠ Possible hardcoded IP address found"
    fi
}

# Function to generate validation report
generate_report() {
    local total_errors=$1
    local total_warnings=$2
    local total_templates=$3
    
    print_message $YELLOW "\n========== Validation Report =========="
    print_message $GREEN "Total templates validated: $total_templates"
    
    if [ $total_errors -eq 0 ]; then
        print_message $GREEN "✓ All validations passed!"
    else
        print_message $RED "✗ Total errors: $total_errors"
    fi
    
    if [ $total_warnings -gt 0 ]; then
        print_message $YELLOW "⚠ Total warnings: $total_warnings"
    fi
    
    print_message $YELLOW "======================================"
}

# Main validation function
main() {
    print_message $GREEN "Starting CloudFormation template validation...\n"
    
    # Check prerequisites
    check_aws_cli
    check_cfn_lint
    
    local total_errors=0
    local total_warnings=0
    local total_templates=0
    
    # Validate main template
    if [ -f "main.yaml" ]; then
        validate_template "main.yaml"
        total_errors=$((total_errors + $?))
        check_template_size "main.yaml"
        check_hardcoded_values "main.yaml"
        check_dependencies "main.yaml"
        ((total_templates++))
        echo
    fi
    
    # Validate all templates in templates directory
    if [ -d "templates" ]; then
        for template in templates/*.yaml; do
            if [ -f "$template" ]; then
                validate_template "$template"
                total_errors=$((total_errors + $?))
                check_template_size "$template"
                check_hardcoded_values "$template"
                check_dependencies "$template"
                ((total_templates++))
                echo
            fi
        done
    else
        print_message $RED "templates directory not found!"
    fi
    
    # Check parameter files
    check_parameter_files
    
    # Generate report
    generate_report $total_errors $total_warnings $total_templates
    
    # Exit with error code if validation failed
    if [ $total_errors -gt 0 ]; then
        exit 1
    fi
}

# Run main function
main