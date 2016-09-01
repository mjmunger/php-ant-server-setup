#!/bin/bash

#Complete operations for the following users (in the array)
#USER=( foouser baruser thirduser)
USER=( timing ) 

#Get the command line arg and store it in opt
getopts "ck" opt

#FUNCTIONS DEFINED HERE

check_global_servername() {
	echo -n "Checking to make sure ServerName has been set globally to supress the error message..."
	TEST=`cat /etc/apache2/apache2.conf | grep ^ServerName`
	EXISTS=${#TEST}
	if [ ${EXISTS} -gt 0 ]; then
		echo "[OK]"
	else 
		echo "[FAILED]"
		echo "You must set the ServerName directive in /etc/apache/apache.conf to continue. See: https://www.highpoweredhelp.com/codex/index.php/BFW_Toolkit#Configuring_Apache"
		exit 1
	fi	
}

check_apache_config_failures() {
	echo -n "Checking for $1..."
	TEST=`apache2ctl -M | grep $1`
	EXISTS=${#TEST}
	if [ ${EXISTS} -gt 0 ]; then
		echo "[FAILED]"
		echo "You have an error ($1). Run apache2ctl -M and correct all errors."
		exit 1
		else
		echo "[OK]"
	fi
}

check_apache_config() {
	echo -n "Checking for $1..."
	TEST=`apache2ctl -M | grep $1`
		EXISTS=${#TEST}
	if [ ${EXISTS} -gt 0 ]; then
		echo "[OK]"
		else
		echo "[FAILED]"
		echo "You need to install and enable the following module: $1. Try: $2"
		exit 1
	fi
}

check_dependency() {
	echo -n "Checking for $1..."
	TEST=`which $1`
	EXISTS=${#TEST}
	if [ ${EXISTS} -gt 0 ]; then
		echo "[OK]"
		else
		echo "[FAILED]"
		echo "You need to install $1 before proceeding."
		exit 1
	fi
}

setupUser() {
	PASS=`pwgen -cns 12 1`
	echo "Setting up user: $1"
	useradd -m $1
	usermod -s /bin/bash $1

	echo "Setting password to: $PASS"
	echo "$1:$PASS" | chpasswd

	echo "Saving information to setup.log"
	echo $1 : $PASS >> setup.log

	cd /home/$1
	echo "Checking out bfw into document root..."
	svn co svn://svn.highpoweredhelp.com/bfw www

	echo "Making SSL and Log directories..."
	mkdir ssl
	mkdir log

	cd /home/
	chown -R $1:$1 /home/$1/
}

setupApache() {
	INSTALLPATH=`pwd`

	echo "What domain will be installed for user $1?"
	read DOMAIN
	echo "What IP address will SSL use for this user?"
	read SSLIP

	echo "Generating CSR..."
	cd /home/$1/ssl
	openssl req -new -newkey rsa:2048 -nodes -keyout $DOMAIN.key -out $DOMAIN.csr	

	cd $INSTALLPATH
	./setup-apache.py $1 $DOMAIN $SSLIP
}

killUser() {
	echo "Removing user: $1"
	userdel $1
	echo "Removing user profile and directories"
	rm -vfr /home/$1
}

usage() {
	echo "Usage: setup.sh [-c | -k], where:"
	echo "     -c     Create accounts"
	echo "     -k     Delete and remove all accounts"
	echo ""
}

#END FUCNTIONS

#ENVIRONMENT CHECKS
if [ $(whoami) != "root" ]; then
echo "$0 should be run as root! You're not root. Magic 8 ball says: RTFM."
usage
fi

##SERVER NAME CHECK
check_global_servername
##END SERVER NAME CHECK

## APACHE CONFIG FAILURE CHECKS
check_apache_config_failures AH00558
## END APACHE CONFIG FAILURE CHECKS

## APP CHECKS ##

check_dependency pwgen

## END APP CHECKS ##


##APACHE MODULE CHECKS
check_apache_config ssl_module "a2enmod ssl"
check_apache_config rewrite_module "a2enmod rewrite"
check_apache_config mpm_itk_module " a2enmod mpm_itk, and if that fails, try: apt-get install apache2-mpm-itk"
##END APACHE MODULE CHECKS

echo ""
if [ $# -eq 0 ]; then
	echo "Oops. Perhaps you didn't RTFM? https://www.highpoweredhelp.com/codex/index.php/BFW_Toolkit"
	usage
fi


#END ENVIRONMENT CHECKS

#PERFORM OPERATIONS

for u in ${USER[@]}
do
	case $opt in
		c)
			echo "Running setupUser() for $u"
			setupUser $u
			setupApache $u
			;;
		k)
			killUser $u
			;;
		\?)
			usage
			;;
	esac
done

echo "Operation complete."
echo ""
echo "Your CSR is located in the SSL directory for each user created. Get that signed by a CA, and put the certificate (and relevant files) in that same directory, then confirm the site configuration for Apache is valid. Once you've done that, restart / reload the Apache web server, and everything will be up and running!"