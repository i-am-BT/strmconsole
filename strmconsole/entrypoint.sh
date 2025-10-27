#!/bin/bash

# 生成动态配置文件
cat > /var/www/html/config.php << EOF
<?php
// config.php - 动态生成配置
\$config = array(
    'username' => '${STRM_CONSOLE_USERNAME:-admin}',
    'password' => '${STRM_CONSOLE_PASSWORD:-password123}',
    'session_timeout' => 3600,
    
    // 路径配置
    'script_path' => '/var/www/html/scripts/',
    'log_path' => '/var/log/strm_console/',
    'task_path' => '/var/www/html/tasks/',
    
    // 系统路径
    'cd2_mount' => '/docker/clouddrive/shared/CloudDrive',
    'strm_root' => '/var/strm_files',
    'docker_logs' => '/var/log/strm_console/'
);

return \$config;
?>
EOF

# 设置权限
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 777 /var/www/html/tasks
chmod -R 777 /var/log/strm_console
chmod -R 777 /var/strm_files

# 启动服务
echo "启动 PHP-FPM..."
php-fpm -D

echo "启动 Nginx..."
nginx -g "daemon off;"