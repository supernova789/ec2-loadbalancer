#! /bin/bash
yum install httpd -y
echo "Deployed via Terraform $(hostname -f)" > /var/www/html/index.html
service httpd start
chkconfig httpd on