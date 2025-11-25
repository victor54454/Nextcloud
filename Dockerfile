FROM nextcloud:29-fpm-alpine

# Copier le certificat LDAP
COPY ./ldap-cert.cer /usr/local/share/ca-certificates/ad-ldap.crt

# Installer le certificat et ldap-utils
RUN apk add --no-cache openldap-clients curl ca-certificates && \
    update-ca-certificates

# Copier le script d'entrypoint personnalisé
COPY entrypoint-custom.sh /usr/local/bin/entrypoint-custom.sh
RUN chmod +x /usr/local/bin/entrypoint-custom.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-custom.sh"]