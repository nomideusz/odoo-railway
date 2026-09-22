# Pinned: odoo:19.0 moves with every nightly build, and a silent rebase can
# break every deploy of this template at once. Bump deliberately.
FROM odoo:19.0-20260908

# Prefork mode serves websockets from a separate gevent port; Caddy puts both
# behind the single port Railway routes to.
COPY --from=caddy:2.11.4 /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY --chmod=0755 railway-entrypoint.sh /railway-entrypoint.sh
COPY --chmod=0755 odoo-backup /usr/local/bin/odoo-backup

# Starts as root only to chown the Railway volume, then drops to the odoo user.
USER root
ENTRYPOINT ["/railway-entrypoint.sh"]
