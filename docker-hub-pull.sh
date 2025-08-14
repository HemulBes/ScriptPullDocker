#!/bin/bash
# Script to pull and run container from Docker Hub

# Replace with the actual Docker Hub username and image name
DOCKER_USERNAME="hemulbes"
IMAGE_NAME="V4-web"
TAG="latest"

echo "Setting up Records App from Docker Hub..."

# Pull the image
echo "Pulling image from Docker Hub..."
docker pull $DOCKER_USERNAME/$IMAGE_NAME:$TAG

# Create project structure
mkdir -p records-app
cd records-app

# Create necessary directories
mkdir -p instance static/uploads backups logs templates

# Create environment file
cat > .env << EOF
SECRET_KEY=your-super-secret-key-change-this-in-production
FLASK_ENV=production
SQLALCHEMY_DATABASE_URI=sqlite:///instance/records.db
EOF

# Create docker-compose file
cat > docker-compose.yml << EOF
version: '3.8'

services:
  web:
    image: $DOCKER_USERNAME/$IMAGE_NAME:$TAG
    ports:
      - "8001:8000"
    environment:
      - FLASK_ENV=production
      - SECRET_KEY=\${SECRET_KEY:-change-this-secret-key}
      - SQLALCHEMY_DATABASE_URI=sqlite:///instance/records.db
    volumes:
      - ./instance:/app/instance
      - ./static/uploads:/app/static/uploads
      - ./backups:/app/backups
      - ./logs:/app/logs
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  default:
    name: records-network
EOF

# Set permissions
chmod 755 instance static/uploads backups logs

echo "Starting application..."
docker-compose up -d

echo "Waiting for application to start..."
sleep 10

# Initialize database
echo "Initializing database..."
docker-compose exec -T web python -c "
from app import app, db, User
from werkzeug.security import generate_password_hash
with app.app_context():
    db.create_all()
    admin = User(username='admin', password=generate_password_hash('admin123'), is_admin=True)
    db.session.add(admin)
    db.session.commit()
    print('Database initialized and admin user created')
"

echo "Setup complete!"
echo "Access your application at: http://localhost:8001"
echo "Username: admin"
echo "Password: admin123"
echo ""
echo "Don't forget to:"
echo "1. Change the default password"
echo "2. Update the SECRET_KEY in .env file"
echo "3. Configure firewall if needed"
