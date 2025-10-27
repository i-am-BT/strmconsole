#!/bin/bash

# ���ɶ�̬�����ļ�
cat > /var/www/html/config.php << EOF
<?php
// config.php - ��̬��������
\$config = array(
    'username' => '${STRM_CONSOLE_USERNAME:-admin}',
    'password' => '${STRM_CONSOLE_PASSWORD:-password123}',
    'session_timeout' => 3600,
    
    // ·������
    'script_path' => '/var/www/html/scripts/',
    'log_path' => '/var/log/strm_console/',
    'task_path' => '/var/www/html/tasks/',
    
    // ϵͳ·��
    'cd2_mount' => '/docker/clouddrive/shared/CloudDrive',
    'strm_root' => '/var/strm_files',
    'docker_logs' => '/var/log/strm_console/'
);

return \$config;
?>
EOF

# ����Ȩ��
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 777 /var/www/html/tasks
chmod -R 777 /var/log/strm_console
chmod -R 777 /var/strm_files

# ��������
echo "���� PHP-FPM..."
php-fpm -D

echo "���� Nginx..."
nginx -g "daemon off;"