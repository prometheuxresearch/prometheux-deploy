#!/bin/bash

# Databricks Spark Connect Cluster Setup and Test Runner Script
# This script helps automate the setup and testing process for Spark Connect

set -e  # Exit on any error

# Default Cluster Configuration Variables
DEFAULT_CLUSTER_NAME="prometheux-spark-connect"
DEFAULT_SPARK_VERSION="17.1.x-scala2.13"
DEFAULT_NODE_TYPE="i3.xlarge"
DEFAULT_DRIVER_NODE_TYPE="i3.xlarge"
DEFAULT_MIN_WORKERS=1
DEFAULT_MAX_WORKERS=3

# Allow environment variable overrides
CLUSTER_NAME="${CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}"
SPARK_VERSION="${SPARK_VERSION:-$DEFAULT_SPARK_VERSION}"
NODE_TYPE="${NODE_TYPE:-$DEFAULT_NODE_TYPE}"
DRIVER_NODE_TYPE="${DRIVER_NODE_TYPE:-$DEFAULT_DRIVER_NODE_TYPE}"
MIN_WORKERS="${MIN_WORKERS:-$DEFAULT_MIN_WORKERS}"
MAX_WORKERS="${MAX_WORKERS:-$DEFAULT_MAX_WORKERS}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are installed
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform >= 1.25.0"
        exit 1
    fi
    
    # Check Java
    if ! command -v java &> /dev/null; then
        print_error "Java is not installed. Please install Java 17"
        exit 1
    fi
    
    # Check Maven
    if ! command -v mvn &> /dev/null; then
        print_error "Maven is not installed. Please install Maven"
        exit 1
    fi
    
    print_success "All dependencies are available"
}

# Function to check environment variables
check_environment() {
    print_status "Checking environment variables..."
    
    local missing_vars=()
    
    if [[ -z "$DATABRICKS_HOST" ]]; then
        missing_vars+=("DATABRICKS_HOST")
    fi
    
    if [[ -z "$DATABRICKS_TOKEN" ]]; then
        missing_vars+=("DATABRICKS_TOKEN")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "Missing required environment variables: ${missing_vars[*]}"
        echo ""
        echo "Please set the following environment variables:"
        echo "export DATABRICKS_HOST=\"https://your-workspace.cloud.databricks.com\""
        echo "export DATABRICKS_TOKEN=\"your-personal-access-token\""
        echo ""
        echo "For testing, you'll also need:"
        echo "export DATABRICKS_CLUSTER_ID=\"cluster-id-after-creation\""
        exit 1
    fi
    
    print_success "Environment variables are set"
}

# Function to create terraform.tfvars if it doesn't exist
setup_terraform_vars() {
    if [[ ! -f "terraform.tfvars" ]]; then
        print_status "Creating terraform.tfvars file..."
        
        cat > terraform.tfvars << EOF
# Databricks Configuration
databricks_host = "$DATABRICKS_HOST"
databricks_token = "$DATABRICKS_TOKEN"

# Cluster Configuration
cluster_name = "$CLUSTER_NAME"
spark_version = "$SPARK_VERSION"
node_type_id = "$NODE_TYPE"
driver_node_type_id = "$DRIVER_NODE_TYPE"
min_workers = $MIN_WORKERS
max_workers = $MAX_WORKERS
EOF
        
        print_success "Created terraform.tfvars with environment variables"
    else
        print_status "terraform.tfvars already exists"
    fi
}

# Function to deploy Databricks cluster
deploy_cluster() {
    print_status "Deploying Databricks cluster..."
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan
    
    # Ask for confirmation
    echo ""
    read -p "Do you want to proceed with cluster deployment? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Apply deployment
        print_status "Applying Terraform deployment..."
        terraform apply -auto-approve
        
        # Get cluster ID
        CLUSTER_ID=$(terraform output -raw cluster_id)
        print_success "Cluster deployed successfully!"
        print_status "Cluster ID: $CLUSTER_ID"
        
        # Set environment variable for testing
        export DATABRICKS_CLUSTER_ID="$CLUSTER_ID"
        
        echo ""
        echo "To use this cluster in tests, set the environment variable:"
        echo "export DATABRICKS_CLUSTER_ID=\"$CLUSTER_ID\""
        echo ""
        
    else
        print_warning "Deployment cancelled"
        exit 0
    fi
}

