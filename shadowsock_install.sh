#!/bin/sh
Server_IP=$(hostname -I)
yum install -y python-setuptools wget
wget https://pypi.python.org/packages/source/p/pip/pip-1.3.1.tar.gz --no-check-certificate -O /mnt/pip-1.3.1.tar.gz
cd /mnt && tar xf pip-1.3.1.tar.gz
cd pip-1.3.1 && python setup.py install
pip install shadowsocks
echo -e "{  
 \"server\":\"$Server_IP\",
 \"local_address\":\"127.0.0.1\",  
 \"local_port\":1080,  
 \"port_password\": {  
     \"9990\": \"WWW.163.com\"
 },  
 \"timeout\":600,  
 \"method\":\"rc4-md5\",  
 \"fast_open\": false 
}" > /etc/shadowsocks.json
ssserver -c /etc/shadowsocks.json -d start
echo "ssserver -c /etc/shadowsocks.json -d start" >> /etc/rc.d/rc.local
systemctl stop firewalld && systemctl disable firewalld
ssserver -c /etc/shadowsocks.json -d start
echo "ssserver -c /etc/shadowsocks.json -d start" >> /etc/rc.d/rc.local
