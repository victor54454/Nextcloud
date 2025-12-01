# Configuration OnlyOffice pour Nextcloud

## Prérequis

- Nextcloud installé et fonctionnel
- OnlyOffice DocumentServer déployé via Docker

## Installation et configuration

### Création du certificat SSL a mettre dans le dossier ssl/ 
```bash 
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./ssl/nextcloud.key \
  -out ./ssl/nextcloud.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=HomeServer/CN=nextcloud.local"
```

### 1. Récupérer le secret JWT d'OnlyOffice
```bash
docker exec nextcloud-onlyoffice  /var/www/onlyoffice/documentserver/npm/json -f /etc/onlyoffice/documentserver/local.json 'services.CoAuthoring.secret.session.string'
```

**Note :** Conservez ce secret pour l'étape 4.

### 2. Installer l'application OnlyOffice dans Nextcloud
```bash
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:install onlyoffice"
```

### 3. Configurer l'URL du serveur OnlyOffice
```bash
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice DocumentServerUrl --value='http://documentserver/'"
```

### 4. Configurer le secret JWT
```bash
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice jwt_secret --value='super-secret-jwt-2024-change-me'"
```

> ⚠️ **Important :** Remplacez `super-secret-jwt-2024-change-me` par le secret récupéré à l'étape 1.

### 5. Activer OnlyOffice comme éditeur par défaut
```bash
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice defFormats --value='{\"docx\":true,\"xlsx\":true,\"pptx\":true}'"
```
### 6. Activer Draw.io 
```bash 
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:install drawio"
```


## Erreur possible après l'exécution de ces commandes :
![alt text](/photo/image.png)
![alt text](/photo/image-1.png)

### Explication de l'erreur d'intégrité : 
Les erreurs d'intégrité qu'on vois sont normal. Voici pourquoi :

OnlyOffice et Draw.io modifient légitimement mimetypelist.js pour ajouter leurs types de fichiers supportés (.docx, .xlsx, .pptx, .drawio, etc.)
Les fichiers SVG (drawio.svg, dwb.svg) sont des icônes ajoutées par l'app Draw.io

C'est le comportement standard de ces applications officielles.
### Comment voir les versions de nos logiciels installés : 
``` bash 
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:list --output=json" | jq '.enabled'
```

#### Modifications légitimes attendues
- `core/js/mimetypelist.js` : Modifié par OnlyOffice + Draw.io
- `core/img/filetypes/drawio.svg` : Icône Draw.io
- `core/img/filetypes/dwb.svg` : Icône Draw.io

#### Apps installées modifiant les fichiers core
- onlyoffice v9.8.0
- drawio v3.0.9

Date dernière vérification : 25 nov 2025

## Ajout du LDAPS en invite de commande : 
```bash 
SUPPRIMER UNE CONF LDAPS
# Supprime la config s01
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:delete-config s01"

# Vide le cache
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:invalidate-cache"

# Vérifie qu'il ne reste rien
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:show-config"

NEWS CONFIG 

# Crée une nouvelle config
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:create-empty-config"

# Configure le serveur LDAPS
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapHost 'ldaps://192.168.10.28'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapPort 636"

# Credentials du compte de service
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapAgentName 'CN=svc_nextcloud,CN=Users,DC=lab,DC=local'"
LDAP_PASSWORD='NextCloud@2024!Service'
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapAgentPassword '$LDAP_PASSWORD'"

# Base DN
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapBase 'DC=lab,DC=local'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapBaseUsers 'DC=lab,DC=local'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapBaseGroups 'DC=lab,DC=local'"

# Désactive la vérification SSL
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 turnOffCertCheck 1"

# Filtres (version PROPRE et SIMPLE)
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapUserFilter '(&(objectClass=user)(sAMAccountName=*)(!(objectClass=computer))(!(sAMAccountName=krbtgt)))'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapLoginFilter '(&(objectClass=user)(sAMAccountName=%uid))'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapGroupFilter '(objectClass=group)'"

# Attributs de mapping
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapExpertUsernameAttr 'sAMAccountName'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapUserDisplayName 'displayName'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapEmailAttribute 'mail'"
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapGroupDisplayName 'cn'"

# Active la configuration
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapConfigurationActive 1"

TEST 
# Teste la connexion
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:test-config s01"

# Recherche tous les utilisateurs
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:search ''"

# Liste les utilisateurs dans Nextcloud
docker exec nextcloud su -s /bin/sh www-data -c "php occ user:list"
```

## Synchro des groupes crée dans l'AD : 
![alt text](/photo/image3.png)

Comme on peut le voir sur la photo les groupes que j'ai crée dans l'AD sont remonter dans mon NextCloud. 
Pour se faire il faut intervenir sur un container en particulier sui est le container NextCloud : 
```bash 
# Configure l'attribut de membership des groupes (pour Active Directory)
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapGroupMemberAssocAttr 'member'"

# Active la nested groups (groupes imbriqués) si tu en as
docker exec nextcloud su -s /bin/sh www-data -c "php occ ldap:set-config s01 ldapNestedGroups 1"

# Force une synchro
docker exec nextcloud su -s /bin/sh www-data -c "php occ group:list"
```

## Gestion de sécuritée sur la création des users dans le NextCloud : 
```bash
# Désactive le backend de base de données (comptes locaux)
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set user_ldap disable_db_backend --value=1"
```