# Function to run tests
run_tests() {
    print_status "Running Databricks Spark Connect tests..."
    
    # Change to project root directory
    cd ..
    
    # Check if cluster ID is set
    if [[ -z "$DATABRICKS_CLUSTER_ID" ]]; then
        print_error "DATABRICKS_CLUSTER_ID is not set. Please set it to your cluster ID"
        exit 1
    fi
    
    print_status "Running Maven tests..."
    mvn test -Dtest=TestDatabricksSparkConnect
    
    if [[ $? -eq 0 ]]; then
        print_success "All tests passed!"
    else
        print_error "Some tests failed. Check the output above for details."
        exit 1
    fi
}

# Function to show cluster status
show_cluster_status() {
    print_status "Checking cluster status..."
    
    if [[ -f "terraform.tfstate" ]]; then
        CLUSTER_ID=$(terraform output -raw cluster_id 2>/dev/null || echo "unknown")
        CLUSTER_URL=$(terraform output -raw cluster_url 2>/dev/null || echo "unknown")
        
        echo ""
        echo "Cluster Information:"
        echo "  Cluster ID: $CLUSTER_ID"
        echo "  Cluster URL: $CLUSTER_URL"
        echo ""
        
        if [[ "$CLUSTER_ID" != "unknown" ]]; then
            print_status "You can view your cluster at: $CLUSTER_URL"
        fi
    else
        print_warning "No Terraform state found. Cluster may not be deployed."
    fi
}

# Function to destroy cluster
destroy_cluster() {
    print_status "Destroying Databricks cluster..."
    
    # Ask for confirmation
    echo ""
    print_warning "This will destroy the Databricks cluster and all associated resources!"
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform destroy -auto-approve
        print_success "Cluster destroyed successfully!"
    else
        print_warning "Destruction cancelled"
    fi
}

# Function to show help
show_help() {
    echo "Databricks Spark Connect Cluster Setup and Test Runner"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup      Check dependencies and set up configuration"
    echo "  deploy     Deploy the Databricks cluster using Terraform"
    echo "  test       Run the Java Spark Connect tests"
    echo "  status     Show current cluster status"
    echo "  destroy    Destroy the Databricks cluster"
    echo "  all        Run setup, deploy, and test in sequence"
    echo "  help       Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  Required:"
    echo "    DATABRICKS_HOST     Your Databricks workspace URL"
    echo "    DATABRICKS_TOKEN    Your Databricks personal access token"
    echo "    DATABRICKS_CLUSTER_ID  Cluster ID (set automatically after deployment)"
    echo ""
    echo "  Optional (with defaults):"
    echo "    CLUSTER_NAME        Cluster name (default: $DEFAULT_CLUSTER_NAME)"
    echo "    SPARK_VERSION       Spark runtime version (default: $DEFAULT_SPARK_VERSION)"
    echo "    NODE_TYPE           Worker node type (default: $DEFAULT_NODE_TYPE)"
    echo "    DRIVER_NODE_TYPE    Driver node type (default: $DEFAULT_DRIVER_NODE_TYPE)"
    echo "    MIN_WORKERS         Minimum workers (default: $DEFAULT_MIN_WORKERS)"
    echo "    MAX_WORKERS         Maximum workers (default: $DEFAULT_MAX_WORKERS)"
    echo ""
}

# Main script logic
main() {
    # Change to script directory
    cd "$(dirname "$0")"
    
    case "${1:-help}" in
        "setup")
            check_dependencies
            check_environment
            setup_terraform_vars
            print_success "Setup completed successfully!"
            ;;
        "deploy")
            check_dependencies
            check_environment
            setup_terraform_vars
            deploy_cluster
            ;;
        "test")
            check_dependencies
            check_environment
            run_tests
            ;;
        "status")
            show_cluster_status
            ;;
        "destroy")
            destroy_cluster
            ;;
        "all")
            check_dependencies
            check_environment
            setup_terraform_vars
            deploy_cluster
            run_tests
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@" 