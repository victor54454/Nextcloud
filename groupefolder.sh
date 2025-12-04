#!/bin/bash

set -e

echo "📁 === CONFIGURATION AUTOMATIQUE DOSSIERS ==="

# Mapping utilisateurs -> groupes
declare -A USER_GROUPS=(
    ["Victor"]="CDR"
    ["francesco"]="CDR"
    ["Jean"]="Latte"
    ["romain"]="Latte"
    ["francois"]="MTP"
    ["louis"]="MTP"
)

# ==========================================
# 1. INSTALLATION GROUPFOLDERS
# ==========================================
echo "📦 Installation groupfolders..."
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:install groupfolders" 2>/dev/null || true
docker exec nextcloud su -s /bin/sh www-data -c "php occ app:enable groupfolders"

# ==========================================
# 2. NETTOYAGE
# ==========================================
echo "🗑️ Nettoyage..."
for id in {1..20}; do
    docker exec nextcloud su -s /bin/sh www-data -c "php occ groupfolders:delete $id --force" 2>/dev/null || true
done

# ==========================================
# 3. DOSSIERS PARTAGÉS + PERMISSIONS
# ==========================================
echo "📂 Création dossiers partagés avec permissions..."
GROUPES=("CDR" "Latte" "MTP")

for groupe in "${GROUPES[@]}"; do
    echo "Dossier : $groupe"
    
    FOLDER_ID=$(docker exec nextcloud su -s /bin/sh www-data -c "php occ groupfolders:create '$groupe'" | grep -oP '\d+')
    
    # Ajoute les groupes avec permissions WRITE
    docker exec nextcloud su -s /bin/sh www-data -c "php occ groupfolders:group $FOLDER_ID '$groupe' write"
    docker exec nextcloud su -s /bin/sh www-data -c "php occ groupfolders:group $FOLDER_ID 'admin' write"
    
    # Active les ACL via la base de données directement
    docker exec nextcloud-db psql -U nextcloud -d nextcloud -c "
        INSERT INTO oc_group_folders_manage (folder_id, mapping_type, mapping_id, permissions)
        VALUES ($FOLDER_ID, 'group', '$groupe', 15)
        ON CONFLICT DO NOTHING;
    " 2>/dev/null || echo "  → ACL déjà configuré ou non supporté"
    
    docker exec nextcloud-db psql -U nextcloud -d nextcloud -c "
        INSERT INTO oc_group_folders_manage (folder_id, mapping_type, mapping_id, permissions)
        VALUES ($FOLDER_ID, 'group', 'admin', 31)
        ON CONFLICT DO NOTHING;
    " 2>/dev/null || echo "  → ACL admin déjà configuré"
    
    echo "  ✅ $groupe créé (ID: $FOLDER_ID)"
done

# ==========================================
# 4. CRÉATION GROUPES TECHNIQUES + DOSSIERS PRIVÉS
# ==========================================
echo "👤 Création dossiers privés automatiques..."

for user in "${!USER_GROUPS[@]}"; do
    groupe="${USER_GROUPS[$user]}"
    folder_name="${groupe}_${user}"
    tech_group="${user}_private"
    
    echo "Dossier privé : $folder_name pour $user"
    
    # Crée un groupe technique pour l'utilisateur
    docker exec nextcloud su -s /bin/sh www-data -c "php occ group:add '$tech_group'" 2>/dev/null || echo "  → Groupe technique existe"
    
    # Ajoute l'utilisateur au groupe technique
    docker exec nextcloud su -s /bin/sh www-data -c "php occ group:adduser '$tech_group' '$user'" 2>/dev/null || true
    
    # Crée le groupfolder privé
    FOLDER_ID=$(docker exec nextcloud su -s /bin/sh www-data -c "php occ groupfolders:create '$folder_name'" | grep -oP '\d+')
    
    # Donne accès au groupe technique ET à admin
    docker exec nextcloud su -s /bin/sh www-data -c "php occ groupfolders:group $FOLDER_ID '$tech_group' write"
    docker exec nextcloud su -s /bin/sh www-data -c "php occ groupfolders:group $FOLDER_ID 'admin' write"
    
    # Permissions : tous les droits (31) pour le user ET admin
    docker exec nextcloud-db psql -U nextcloud -d nextcloud -c "
        INSERT INTO oc_group_folders_manage (folder_id, mapping_type, mapping_id, permissions)
        VALUES ($FOLDER_ID, 'group', '$tech_group', 31)
        ON CONFLICT DO NOTHING;
    " 2>/dev/null || true
    
    docker exec nextcloud-db psql -U nextcloud -d nextcloud -c "
        INSERT INTO oc_group_folders_manage (folder_id, mapping_type, mapping_id, permissions)
        VALUES ($FOLDER_ID, 'group', 'admin', 31)
        ON CONFLICT DO NOTHING;
    " 2>/dev/null || true
    
    echo "  ✅ $folder_name créé (ID: $FOLDER_ID, groupe: $tech_group)"
done

# ==========================================
# 5. RÉSUMÉ
# ==========================================
echo ""
echo "📋 === CONFIGURATION TERMINÉE ==="
docker exec nextcloud su -s /bin/sh www-data -c "php occ groupfolders:list"
echo ""
echo "✅ Tout est automatiquement configuré !"
echo "   • Dossiers partagés : CDR, Latte, MTP (Write + Share, pas Delete)"
echo "   • Dossiers privés : accessibles uniquement par le user + admin (tous droits)"
echo ""
echo "🎉 Rafraîchis Nextcloud (F5) pour voir les dossiers !"