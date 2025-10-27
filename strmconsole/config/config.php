<?php
// config.php - 动态配置将由entrypoint.sh生成
$config = array(
    'username' => '{{USERNAME}}',
    'password' => '{{PASSWORD}}',
    'session_timeout' => 3600,
    
    // 路径配置
    'script_path' => '/var/www/html/scripts/',
    'log_path' => '/var/log/strm_console/',
    'task_path' => '/var/www/html/tasks/',
    
    // 系统路径 - 这些将在容器内映射
    'cd2_mount' => '/docker/clouddrive/shared/CloudDrive',
    'strm_root' => '/var/strm_files',
    'docker_logs' => '/var/log/strm_console/'
);

return $config;
?>