#!/usr/bin/env bash

# Load configuration
CONFIG_FILE="./config/deploy/dev.config"
ENV_FILE_PATH="./config/deploy/dev.env"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "Loaded configuration from $CONFIG_FILE"
else
    echo "Configuration file $CONFIG_FILE not found. Using defaults."
    # Default configuration
    SERVER_USER="ubuntu"
    SERVER_HOST="your-server.com"
    SERVER_PATH="/home/ubuntu/myapp"
    GO_PROJECT_PATH="./go-backend"
    ANGULAR_PROJECT_PATH="./angular-frontend"
    GO_BINARY_NAME="myapp"
    SYSTEMD_SERVICE_NAME="myapp"
    GO_OS="linux"
    GO_ARCH="amd64"
fi

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
    
    if ! command_exists go; then
        print_error "Go is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists npm; then
        print_error "npm is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists scp; then
        print_error "scp is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists ssh; then
        print_error "ssh is not installed or not in PATH"
        exit 1
    fi
    
    print_success "All prerequisites found"
}

# Build Go backend
build_go() {
    print_status "Building Go backend..."
    
    if [ ! -d "$GO_PROJECT_PATH" ]; then
        print_error "Go project directory '$GO_PROJECT_PATH' not found"
        exit 1
    fi
    
    cd "$GO_PROJECT_PATH" || exit 1
    
    # Build for target OS and architecture
    GOOS=${GO_OS:-linux} GOARCH=${GO_ARCH:-amd64} go build -o "$GO_BINARY_NAME" .
    
    if [ $? -eq 0 ]; then
        print_success "Go backend built successfully"
    else
        print_error "Failed to build Go backend"
        exit 1
    fi
    
    cd - > /dev/null
}

# Build Angular frontend
build_angular() {
    print_status "Building Angular frontend..."
    
    if [ ! -d "$ANGULAR_PROJECT_PATH" ]; then
        print_error "Angular project directory '$ANGULAR_PROJECT_PATH' not found"
        exit 1
    fi
    
    cd "$ANGULAR_PROJECT_PATH" || exit 1
    
    # Install dependencies if node_modules doesn't exist
    if [ ! -d "node_modules" ]; then
        print_status "Installing npm dependencies..."
        npm install
    fi
    
    # Build for production
    npm run build
    
    if [ $? -eq 0 ]; then
        print_success "Angular frontend built successfully"
    else
        print_error "Failed to build Angular frontend"
        exit 1
    fi
    
    cd - > /dev/null
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
    
    ssh "$SERVER_USER@$SERVER_HOST" "sudo rm -rf /var/www/nikaudio 2>/dev/null || true"

    ssh "$SERVER_USER@$SERVER_HOST" "
        sudo mkdir -p /var/www/nikaudio
        sudo chown -R tilen:users /var/www/nikaudio
        mkdir -p $SERVER_PATH
        mkdir -p $SERVER_PATH/frontend
        mkdir -p $SERVER_PATH/backend
        mkdir -p $SERVER_PATH/audio
    "
    
    if [ $? -eq 0 ]; then
        print_success "Directory structure created"
    else
        print_error "Failed to create directory structure"
        exit 1
    fi
}

# Deploy Go backend
deploy_go() {
    print_status "Deploying Go backend..."
    
    # Stop the service if it's running
    ssh "$SERVER_USER@$SERVER_HOST" "sudo systemctl stop $SYSTEMD_SERVICE_NAME 2>/dev/null || true"

    ssh "$SERVER_USER@$SERVER_HOST" "rm -rf $SERVER_PATH/backend/$GO_BINARY_NAME 2>/dev/null || true"
    
    # Copy binary
    scp "$GO_PROJECT_PATH/$GO_BINARY_NAME" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/backend/"
    
    # Copy audio files if they exist
    # print_status "Copying audio files..."
    # scp -r "$GO_PROJECT_PATH/audio" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/backend/audio"

    if [ -f "$ENV_FILE_PATH" ]; then
        print_status "Copying environment file..."
        scp "$ENV_FILE_PATH" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/backend/.env"
        # Secure the file so only the owner can read it
        ssh "$SERVER_USER@$SERVER_HOST" "chmod 600 $SERVER_PATH/backend/.env"
    else
        print_warning "No environment file found at $ENV_FILE_PATH. Skipping."
    fi

    
    # Make binary executable
    ssh "$SERVER_USER@$SERVER_HOST" "chmod +x $SERVER_PATH/backend/$GO_BINARY_NAME"
    
    if [ $? -eq 0 ]; then
        print_success "Go backend deployed successfully"
    else
        print_error "Failed to deploy Go backend"
        exit 1
    fi
}

