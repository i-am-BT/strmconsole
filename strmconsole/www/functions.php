<?php
// functions.php - 公共函数文件

/**
 * 检查用户登录状态
 */
function check_login() {
    // 包含配置文件
    $config_file = __DIR__ . '/config.php';
    if (!file_exists($config_file)) {
        header('Location: index.php');
        exit;
    }
    
    $config = include $config_file;
    if (!is_array($config)) {
        header('Location: index.php');
        exit;
    }
    
    // 启动会话（如果尚未启动）
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    
    // 检查是否已登录
    if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
        header('Location: index.php');
        exit;
    }
    
    // 检查会话超时
    if (isset($_SESSION['login_time']) && (time() - $_SESSION['login_time']) > $config['session_timeout']) {
        session_destroy();
        header('Location: index.php');
        exit;
    }
    
    // 更新最后活动时间
    $_SESSION['last_activity'] = time();
    
    return true;
}

/**
 * 记录操作日志
 */
function log_operation($action) {
    $config_file = __DIR__ . '/config.php';
    if (!file_exists($config_file)) {
        return false;
    }
    
    $config = include $config_file;
    if (!is_array($config) || !isset($config['log_path'])) {
        return false;
    }
    
    $log_file = $config['log_path'] . 'operations.log';
    $username = $_SESSION['username'] ?? 'unknown';
    $message = date('Y-m-d H:i:s') . " - " . $username . " - " . $action . "\n";
    
    return file_put_contents($log_file, $message, FILE_APPEND | LOCK_EX);
}

/**
 * 获取配置
 */
function get_config() {
    $config_file = __DIR__ . '/config.php';
    if (!file_exists($config_file)) {
        return false;
    }
    
    $config = include $config_file;
    return is_array($config) ? $config : false;
}
?>