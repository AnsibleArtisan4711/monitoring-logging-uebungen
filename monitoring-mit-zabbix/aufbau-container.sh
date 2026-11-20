#!/usr/bin/env bash
# Aufbau der Testumgebung im Cloud-Container (Ubuntu 24.04, root). Ubuntu hat keine Zabbix-Pakete; Zabbix 7.0.32 wurde aus dem Quellcode gebaut.
# Diese Datei fasst die tatsächlich ausgeführten Schritte zusammen. Sie wurde NICHT als Ganzes erneut ausgeführt (der Bau dauert mehrere Minuten).
# Im Hyper-V-Labor wird stattdessen aus den Paketen von zabbix.com installiert (Modul 2, Schritt 7; Paketnamen nicht bestätigt).
set -e
apt-get install -y postgresql postgresql-client libpq-dev libpcre2-dev libevent-dev libssl-dev libxml2-dev libcurl4-openssl-dev libsnmp-dev \
  libsqlite3-dev libgnutls28-dev gettext php-cli php-pgsql php-bcmath php-mbstring php-gd php-xml php-curl php-ldap snmp snmpd
mkdir -p /opt/zbx && cd /opt/zbx
git clone --depth 1 --branch 7.0.32 https://github.com/zabbix/zabbix.git src
cd src && ./bootstrap.sh
./configure --prefix=/opt/zbx/inst --enable-server --enable-agent --with-postgresql --with-net-snmp --with-libcurl --with-libxml2 --with-openssl --with-libpcre2
make -j2 && make install && make dbschema
# eigener PostgreSQL-Cluster (Port 15432, Anmeldung "trust"), Datenbank-Vorlage zbx_base mit Schema und Grunddaten
PGB=/usr/lib/postgresql/16/bin; install -d -o postgres -g postgres /opt/zbx/pg
su postgres -c "$PGB/initdb -D /opt/zbx/pg/data -A trust -E UTF8 --locale=C.UTF-8"
su postgres -c "$PGB/pg_ctl -D /opt/zbx/pg/data -o '-p 15432 -c listen_addresses=127.0.0.1 -c unix_socket_directories=/tmp' -l /opt/zbx/pg/pg.log -w start"
su postgres -c "psql -h 127.0.0.1 -p 15432 -c \"CREATE USER zabbix PASSWORD 'uebung-zbx'\" -c \"CREATE DATABASE zbx_base OWNER zabbix ENCODING 'UTF8' TEMPLATE template0\""
for f in schema.sql images.sql data.sql; do PGPASSWORD=uebung-zbx psql -q -h 127.0.0.1 -p 15432 -U zabbix -d zbx_base -v ON_ERROR_STOP=1 -f /opt/zbx/src/database/postgresql/$f; done
useradd -r -s /usr/sbin/nologin zabbix
cp -r /opt/zbx/src/ui /opt/zbx/ui     # Frontend; die Konfigurationsdatei conf/zabbix.conf.php schreibt lab.sh bei jedem Start
