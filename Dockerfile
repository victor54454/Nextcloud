FROM nextcloud:29-fpm-alpine

# CERTIFICAT LDAPS
COPY ./ldap-cert.cer /usr/local/share/ca-certificates/ad-ldap.crt
# CERTIFICAT
RUN apk add --no-cache openldap-clients curl ca-certificates && \
    update-ca-certificates

# SCRIPT
COPY entrypoint-custom.sh /usr/local/bin/entrypoint-custom.sh
RUN chmod +x /usr/local/bin/entrypoint-custom.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-custom.sh"]