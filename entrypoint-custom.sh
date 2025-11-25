#!/bin/sh
set -e

echo "🚀 Démarrage de Nextcloud FPM..."

# Lancer l'entrypoint original qui va installer automatiquement
/entrypoint.sh php-fpm &
FPM_PID=$!

# Attendre que Nextcloud soit installé
sleep 20

# Vérifier si installé
if su -s /bin/sh www-data -c "php /var/www/html/occ status" 2>/dev/null | grep -q "installed: true"; then
    echo "✅ Nextcloud installé!"
    
    # Appliquer les optimisations UNE SEULE FOIS
    if [ ! -f /var/www/html/data/.optimized ]; then
        echo "🔧 Application des optimisations..."
        
        # Configuration Redis
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set memcache.local --value='\\OC\\Memcache\\APCu'"
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set memcache.distributed --value='\\OC\\Memcache\\Redis'"
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set memcache.locking --value='\\OC\\Memcache\\Redis'"
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set redis host --value='redis'"
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set redis port --value=6379 --type=integer"
        
        # Configuration régionale
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set default_phone_region --value='FR'"
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set default_language --value='fr'"
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set default_locale --value='fr_FR'"
        
        # Configuration proxy
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set trusted_proxies 0 --value='172.16.0.0/12'"
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set overwritecondaddr --value='^172\\.16\\..*$'"
        
        # Maintenance
        su -s /bin/sh www-data -c "php /var/www/html/occ config:system:set maintenance_window_start --value=1 --type=integer"
        
        # Index
        echo "📊 Ajout des index..."
        su -s /bin/sh www-data -c "php /var/www/html/occ db:add-missing-indices" || true
        
        # Bigint
        su -s /bin/sh www-data -c "php /var/www/html/occ db:convert-filecache-bigint --no-interaction" || true
        
        # Marquer comme optimisé
        touch /var/www/html/data/.optimized
        echo "✅ Optimisations terminées!"
    else
        echo "ℹ️ Optimisations déjà appliquées"
    fi
else
    echo "⚠️ Nextcloud pas encore installé, les optimisations seront appliquées au prochain redémarrage"
fi

wait $FPM_PID