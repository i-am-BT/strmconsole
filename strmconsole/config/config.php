<?php
// config.php - ��̬���ý���entrypoint.sh����
$config = array(
    'username' => '{{USERNAME}}',
    'password' => '{{PASSWORD}}',
    'session_timeout' => 3600,
    
    // ·������
    'script_path' => '/var/www/html/scripts/',
    'log_path' => '/var/log/strm_console/',
    'task_path' => '/var/www/html/tasks/',
    
    // ϵͳ·�� - ��Щ����������ӳ��
    'cd2_mount' => '/docker/clouddrive/shared/CloudDrive',
    'strm_root' => '/var/strm_files',
    'docker_logs' => '/var/log/strm_console/'
);

return $config;
?>