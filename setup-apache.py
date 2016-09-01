#!/usr/bin/env python
import sys,os


#Get username from the command line
user=sys.argv[1]

#Get domain name from the command line
domain=sys.argv[2]

#Get SSL IP from the command line
sslip = sys.argv[3]

# Setup find and replace values.
findAndReplace = [
                  ['%USERNAME%'    ,user]
                 ,['%SHORTDOMAIN%' ,domain]
                 ,['%SSLIP%'       ,sslip]
                 ]

with open('apache.conf', 'r') as content_file:
    content = content_file.read()

for find,repl in findAndReplace:
    content = content.replace(find,repl)

f = open('/etc/apache2/sites-available' + domain + ".conf",'w')
f.write(content)
f.close()