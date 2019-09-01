include:
  - debian.states.pre-upgrade

dist-upgrade:
  cmd.run: 
    - name: /root/upgrades/php7_fpm_convert.sh
    - cwd: /root/upgrades