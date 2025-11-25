<?php
$CONFIG = array (
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' => 
  array (
    0 => 
    array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 => 
    array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' => 
  array (
    'host' => 'redis',
    'password' => '',
    'port' => 6379,
  ),
  'upgrade.disable-web' => true,
  
  'instanceid' => 'oc68dr9iiw7h',
  'passwordsalt' => 'MhFOZCjYFEvAABjTAxI1h/7tO3CySL',
  'secret' => 'g416VjZhcMyK8Th/Yz/Eh7rQGKNG+Yca2KGQt+YCWKBDxS5B',
  
  'trusted_domains' => 
  array (
    0 => 'nextcloud.local',
    1 => 'localhost',
    2 => '127.0.0.1',
  ),
  
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'pgsql',
  'version' => '29.0.16.1',
  'dbname' => 'nextcloud',
  'dbhost' => 'db',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'dbuser' => 'oc_svc_nextcloud',
  'dbpassword' => '0zh84k9hMbcR2SGCCshcaGH9nZEzFt',
  'installed' => true,
  
  // CONFIGURATION HTTPS
  'overwrite.cli.url' => 'https://nextcloud.local',
  'overwriteprotocol' => 'https',
  'overwritehost' => 'nextcloud.local',
  'overwritecondaddr' => '^172\\.16\\..*$',  // ⬅️ LIGNE CRITIQUE
  'trusted_proxies' => array('172.16.0.0/12'),
  
  // CONFIGURATION RÉGIONALE
  'default_phone_region' => 'FR',
  'default_language' => 'fr',
  'default_locale' => 'fr_FR',
  'logtimezone' => 'Europe/Paris',
  
  'maintenance_window_start' => 1,
  
  'loglevel' => 2,
  'log_type' => 'file',
  'logfile' => '/var/www/html/data/nextcloud.log',
  'log_rotate_size' => 104857600,
  
  'filelocking.enabled' => true,
  'filesystem_check_changes' => 1,
  'updatechecker' => true,
  
  'auth.bruteforce.protection.enabled' => true,
  'ratelimit.protection.enabled' => true,
  
  'enable_previews' => true,
  'enabledPreviewProviders' => 
  array (
    0 => 'OC\\Preview\\PNG',
    1 => 'OC\\Preview\\JPEG',
    2 => 'OC\\Preview\\GIF',
    3 => 'OC\\Preview\\BMP',
    4 => 'OC\\Preview\\XBitmap',
    5 => 'OC\\Preview\\MP3',
    6 => 'OC\\Preview\\TXT',
    7 => 'OC\\Preview\\MarkDown',
    8 => 'OC\\Preview\\PDF',
  ),
  
  'max_chunk_size' => 10485760,
  'allow_local_remote_servers' => true,
  'mail_smtpmode' => 'smtp',
  'mail_sendmailmode' => 'smtp',
  
  'config_is_read_only' => true,
);