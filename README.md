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