<?php
// dashboard.php - 修复版本

// 包含必要的文件
require_once 'functions.php';

// 检查登录状态
check_login();

// 获取配置
$config = get_config();
if (!$config) {
    die('系统配置错误，请联系管理员');
}
?>

<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>STRM 文件管理控制台</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>STRM 文件管理控制台</h1>
            <div class="user-info">
                欢迎, <?php echo htmlspecialchars($_SESSION['username']); ?> 
                <a href="logout.php" class="btn btn-secondary">退出</a>
            </div>
        </header>

        <div class="dashboard">
            <!-- 任务控制区域 -->
            <div class="control-panel">
                <h2>任务控制</h2>
                <div class="button-group">
                    <button id="startFullUpdate" class="btn btn-primary">开始全量更新</button>
                    <button id="startIncremental" class="btn btn-primary">开始增量更新</button>
                    <button id="startMetadata" class="btn btn-primary">仅刮削数据复制</button>
                    <button id="startScanOnly" class="btn btn-primary">仅STRM扫描</button>
                    <button id="stopTask" class="btn btn-danger">停止当前任务</button>
                </div>
            </div>

            <!-- 进度显示区域 -->
            <div class="progress-panel">
                <h2>任务进度</h2>
                <div id="progressContainer">
                    <div class="progress-info">
                        <div id="taskStatus">当前状态: 无任务运行</div>
                        <div id="taskProgress">进度: 0%</div>
                        <div id="taskDetails">详细信息: 等待任务开始...</div>
                    </div>
                    <div class="progress-bar">
                        <div id="progressBar" class="progress-fill" style="width: 0%"></div>
                    </div>
                </div>
            </div>

            <!-- 实时日志区域 -->
            <div class="log-panel">
                <h2>实时日志</h2>
                <div class="log-controls">
                    <button id="clearLogs" class="btn btn-secondary">清空日志</button>
                    <button id="refreshLogs" class="btn btn-secondary">刷新日志</button>
                </div>
                <div id="logContent" class="log-content">
                    <!-- 日志内容将通过JavaScript动态加载 -->
                </div>
            </div>

            <!-- 系统信息区域 -->
            <div class="info-panel">
                <h2>系统信息</h2>
                <div class="system-info">
                    <div>STRM文件总数: <span id="strmCount">加载中...</span></div>
                    <div>挂载点状态: <span id="mountStatus">检查中...</span></div>
                    <div>最后全量更新: <span id="lastFullUpdate">加载中...</span></div>
                    <div>服务器时间: <span id="serverTime"><?php echo date('Y-m-d H:i:s'); ?></span></div>
                </div>
            </div>
        </div>
    </div>

    <script src="js/script.js"></script>
</body>
</html>