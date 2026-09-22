# Deploy and Host Odoo 19 on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/odoo-19?utm_medium=integration&utm_source=button&utm_campaign=odoo-19)

[Odoo](https://www.odoo.com/) is the open-source business suite: CRM, sales, invoicing and accounting, inventory, purchasing, manufacturing, projects, HR, website and eCommerce — dozens of apps that share one database, so a quote becomes an order, a delivery and an invoice without re-typing anything. This template runs Odoo 19 Community set up the way Odoo's own deployment guide recommends, with nightly backups included.

## About Hosting Odoo 19

The stack is three pieces: Odoo, a private Postgres, and a Railway bucket for backups.

- **Production mode, not the dev server.** Odoo runs with prefork workers (2 HTTP workers, a cron worker and the websocket worker) behind Caddy, with gzip and the memory/time limits from Odoo's deployment docs. Live chat and notifications work over websockets out of the box.
- **Locked down from the first second.** The database is created on first boot with a generated `admin` password — never `admin`/`admin`. The database manager (`/web/database/manager`), which lets anyone with the master password download or drop your data, is switched off, and the master password is generated too. The session cookie is `Secure` with HSTS on, as in Odoo's nginx example. Postgres has no public proxy.
- **Nightly backups.** Every night at 03:00 UTC the database and filestore go to the bundled bucket as the same `.zip` Odoo's database manager makes, one per weekday, so the last 7 days are always there.
- **Initialized once.** The database is built on the first boot only; redeploys and restarts never re-run module data over your changes.

## Common Use Cases

- CRM and sales pipeline, quotes, and invoicing for a small business — no per-user fees
- Inventory, purchasing, and manufacturing for a shop or a small factory
- A self-hosted ERP to try Odoo apps before committing, with real backups from day one

## Dependencies for Odoo 19 Hosting

- PostgreSQL 17 (included, private network only)
- A Railway bucket for backups (included)

### Deployment Dependencies

- [Odoo 19 documentation](https://www.odoo.com/documentation/19.0/)
- [Template source on GitHub](https://github.com/nomideusz/odoo-railway)

### Implementation Details

**Sign in** at your Odoo service's Railway domain with login `admin` and the `ODOO_ADMIN_PASSWORD` value from the Odoo service's Variables tab. The first boot builds the database, so give it a minute or two. Change the password in Odoo afterwards; the variable is only read on first boot. Before installing Invoicing or Accounting, set your company's country (Settings → Companies) so Odoo loads your country's chart of accounts and taxes.

**Memory.** Around 500 MB with a handful of apps in use. On plans that give a service less than 1 GB, the template switches to single-process mode by itself (about 320 MB). For more users, set `ODOO_WORKERS` higher (roughly 1 worker per 6 concurrent users).

**Backups and restore.** Backups appear in the Backups bucket as `odoo-Mon.zip` … `odoo-Sun.zip`. For an extra one before a risky change, run `odoo-backup` in a `railway ssh` session on the Odoo service. To restore:

1. Download the zip from the bucket.
2. Set `ODOO_DB_MANAGER=true` on the Odoo service and redeploy.
3. Open `/web/database/manager`, delete the `odoo` database, then restore the zip as `odoo`, using `ODOO_MASTER_PASSWORD`.
4. Set `ODOO_DB_MANAGER=false` again and redeploy.

**Email.** Railway only allows outbound SMTP on the Pro plan, and Odoo sends mail over SMTP. On Pro, add your provider under Settings → Technical → Outgoing Mail Servers. On other plans Odoo can't send email, so set new users' passwords yourself (Settings → Users) instead of emailing invitations.

**Custom domain.** Add it in the Odoo service's Settings → Networking. Odoo updates its base URL the next time an admin logs in through the new domain.

**Custom modules.** Put them in `/var/lib/odoo/addons/19.0` on the volume; Odoo loads that folder automatically.

## Why Deploy Odoo 19 on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Odoo 19 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
