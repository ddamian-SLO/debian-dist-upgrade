apache-security-server-sig-conf:
  file.replace:
    - name: /etc/apache2/conf-available/security.conf
    - pattern: 'ServerSignature On'
    - repl: 'ServerSignature Off'
    - show_changes: true
    - require:
      - pkg: apache2

apache-security-server-token-conf:
  file.replace:
    - name: /etc/apache2/conf-available/security.conf
    - pattern: 'ServerTokens OS'
    - repl: 'ServerTokens Prod'
    - show_changes: True
    - require:
      - pkg: apache2

apache-enable-mods:
  apache_module.enabled:
    - names:
      - access_compat
      - actions
      - alias
      - auth_basic
      - authn_core
      - authn_file
      - authz_core
      - authz_host
      - authz_user
      - autoindex
      - deflate
      - dir
      - env
      - filter
      - mime
      - mpm_event
      - negotiation
      - proxy
      - proxy_fcgi
      - rewrite
      - setenvif
      - socache_shmcb
      - ssl
      - status
      - suexec

apache-deprecated-mods:
  apache_module.disabled:
    - names:
      - authz_default
      - mpm_prefork
      - php7.0
      - php7.0-fpm
      - fcgid
      - serve-cgi-bin