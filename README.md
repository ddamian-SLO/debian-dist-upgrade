# Debian Distro Upgrade 

This is a collection of salt states/beacons/reactors and scripts used to automate the dist upgrade process. The dist upgrade process is relatively simple, but for relatively older systems, many applications can break during this process. These states and reactors aim to fix this.

These states and scripts do the following:
* Upgrade a distro from as old as Debian 7 to the latest stable release (currently Debian 10).
* Fix various configuration files for typical LAMP stack servers. 
* Keep old configuration files in use to prevent overwrite of custom definitions. Have separate Salt states overwrite these with proper files if configuration errors persist. 
* Convert old way of defining vhosts in /etc/apache2/conf.d/<conffile>.conf and move them to sites-available. Environments that I've seen have typically used /etc/apache2/conf.d/vhosts.conf and vhosts-ssl.conf
* Reconfigure Apache2 to use PHP-FPM (like nginx). 
* Generate FPM configurations based off of enabled sites (/etc/apache2/sites-enabled/*.conf)
* Update mysql 5.1/5.5 cnf definitions to MariaDB 10.1+ definitions.
* Run the mysql_upgrade shell script to fix schema post upgrade. 

All in all, this is mostly used to upgrade legacy tech debt that's been left to build up over the years.