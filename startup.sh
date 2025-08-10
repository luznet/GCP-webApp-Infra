#!/bin/bash
# Startup script for web server (Nginx example)
apt-get update
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
# Optionally, add app deployment steps here
