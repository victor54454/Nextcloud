#!/bin/bash

set -e

echo "🚀 === CONFIGURATION AUTOMATIQUE NEXTCLOUD ==="

# ==========================================
# VÉRIFICATION CONTAINERS
# ==========================================
echo "🔍 Vérification que les containers sont démarrés..."

if ! docker ps | grep -q "nextcloud"; then
    echo "❌ Container nextcloud non trouvé"
    exit 1
fi

echo "✅ Containers OK"
echo ""

# ==========================================
# ATTENTE NEXTCLOUD PRÊT
# ==========================================
echo "⏳ Attente que Nextcloud soit prêt..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker exec nextcloud su -s /bin/sh www-data -c "php occ status" 2>/dev/null | grep -q "installed: true"; then
        echo "✅ Nextcloud est prêt !"
        break
    fi
    attempt=$((attempt + 1))
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Timeout: Nextcloud ne répond pas"
    exit 1
fi

echo ""

# ==========================================
# 1. INSTALLATION DES APPLICATIONS
# ==========================================
echo "Récupérer le secret JWT d'OnlyOffice"
docker exec nextcloud-onlyoffice  /var/www/onlyoffice/documentserver/npm/json -f /etc/onlyoffice/documentserver/local.json 'services.CoAuthoring.secret.session.string'

echo "Installer l'application OnlyOffice dans Nextcloud"
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:install onlyoffice" 2>/dev/null || true
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:enable onlyoffice"

echo "Configurer l'URL du serveur OnlyOffice"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice DocumentServerUrl --value='http://documentserver/'"

echo "Configurer le secret JWT"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice jwt_secret --value='super-secret-jwt-2024-change-me'"

echo "Activer OnlyOffice comme éditeur par défaut"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice defFormats --value='{\"docx\":true,\"xlsx\":true,\"pptx\":true}'"

echo "Activer Draw.io"
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:install drawio" 2>/dev/null || true
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:enable drawio"

echo "Activer LDAP/AD integration"
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:enable user_ldap"

echo "versions de nos logiciels installés"
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:list --output=json" | jq '.enabled'
sleep 3

# ==========================================
# 2. LDAPS
# ==========================================
echo "Crée une nouvelle config (ou utilise s01 si existe déjà)"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:create-empty-config" 2>/dev/null || echo "Config LDAP existe déjà, on continue..."

echo "Configure le serveur LDAPS"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapHost 'ldaps://192.168.10.76'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapPort 636"

echo "Credentials du compte de service"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapAgentName 'CN=svc_nextcloud,CN=Users,DC=lab,DC=local'"
LDAP_PASSWORD='NextCloud@2024!Service'
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapAgentPassword '$LDAP_PASSWORD'"

echo "Base DN"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapBase 'DC=lab,DC=local'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapBaseUsers 'DC=lab,DC=local'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapBaseGroups 'DC=lab,DC=local'"

echo "Désactive la vérification SSL"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 turnOffCertCheck 1"

echo "Filtres (version PROPRE et SIMPLE)"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapUserFilter '(&(objectClass=user)(sAMAccountName=*)(!(objectClass=computer))(!(sAMAccountName=krbtgt)))'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapLoginFilter '(&(objectClass=user)(sAMAccountName=%uid))'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapGroupFilter '(objectClass=group)'"

echo "Attributs de mapping"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapExpertUsernameAttr 'sAMAccountName'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapUserDisplayName 'displayName'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapEmailAttribute 'mail'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapGroupDisplayName 'cn'"

echo "Active la configuration"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapConfigurationActive 1"

echo "TEST" 
echo "Teste la connexion"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:test-config s01"

echo "Recherche tous les utilisateurs"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:search ''"

echo "Liste les utilisateurs dans Nextcloud"
docker exec nextcloud su -s /bin/sh www-data -c "php occ user:list"
sleep 3

# ==========================================
# 3. Synchro des groupes crée dans l'AD
# ==========================================
echo "Configure l'attribut de membership des groupes (pour Active Directory)"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapGroupMemberAssocAttr 'member'"

echo "Active la nested groups (groupes imbriqués) si tu en as"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapNestedGroups 1"

echo "Force une synchro"
docker exec nextcloud su -s /bin/sh www-data -c "php occ group:list"
sleep 3

# ================================================
# 4. Gestion des paramètres du serveur ONLYOFFICE
# ================================================
echo "Adresse publique OnlyOffice (HTTPS)"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice DocumentServerUrl --value='https://nextcloud.local/onlyoffice/'"

echo "Adresse interne OnlyOffice"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice DocumentServerInternalUrl --value='http://documentserver/'"

