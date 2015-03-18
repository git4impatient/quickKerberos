#!/bin/bash
# (c) copyright 2014 martin lurie sample code not supported

# reminder to activate CM in the quickstart
echo Activate CM in the quickstart vmware image
echo Hit enter when you are ready to proceed
# pause until the user hits enter
read foo
# for debugging - set -x

# fix the permissions in the quickstart vm
# may not be an issue in later versions of the vm
# this fixes the following error
# failed to start File /etc/hadoop must not be world 
# or group writable, but is 775
# File /etc must not be world or group writable, but is 775
#
#  run this as root
#  to become root
#  sudo su - 
cd /root
chmod 755 /etc
chmod 755 /etc/hadoop

# install the kerberos components
yum install -y krb5-server
yum install -y openldap-clients
yum install -y krb5-workstation

# update the config files for the realm name and hostname
# in the quickstart VM
# notice the -i.xxx for sed will create an automatic backup
# of the file before making edits in place
# 
# set the Realm
sed -i.orig 's/EXAMPLE.COM/CLOUDERA/g' /etc/krb5.conf
# set the hostname for the kerberos server
sed -i.m1 's/kerberos.example.com/quickstart.cloudera/g' /etc/krb5.conf
# change domain name to cloudera 
sed -i.m2 's/example.com/cloudera/g' /etc/krb5.conf

# download UnlimitedJCEPolicyJDK7.zip from Oracle into
# the /root directory
# we will use this for full strength 256 bit encryption

mkdir jce
cd jce
unzip ../UnlimitedJCEPolicyJDK7.zip 
# save the original jar files
cp /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/local_policy.jar local_policy.jar.orig
cp /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/US_export_policy.jar US_export_policy.jar.orig

# copy the new jars into place
cp /root/jce/UnlimitedJCEPolicy/local_policy.jar /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/local_policy.jar
cp /root/jce/UnlimitedJCEPolicy/US_export_policy.jar /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/US_export_policy.jar

# now create the kerberos database
kdb5_util create -s

# type in cloudera at the password prompt
echo suggested password is cloudera 

# update the kdc.conf file
sed -i.orig 's/EXAMPLE.COM/CLOUDERA/g' /var/kerberos/krb5kdc/kdc.conf
# this will add a line to the file with ticket life
sed -i.m1 '/dict_file/a max_life = 1d' /var/kerberos/krb5kdc/kdc.conf
# add a max renewable life
sed -i.m2 '/dict_file/a max_renewable_life = 7d' /var/kerberos/krb5kdc/kdc.conf
# indent the two new lines in the file
sed -i.m3 's/^max_/  max_/' /var/kerberos/krb5kdc/kdc.conf

# the acl file needs to be updated so the */admin
# is enabled with admin privileges 
sed -i 's/EXAMPLE.COM/CLOUDERA/' /var/kerberos/krb5kdc/kadm5.acl

# The kerberos authorization tickets need to be renewable
# if not the Hue service will show bad (red) status
# and the Hue “Kerberos Ticket Renewer” will not start
# the error message in the log will look like this:
#  kt_renewer   ERROR    Couldn't renew # kerberos ticket in 
#  order to work around Kerberos 1.8.1 issue.
#  Please check that the ticket for 'hue/quickstart.cloudera' 
#  is still renewable

# update the kdc.conf file to allow renewable
sed -i.m3 '/supported_enctypes/a default_principal_flags = +renewable, +forwardable' /var/kerberos/krb5kdc/kdc.conf
# fix the indenting
sed -i.m4 's/^default_principal_flags/  default_principal_flags/' /var/kerberos/krb5kdc/kdc.conf

# start up the kdc server and the admin server
service krb5kdc start
service kadmin start

# There is an addition error message you may encounter
# this requires an update to the krbtgt principal

# 5:39:59 PM 	ERROR 	kt_renewer 	
#
#Couldn't renew kerberos ticket in order to work around 
# Kerberos 1.8.1 issue. Please check that the ticket 
# for 'hue/quickstart.cloudera' is still renewable:
#  $ kinit -f -c /tmp/hue_krb5_ccache
#If the 'renew until' date is the same as the 'valid starting' 
# date, the ticket cannot be renewed. Please check your 
# KDC configuration, and the ticket renewal policy 
# (maxrenewlife) for the 'hue/quickstart.cloudera' 
# and `krbtgt' principals.
#

kadmin.local <<eoj
modprinc -maxrenewlife 1week krbtgt/CLOUDERA@CLOUDERA
eoj
# now just add a few user principals 
#kadmin:  addprinc -pw <Password>
# cloudera-scm/admin@YOUR-LOCAL-REALM.COM

# add the admin user that CM will use to provision
# kerberos in the cluster
kadmin.local <<eoj
addprinc -pw cloudera cloudera-scm/admin@CLOUDERA
modprinc -maxrenewlife 1week cloudera-scm/admin@CLOUDERA
eoj

# add the hdfs principal so you have a superuser for hdfs
kadmin.local <<eoj
addprinc -pw cloudera hdfs@CLOUDERA
eoj

# add a cloudera principal  for the standard user 
# in the Cloudera Quickstart VM
kadmin.local <<eoj
addprinc -pw cloudera cloudera@CLOUDERA
eoj

# test the server by authenticating as the CM admin user
# enter the password cloudera when you are prompted
kinit cloudera-scm/admin@CLOUDERA

# once you have a valid ticket you can see the 
# characteristics of the ticket with klist -e
# you will see the encryption type which you will
# need for a screen in the wizard, for example
#  Etype (skey, tkt): aes256-cts-hmac-sha1-96
klist -e

# to see the contents of the files cat them
cat /var/kerberos/krb5kdc/kdc.conf
cat /var/kerberos/krb5kdc/kadm5.acl
cat /etc/krb5.conf

#The files will look like this:
