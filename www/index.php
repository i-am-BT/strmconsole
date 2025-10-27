<?php
// index.php - 最终修复版本

// 启动会话
session_start();

// 如果已登录，跳转到控制面板
if (isset($_SESSION['logged_in']) && $_SESSION['logged_in'] === true) {
    header('Location: dashboard.php');
    exit;
}

// 包含配置文件
$config_file = __DIR__ . '/config.php';
if (!file_exists($config_file)) {
    die('系统配置错误，请联系管理员');
}

$config = include $config_file;
if (!is_array($config)) {
    die('系统配置错误，请联系管理员');
}

// 处理登录请求
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    
    if ($username === $config['username'] && $password === $config['password']) {
        $_SESSION['logged_in'] = true;
        $_SESSION['username'] = $username;
        $_SESSION['login_time'] = time();
        header('Location: dashboard.php');
        exit;
    } else {
        $error = "用户名或密码错误";
    }
}
?>

<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>STRM 文件管理控制台 - 登录</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body class="login-body">
    <div class="login-container">
        <h1>STRM 文件管理控制台</h1>
        <form method="post" class="login-form">
            <?php if (!empty($error)): ?>
                <div class="alert alert-error"><?php echo htmlspecialchars($error); ?></div>
            <?php endif; ?>
            
            <div class="form-group">
                <label for="username">用户名:</label>
                <input type="text" id="username" name="username" required value="<?php echo htmlspecialchars($_POST['username'] ?? ''); ?>">
            </div>
            
            <div class="form-group">
                <label for="password">密码:</label>
                <input type="password" id="password" name="password" required>
            </div>
            
            <button type="submit" class="btn btn-primary">登录</button>
        </form>
    </div>
</body>
</html>