#!/usr/bin/env bash

# Deploy the static landing site (../nikaudio-landing) to the server.
# No build step — the landing site is plain static files served by nginx
# (see config/nginx.landing.config.example).

# Load configuration
CONFIG_FILE="./config/deploy/dev.config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "Loaded configuration from $CONFIG_FILE"
else
    echo "Configuration file $CONFIG_FILE not found. Using defaults."
    # Default configuration
    SERVER_USER="ubuntu"
    SERVER_HOST="your-server.com"
    LANDING_PROJECT_PATH="../nikaudio-landing"
    LANDING_SERVER_PATH="/var/www/nikaudio-landing"
fi

# Fallbacks for configs that predate the landing site entries
LANDING_PROJECT_PATH="${LANDING_PROJECT_PATH:-../nikaudio-landing}"
LANDING_SERVER_PATH="${LANDING_SERVER_PATH:-/var/www/nikaudio-landing}"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command_exists rsync; then
        print_error "rsync is not installed or not in PATH"
        exit 1
    fi

    if ! command_exists ssh; then
        print_error "ssh is not installed or not in PATH"
        exit 1
    fi

    print_success "All prerequisites found"
}

# Validate the local landing site project
check_landing_project() {
    print_status "Checking landing site project..."

    if [ ! -d "$LANDING_PROJECT_PATH" ]; then
        print_error "Landing project directory '$LANDING_PROJECT_PATH' not found"
        exit 1
    fi

    if [ ! -f "$LANDING_PROJECT_PATH/index.html" ]; then
        print_error "No index.html found in '$LANDING_PROJECT_PATH'"
        exit 1
    fi

    print_success "Landing site project found at $LANDING_PROJECT_PATH"
}

# Test SSH connection
test_ssh_connection() {
    print_status "Testing SSH connection to server..."

    ssh -o ConnectTimeout=10 -o BatchMode=yes "$SERVER_USER@$SERVER_HOST" exit

    if [ $? -eq 0 ]; then
        print_success "SSH connection successful"
    else
        print_error "Failed to connect to server via SSH"
        print_error "Please check your SSH configuration and server details"
        exit 1
    fi
}

# Create deployment directory structure on server
create_server_directories() {
    print_status "Creating directory structure on server..."

    ssh "$SERVER_USER@$SERVER_HOST" "sudo rm -rf $LANDING_SERVER_PATH 2>/dev/null || true"

    ssh "$SERVER_USER@$SERVER_HOST" "
        sudo mkdir -p $LANDING_SERVER_PATH
        sudo chown -R $SERVER_USER:users $LANDING_SERVER_PATH
    "

    if [ $? -eq 0 ]; then
        print_success "Directory structure created"
    else
        print_error "Failed to create directory structure"
        exit 1
    fi
}

# Deploy landing site
deploy_landing() {
    print_status "Deploying landing site..."

    # Copy static files (no build step), excluding repo-only files
    rsync -av --delete \
        --exclude '.git' \
        --exclude 'scripts/' \
        --exclude 'README.md' \
        --exclude '.gitignore' \
        "$LANDING_PROJECT_PATH/" "$SERVER_USER@$SERVER_HOST:$LANDING_SERVER_PATH/"

    if [ $? -ne 0 ]; then
        print_error "Failed to copy landing site files"
        exit 1
    fi

    ssh "$SERVER_USER@$SERVER_HOST" "sudo chown -R nginx:nginx $LANDING_SERVER_PATH"

    if [ $? -eq 0 ]; then
        print_success "Landing site deployed successfully"
    else
        print_error "Failed to deploy landing site"
        exit 1
    fi
}

# Main deployment function
main() {
    print_status "Starting landing site deployment process..."

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  -h, --help          Show this help message"
                echo ""
                echo "Deploys the static landing site from LANDING_PROJECT_PATH"
                echo "to LANDING_SERVER_PATH on the server (see $CONFIG_FILE)."
                exit 0
                ;;
            *)
                print_error "Unknown option $1"
                exit 1
                ;;
        esac
    done

    # Run deployment steps
    check_prerequisites
    check_landing_project
    test_ssh_connection
    create_server_directories
    deploy_landing

    print_success "Deployment completed successfully!"
    print_status "The landing site should now be served by nginx"

    # Show some helpful information
    echo ""
    echo "Next steps:"
    echo "- Configure nginx for the landing site (see config/nginx.landing.config.example)"
    echo "- Set up SSL certificates if needed"
}

# Run main function
main "$@"
