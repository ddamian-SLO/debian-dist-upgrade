include: 
  - debian.states.php-fpm.pkg

php-fpm-convert:
  cmd.run:
    - name: /root/upgrades/php7_fpm_convert.sh
    - cwd: /root/upgrades