## Gestion des paramètres du serveur ONLYOFFICE : 
Dans cette partie nous allons configurais cette partie du serveur NextCloud : 
![alt text](/photo/image4.png)
Nous allons voir comment cela peut ce configurais directement depuis l'invite de commande : 
```bash 
# Adresse publique OnlyOffice (HTTPS)
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice DocumentServerUrl --value='https://nextcloud.local/onlyoffice/'"

# Adresse interne OnlyOffice
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice DocumentServerInternalUrl --value='http://documentserver/'"

# Adresse serveur pour OnlyOffice (callback)
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice StorageUrl --value='http://nginx/'"

# JWT Secret
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice jwt_secret --value='super-secret-jwt-2024-change-me'"

# JWT Header
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice jwt_header --value='Authorization'"

# Désactiver vérification SSL
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:app:set onlyoffice verify_peer_off --value='true'"

# Vérifier la config
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:list onlyoffice"
```
> ⚠️ **Important :** À noter, il faut prendre en compte que le nextcloud que j'ai monté et monté avec un certificat autosignée donc ce paramétrage permet de le faire fonctionner en ayant ce certificat. Sachant qu'avec un vrai certificat qui est valide nous allons rencontrer beaucoup moins de problèmes voire aucun, comme nextCloud n'aime pas forcément les certificats autosignés. 

## Information : 
Si on veut ajouter des application comme LDAP ou le groupe folder pour faire des dossier partager avec des groupes ou des users il faut ce rendre ici : 
![alt text](/photo/image5.png)
 
![alt text](/photo/image6.png)

Il faut cliqué sur **Applications** une fois ici il faut aller : Dans **Pack d'applications** et la vous pourrais trouver bon nombre d'option comme celle citée plus haut. 


## Installation de l'application S3 dans NextCloud :
```bash
# Installe l'app files_external (stockage externe)
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:install files_external"
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:enable files_external" 
```

### Création des certificats auto signée : 
```bash 
# Crée les certificats
openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout ~/travail/Nextcloud/minio-certs/certs/private.key \
  -out ~/travail/Nextcloud/minio-certs/certs/public.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=EntrepriseXYZ/CN=minio" \
  -addext "subjectAltName=DNS:minio,DNS:localhost,IP:127.0.0.1"

# Permissions
chmod 600 ~/travail/Nextcloud/minio-certs/certs/private.key
chmod 644 ~/travail/Nextcloud/minio-certs/certs/public.crt
```
### Création du Bucket dans Minio
Configure l'alias 
```bash 
docker exec minio mc alias set myminio https://localhost:9000 minioadmin minioadmin_secure_2024 --insecure
```
Crée le bucket
```bash 
docker exec minio mc mb myminio/nextcloud --ignore-existing --insecure
```
Rend le bucket privé
```bash 
docker exec minio mc anonymous set none myminio/nextcloud --insecure
```
Crée l'utilisateur service
```bash 
docker exec minio mc admin user add myminio nextcloud-service NextcloudMinIOSecure2024 --insecure
```
Crée la policy
```bash 
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
```
Applique la policy
```bash 
docker exec minio mc admin policy create myminio nextcloud-policy /tmp/nextcloud-policy.json --insecure
```
Attache la policy à l'utilisateur
```bash 
docker exec minio mc admin policy attach myminio nextcloud-policy --user=nextcloud-service --insecure
```
✅ VÉRIFIE QUE TOUT EST OK
```bash 
docker exec minio mc admin user info myminio nextcloud-service --insecure
```

## Configuration de Nextcloud avec Minio 
```bash
# 1. Copie le certificat MinIO dans Nextcloud
docker cp ~/travail/Nextcloud/minio-certs/certs/public.crt nextcloud:/usr/local/share/ca-certificates/minio.crt

# 2. Update les certificats CA
docker exec nextcloud update-ca-certificates

# 3. Mode maintenance
docker exec nextcloud su -s /bin/sh www-data -c "php occ maintenance:mode --on"

# 4. Configure objectstore
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

# 5. Redémarre Nextcloud
docker restart nextcloud
sleep 30

# 6. Désactive maintenance
docker exec nextcloud su -s /bin/sh www-data -c "php occ maintenance:mode --off"

# 7. ✅ VÉRIFIE la config
docker exec nextcloud su -s /bin/sh www-data -c "php occ config:list system" | grep -A20 objectstore 
```

## Vérification

### Via l'interface web

1. Connectez-vous à Nextcloud
2. Allez dans **Paramètres → Administration → ONLYOFFICE**
3. Vérifiez que le message **"Document server is available"** s'affiche en vert ✅

### Via la création de documents

1. Dans l'interface Nextcloud, cliquez sur **"+ Nouveau"**
2. Vous devriez voir les options :
   - 📄 Document
   - 📊 Feuille de calcul
   - 📽️ Présentation

## Dépannage

### Le serveur OnlyOffice n'est pas accessible

Vérifiez que le conteneur documentserver est démarré :
```bash
docker ps | grep documentserver
```

### Erreur de connexion JWT

Assurez-vous que le secret JWT est identique dans :
- Le fichier `docker-compose.yml` (variable `JWT_SECRET`)
- La configuration Nextcloud (étape 4)

### Logs OnlyOffice

Consultez les logs du serveur documentserver :
```bash
docker logs nextcloud
```