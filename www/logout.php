<?php
// logout.php

// 启动会话
session_start();

// 记录退出日志（如果已登录）
if (isset($_SESSION['username'])) {
    // 包含函数文件来记录日志
    require_once 'functions.php';
    log_operation("用户退出系统");
}

// 销毁所有会话数据
$_SESSION = array();

// 删除会话cookie
if (ini_get("session.use_cookies")) {
    $params = session_get_cookie_params();
    setcookie(session_name(), '', time() - 42000,
        $params["path"], $params["domain"],
        $params["secure"], $params["httponly"]
    );
}

// 销毁会话
session_destroy();

// 重定向到登录页面
header('Location: index.php');
exit;
?>