echo "Adresse serveur pour OnlyOffice (callback)"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice StorageUrl --value='http://nginx/'"

echo "JWT Secret"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice jwt_secret --value='super-secret-jwt-2024-change-me'"

echo "JWT Header"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice jwt_header --value='Authorization'"

echo "Désactiver vérification SSL"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice verify_peer_off --value='true'"

echo "Vérifier la config"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:list onlyoffice"
sleep 3

# ===================================================
# 5. Installation de l'application S3 dans NextCloud
# ===================================================
echo "Installe l'app files_external (stockage externe)"
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:install files_external" 2>/dev/null || true
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:enable files_external"

echo "🔍 Vérification que MinIO est accessible..."
if ! docker exec minio mc --help &>/dev/null; then
    echo "❌ MinIO n'est pas prêt"
    exit 1
fi

echo "Alias"
docker exec minio mc alias set myminio https://127.0.0.1:9000 minioadmin minioadmin_secure_2024 --insecure

echo "Crée le bucket"
docker exec minio mc mb myminio/nextcloud --ignore-existing --insecure

echo "Rend le bucket privé"
docker exec minio mc anonymous set none myminio/nextcloud --insecure

echo "Crée l'utilisateur service"
docker exec minio mc admin user add myminio nextcloud-service NextcloudMinIOSecure2024 --insecure

echo "Crée la policy"
docker exec minio sh -c "cat > /tmp/nextcloud-policy.json <<'EOF'
{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Action\": [\"s3:ListBucket\", \"s3:GetBucketLocation\", \"s3:ListBucketMultipartUploads\"],
      \"Resource\": [\"arn:aws:s3:::nextcloud\"]
    },
    {
      \"Effect\": \"Allow\",
      \"Action\": [\"s3:GetObject\", \"s3:PutObject\", \"s3:DeleteObject\", \"s3:ListMultipartUploadParts\", \"s3:AbortMultipartUpload\"],
      \"Resource\": [\"arn:aws:s3:::nextcloud/*\"]
    }
  ]
}
EOF"

echo "Applique la policy"
docker exec minio mc admin policy create myminio nextcloud-policy /tmp/nextcloud-policy.json --insecure

echo "Attache la policy à l'utilisateur"
docker exec minio mc admin policy attach myminio nextcloud-policy --user=nextcloud-service --insecure

echo "✅ VÉRIFIE QUE TOUT EST OK"
docker exec minio mc admin user info myminio nextcloud-service --insecure
sleep 3

# =========================================
# 6. Configuration de Nextcloud avec Minio
# =========================================
echo "Copie le certificat MinIO dans Nextcloud"
if [ ! -f ~/travail/Nextcloud/minio-certs/certs/public.crt ]; then
    echo "❌ Certificat MinIO introuvable !"
    exit 1
fi
docker cp ~/travail/Nextcloud/minio-certs/certs/public.crt nextcloud:/usr/local/share/ca-certificates/minio.crt

echo "Update les certificats CA"
docker exec nextcloud update-ca-certificates

echo "Mode maintenance"
docker exec nextcloud su -s /bin/sh www-data -c "php occ maintenance:mode --on"

echo "Configure objectstore"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:system:set objectstore class --value='\\OC\\Files\\ObjectStore\\S3'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:system:set objectstore arguments bucket --value='nextcloud'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:system:set objectstore arguments autocreate --value=false --type=boolean"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:system:set objectstore arguments key --value='nextcloud-service'"
docker exec nextcloud su -s /bin/sh www-data -c 'php occ config:system:set objectstore arguments secret --value="NextcloudMinIOSecure2024"'
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:system:set objectstore arguments hostname --value='minio'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:system:set objectstore arguments port --value=9000 --type=integer"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:system:set objectstore arguments use_ssl --value=true --type=boolean"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:system:set objectstore arguments region --value='us-east-1'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:system:set objectstore arguments use_path_style --value=true --type=boolean"

echo "Redémarre Nextcloud"
docker restart nextcloud
echo "⏳ Attente du redémarrage de Nextcloud..."
attempt=0
while [ $attempt -lt 30 ]; do
    if docker exec nextcloud su -s /bin/sh www-data -c "php occ status" 2>/dev/null | grep -q "installed: true"; then
        echo "✅ Nextcloud est de retour !"
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done

echo "Test Nextcloud"
docker ps | grep nextcloud
echo "Désactive maintenance"
docker exec nextcloud su -s /bin/sh www-data -c "php occ maintenance:mode --off"

echo "✅ VÉRIFIE la config"
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:list system" | grep -A20 objectstore 