# Deploy Angular frontend
deploy_angular() {
    print_status "Deploying Angular frontend..."
    

    # Copy built frontend
    scp -r "$ANGULAR_PROJECT_PATH/dist/"* "$SERVER_USER@$SERVER_HOST:/var/www/nikaudio"
    ssh "$SERVER_USER@$SERVER_HOST" "sudo chown -R nginx:nginx /var/www/nikaudio"
    
    if [ $? -eq 0 ]; then
        print_success "Angular frontend deployed successfully"
    else
        print_error "Failed to deploy Angular frontend"
        exit 1
    fi
}

# Start services
start_services() {
    print_status "Starting services on server..."
    # 
    # # Start systemd service if configured
    # ssh "$SERVER_USER@$SERVER_HOST" "
    #     cd $SERVER_PATH/backend
    #     
    #     # Start the Go service (adjust this based on your setup)
    #     if systemctl list-units --type=service | grep -q $SYSTEMD_SERVICE_NAME; then
    #         sudo systemctl start $SYSTEMD_SERVICE_NAME
    #         sudo systemctl enable $SYSTEMD_SERVICE_NAME
    #         print_success 'Systemd service started'
    #     else
    #         # Start manually in background (you might want to use screen or tmux instead)
    #         nohup ./$GO_BINARY_NAME > app.log 2>&1 &
    #         echo 'Started Go backend manually'
    #     fi
    # "
}

# Create systemd service file (optional)
create_systemd_service() {
    print_status "Creating systemd service file..."
    
    cat > /tmp/${SYSTEMD_SERVICE_NAME}.service << EOF
[Unit]
Description=My Go App
After=network.target

[Service]
Type=simple
User=$SERVER_USER
WorkingDirectory=$SERVER_PATH/backend
EnvironmentFile=$SERVER_PATH/backend/.env
ExecStart=$SERVER_PATH/backend/$GO_BINARY_NAME
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    scp /tmp/${SYSTEMD_SERVICE_NAME}.service "$SERVER_USER@$SERVER_HOST:/tmp/"
    ssh "$SERVER_USER@$SERVER_HOST" "
        sudo mv /tmp/${SYSTEMD_SERVICE_NAME}.service /etc/systemd/system/
        sudo systemctl daemon-reload
    "
    
    rm /tmp/${SYSTEMD_SERVICE_NAME}.service
    print_success "Systemd service file created"
}

# Main deployment function
main() {
    print_status "Starting deployment process..."
    
    # Parse command line arguments
    CREATE_SERVICE=false
    SKIP_BUILD=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --create-service)
                CREATE_SERVICE=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --create-service    Create systemd service file"
                echo "  --skip-build        Skip building step (use existing builds)"
                echo "  -h, --help          Show this help message"
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
    test_ssh_connection
    create_server_directories
    
    if [ "$SKIP_BUILD" = false ]; then
        build_go
        build_angular
    else
        print_warning "Skipping build step as requested"
    fi
    
    deploy_go
    deploy_angular
    
    if [ "$CREATE_SERVICE" = true ]; then
        create_systemd_service
    fi
    
    start_services
    
    print_success "Deployment completed successfully!"
    print_status "Your application should now be running on the server"
    
    # Show some helpful information
    echo ""
    echo "Next steps:"
    echo "- Configure your web server (nginx/apache) to serve the frontend"
    echo "- Set up SSL certificates if needed"
    echo "- Configure firewall rules"
    echo "- Monitor logs: ssh $SERVER_USER@$SERVER_HOST 'tail -f $SERVER_PATH/backend/app.log'"
}

# Run main function
main "$@"
