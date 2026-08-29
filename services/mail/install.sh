#!/bin/sh

set -eu

postconf=/usr/sbin/postconf
postfix=/usr/sbin/postfix

sudo "$postconf" -e 'myhostname = mail.maclong.dev'
sudo "$postconf" -e 'myorigin = $myhostname'
sudo "$postconf" -e 'inet_interfaces = loopback-only'
sudo "$postconf" -e 'inet_protocols = ipv4'
sudo "$postconf" -e 'mynetworks = 127.0.0.0/8, [::1]/128'
sudo "$postconf" -e 'relayhost ='
sudo "$postconf" -e 'smtp_generic_maps = hash:/etc/postfix/generic'
sudo "$postconf" -e 'smtp_tls_security_level = may'
sudo "$postconf" -e 'smtp_tls_CAfile = /etc/ssl/cert.pem'
sudo "$postconf" -e 'smtpd_client_restrictions = permit_mynetworks, reject'
sudo "$postconf" -e 'smtpd_relay_restrictions = permit_mynetworks, reject'
sudo "$postconf" -e 'disable_vrfy_command = yes'

sudo install -o root -g wheel -m 644 \
	/Users/mac/Developer/configuration/services/mail/generic /etc/postfix/generic
sudo /usr/sbin/postmap /etc/postfix/generic
sudo "$postfix" check

test "$(sudo "$postconf" -h myhostname)" = mail.maclong.dev
test "$(sudo "$postconf" -h inet_interfaces)" = loopback-only
test "$(sudo "$postconf" -h mynetworks)" = '127.0.0.0/8, [::1]/128'
test "$(sudo "$postconf" -h relayhost)" = ''

sudo launchctl enable system/com.apple.postfix.master
sudo launchctl kickstart -k system/com.apple.postfix.master

printf '%s\n' 'Postfix is ready for local, direct delivery.'
