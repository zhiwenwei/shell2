#!/bin/bash
#
domain=$1
if [ -z $domain ]
then
    echo "usage:bash $0 FQDN"
    exit 1
fi

setup_postfix() {
yum -y install postfix mailx > /dev/null
if rpm -q postfix
then 
  echo postfix is installed success.
else
  echo firewalld is install failed.
fi
cat <<EOF > /etc/postfix/main.cf
myhostname = $domain
mydomain = $domain
myorigin = \$mydomain
mynetworks = all
mydestination = \$mydomain
local_recipient_maps = 
default_destination_recipient_limit = 50000
smtpd_banner = \$myhostname ESMTP unknow
smtpd_sasl_auth_enable = yes
broken_sasl_auth_clients = yes
smtpd_sasl_local_domain = \$myhostname
smtpd_sasl_security_options = noanonymous
relay_domains = \$mydomain
smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated,reject_unauth_destination
message_size_limit = 10485760 
mailbox_transport=lmtp:unix:/var/lib/imap/socket/lmtp
smtpd_milters = inet:localhost:8891
non_smtpd_milters = inet:localhost:8891
milter_protocol = 6
milter_default_action = accept
EOF
postfix check && systemctl restart postfix
systemctl enable postfix
}

setup_cyrus-sasl() {
yum -y install cyrus-sasl* > /dev/null
Password=`echo $domain | tr a-z A-Z`@`date +%Y`
for i in {1..6};do
UserName=ken-`openssl rand -hex 1`
/usr/bin/id -u UserName 1>/dev/null
if [ $? = 0 ];then
    echo "$UserName user exists"
else
    useradd -M  $UserName -s /sbin/nologin && echo $Password | passwd $UserName --stdin > /dev/null 
    echo $UserName@$domain >> /root/user.txt
fi
done
echo -e "password:\n$Password\nport:25" >> /root/user.txt
echo USA | cat - /root/user.txt
systemctl restart saslauthd
systemctl enable saslauthd
}

setup_firewalld() {
yum -y install firewalld > /dev/null
if rpm -q firewalld 
then 
  echo firewalld is installed success.
else
  echo firewalld is install failed.
fi
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-port=34589/tcp --add-port=25/tcp 
firewall-cmd --permanent --add-rich-rule='rule protocol value=icmp drop'
firewall-cmd --reload
firewall-cmd --list-all
}

setup_opendkim() {
wget http://mirrors.aliyun.com/repo/epel-7.repo -P /etc/yum.repos.d/ > /dev/null && yum install -y  opendkim --enablerepo=epel > /dev/null || echo  "install opendkim failed."
echo "AutoRestart             Yes
AutoRestartRate         10/1h
LogWhy                  Yes
Syslog                  Yes
SyslogSuccess           Yes
Mode                    sv
Canonicalization        relaxed/simple
ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable
SignatureAlgorithm      rsa-sha256
Socket                  inet:8891@localhost
PidFile                 /var/run/opendkim/opendkim.pid
UMask                   022
UserID                  opendkim:opendkim
TemporaryDirectory      /var/tmp" > /etc/opendkim.conf
#生成dkim密钥对
opendkim-genkey -D /etc/opendkim/keys/ -d $domain -s default
#给opendkim用户访问keys目录的权限
chown -R opendkim: /etc/opendkim/keys/
echo "default._domainkey.$domain $domain:default:/etc/opendkim/keys/default.private" >> /etc/opendkim/KeyTable 
echo "*@$domain default._domainkey.$domain" >> /etc/opendkim/SigningTable
echo "$domain"  >> /etc/opendkim/TrustedHosts
echo "default._demainkey:";cat /etc/opendkim/keys/default.txt |awk -F '"|=' 'NR==2 {print $3}' || echo "dkim公钥文件不存在"
systemctl restart opendkim
systemctl enable opendkim
}

setup_ssh() {
echo "Port 34589" >> /etc/ssh/sshd_config && sed -i 's/#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
useradd $domain && echo $domain | passwd $domain --stdin && chmod +w /etc/sudoers && echo "$domain ALL=(ALL)NOPASSWD:ALL" >> /etc/sudoers
chmod -w /etc/sudoers  && /usr/bin/systemctl restart sshd.service
ss -p | grep sshd
if [ -f /home/$1/.bashrc ]
then
    echo 'sudo su - root' >> /home/$1/.bashrc
fi
}

setup_selinux() {
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
echo selinux status:`getenforce`
}

cat <<EOF > /root/check_mail.sh
#!bin/bash
echo '发信测试:'
echo 'This is a test mail!' | mail -s '邮件测试中...' ddzhiwenwei@163.com
sleep 3
echo '邮件总数:'\`cat /var/log/maillog | grep 'DKIM-Signature field added'|wc -l\`
echo '发信成功数:'\`cat /var/log/maillog |grep 'status=sent'|wc -l\`
tail -n 10 /var/log/maillog|grep 'OK'
EOF

setup_postfix
#setup_opendkim
setup_ssh
setup_selinux
setup_firewalld
setup_cyrus-sasl

bash /root/check_mail.sh

