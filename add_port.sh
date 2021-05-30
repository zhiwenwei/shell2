#!/bin/bash
port=$1
if [ -z $domain ]
then
    echo "usage:bash $0 port"
    exit 1
fi

echo "smtp2      inet  n       -       n       -       -       smtpd" >> /etc/postfix/master.cf 
echo -e "smtp2           ${port}/tcp          mail2\nsmtp2            ${port}/udp          mail2"  >>   /etc/services

firewall-cmd --permanent --add-port=${port}/tcp && firewall-cmd --reload
systemctl restart postfix
ss -anltp
