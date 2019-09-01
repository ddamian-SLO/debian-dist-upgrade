/root/upgrades:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
    - recurse:
      - user
      - group
      - mode

/root/upgrades/log:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
    - recurse:
      - user
      - group
      - mode

upgrade_scripts:
  file.managed:
    - user: root
    - group: root
    - mode: '0755'
    - names:
      - /root/upgrades/dist_upgrade.sh:
        - source: salt://debian/scripts/dist_upgrade.sh
      - /root/upgrades/php7_fpm_convert.sh:
        - source: salt://debian/scripts/php7_fpm_convert.sh