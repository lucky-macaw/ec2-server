#!/bin/bash
sudo yum update -y
sudo yum install -y httpd.x86_64
sudo timedatectl set-timezone Australia/Sydney
sudo systemctl start httpd.service
sudo systemctl enable httpd.service
sudo aws s3 cp s3://belong-test/index.html /var/www/html/