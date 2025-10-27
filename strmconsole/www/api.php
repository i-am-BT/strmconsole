<?php
// api.php - 完整修复版本，包含进度显示修复

// 禁用错误输出到浏览器
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', '/www/wwwroot/strm_console/logs/php_errors.log');

// 设置JSON头
header('Content-Type: application/json');

// 开始输出缓冲
ob_start();

// 全局错误处理函数
function handle_shutdown() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        while (ob_get_level() > 0) {
            ob_end_clean();
        }
        echo json_encode([
            'status' => 'error',
            'message' => '服务器内部错误: ' . $error['message']
        ]);
    }
}

register_shutdown_function('handle_shutdown');

try {
    // 包含必要的文件
    if (!file_exists('functions.php')) {
        throw new Exception('functions.php 文件不存在');
    }
    
    require_once 'functions.php';
    
    // 检查登录状态
    check_login();
    
    // 获取配置
    $config = get_config();
    if (!$config) {
        throw new Exception('系统配置错误');
    }
    
    // 获取action参数
    $action = $_GET['action'] ?? '';
    
    if (empty($action)) {
        throw new Exception('未指定操作类型');
    }
    
    // 根据action执行相应操作
    switch ($action) {
        case 'start_task':
            $type = $_POST['type'] ?? '';
            if (empty($type)) {
                throw new Exception('未指定任务类型');
            }
            $result = start_task($type, $config);
            break;
            
        case 'stop_task':
            $result = stop_task($config);
            break;
            
        case 'get_progress':
            $result = get_progress($config);
            break;
            
        case 'get_logs':
            $result = get_logs($config);
            break;
            
        case 'get_system_info':
            $result = get_system_info_safe($config);
            break;
            
        default:
            throw new Exception('未知操作: ' . $action);
    }
    
    // 清除输出缓冲区
    ob_end_clean();
    
    // 输出结果
    echo is_string($result) ? $result : json_encode($result);
    
} catch (Exception $e) {
    // 清除输出缓冲区
    while (ob_get_level() > 0) {
        ob_end_clean();
    }
    
    // 输出错误信息
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
    
    // 记录错误日志
    error_log('API Error: ' . $e->getMessage());
}

/**
 * 启动任务
 */
function start_task($type, $config) {
    // 验证任务类型
    $valid_types = ['full_update', 'incremental', 'metadata', 'scan_only'];
    if (!in_array($type, $valid_types)) {
        return ['status' => 'error', 'message' => '无效的任务类型'];
    }
    
    $task_file = $config['task_path'] . 'current_task.json';
    
    // 检查任务目录是否存在
    if (!is_dir($config['task_path'])) {
        if (!mkdir($config['task_path'], 0755, true)) {
            return ['status' => 'error', 'message' => '无法创建任务目录'];
        }
    }
    
    // 检查是否已有任务运行
    if (file_exists($task_file)) {
        $current_task = @json_decode(file_get_contents($task_file), true);
        if ($current_task && isset($current_task['status']) && $current_task['status'] === 'running') {
            return ['status' => 'error', 'message' => '已有任务正在运行，请先停止当前任务'];
        }
    }
    
    // 根据任务类型启动不同的脚本
    $script_map = [
        'full_update' => 'generate_strm_full.sh',
        'incremental' => 'strm_incremental.sh',
        'metadata' => 'strm_metadata.sh',
        'scan_only' => 'strm_scan_only.sh'
    ];
    
    $script_name = $script_map[$type];
    $script_path = $config['script_path'] . $script_name;
    
    // 检查脚本文件是否存在
    if (!file_exists($script_path)) {
        return ['status' => 'error', 'message' => '脚本文件不存在: ' . $script_name];
    }
    
    // 检查脚本是否可执行
    if (!is_executable($script_path)) {
        @chmod($script_path, 0755);
    }
    
    // 生成日志文件名
    $log_file = $config['docker_logs'] . 'strm_' . $type . '_' . date('Ymd_His') . '.log';
    
    // 确保日志目录存在
    $log_dir = dirname($log_file);
    if (!is_dir($log_dir)) {
        @mkdir($log_dir, 0755, true);
    }
    
    // 使用更简单可靠的方法启动后台任务
    $output = [];
    $return_var = 0;
    
    // 直接使用后台执行，不依赖复杂的进程管理
    $command = "nohup bash " . escapeshellarg($script_path) . " > " . escapeshellarg($log_file) . " 2>&1 & echo $!";
    $pid = exec($command, $output, $return_var);
    
    if (!empty($pid) && is_numeric($pid)) {
        // 验证进程确实存在
        $check_process = "ps -p " . escapeshellarg($pid) . " -o pid= > /dev/null 2>&1 && echo 'exists'";
        $process_exists = exec($check_process);
        
        if ($process_exists !== 'exists') {
            return ['status' => 'error', 'message' => '任务启动失败，进程未创建成功'];
        }
        
        // 记录任务信息
        $task_info = [
            'pid' => intval($pid),
            'type' => $type,
            'status' => 'running',
            'start_time' => date('Y-m-d H:i:s'),
            'log_file' => $log_file,
            'progress' => 0
        ];
        
        if (@file_put_contents($task_file, json_encode($task_info)) === false) {
            return ['status' => 'error', 'message' => '无法保存任务信息'];
        }
        
        log_operation("启动任务: $type (PID: $pid)");
        
        return ['status' => 'success', 'message' => '任务已启动', 'pid' => $pid];
    } else {
        // 如果上面的方法失败，尝试另一种方法
        $pid_file = "/tmp/strm_task_{$type}_" . time() . ".pid";
        $command = "bash " . escapeshellarg($script_path) . " > " . escapeshellarg($log_file) . " 2>&1 & echo $! > " . escapeshellarg($pid_file);
        exec($command);
        
        // 等待一下，然后读取PID文件
        usleep(500000); // 0.5秒
        if (file_exists($pid_file)) {
            $pid = trim(file_get_contents($pid_file));
            @unlink($pid_file);
            
            if (!empty($pid) && is_numeric($pid)) {
                // 记录任务信息
                $task_info = [
                    'pid' => intval($pid),
                    'type' => $type,
                    'status' => 'running',
                    'start_time' => date('Y-m-d H:i:s'),
                    'log_file' => $log_file,
                    'progress' => 0
                ];
                
                @file_put_contents($task_file, json_encode($task_info));
                log_operation("启动任务: $type (PID: $pid)");
                
                return ['status' => 'success', 'message' => '任务已启动', 'pid' => $pid];
            }
        }
        
        return ['status' => 'error', 'message' => '任务启动失败，请检查脚本权限和系统资源'];
    }
}

/**
 * 停止任务
 */
function stop_task($config) {
    $task_file = $config['task_path'] . 'current_task.json';
    
    if (!file_exists($task_file)) {
        return ['status' => 'error', 'message' => '没有运行中的任务'];
    }
    
    $task_info = @json_decode(file_get_contents($task_file), true);
    
    if (!$task_info || !isset($task_info['pid'])) {
        return ['status' => 'error', 'message' => '任务文件损坏'];
    }
    
    // 使用更简单的方法停止任务
    $pid = $task_info['pid'];
    $output = [];
    exec("kill " . escapeshellarg($pid) . " 2>&1", $output, $return_var);
    
    // 更新任务状态
    $task_info['status'] = 'stopped';
    $task_info['end_time'] = date('Y-m-d H:i:s');
    
    if (@file_put_contents($task_file, json_encode($task_info)) === false) {
        return ['status' => 'error', 'message' => '无法更新任务状态'];
    }
    
    log_operation("停止任务: " . $task_info['type'] . " (PID: " . $task_info['pid'] . ")");
    
    return ['status' => 'success', 'message' => '任务已停止'];
}

/**
 * 获取进度 - 修复版本
 */
function get_progress($config) {
    $task_file = $config['task_path'] . 'current_task.json';
    
    if (!file_exists($task_file)) {
        return ['status' => 'no_task'];
    }
    
    $task_info = @json_decode(file_get_contents($task_file), true);
    
    if (!$task_info) {
        return ['status' => 'error', 'message' => '任务文件损坏'];
    }
    
    // 检查进程是否仍在运行 - 使用简单方法
    $is_running = false;
    if (isset($task_info['status']) && $task_info['status'] === 'running' && isset($task_info['pid'])) {
        $output = [];
        exec("ps -p " . escapeshellarg($task_info['pid']) . " -o pid= 2>/dev/null", $output, $return_var);
        $is_running = (!empty($output) && trim($output[0]) == $task_info['pid']);
        
        if (!$is_running) {
            $task_info['status'] = 'completed';
            $task_info['end_time'] = date('Y-m-d H:i:s');
            @file_put_contents($task_file, json_encode($task_info));
        }
    }
    
    // 从日志文件中提取进度信息
    $progress = 0;
    if (isset($task_info['log_file']) && file_exists($task_info['log_file'])) {
        $progress = parse_progress_from_log_safe($task_info['log_file']);
    }
    
    $task_info['progress'] = $progress;
    $task_info['is_running'] = $is_running;
    
    return $task_info;
}

/**
 * 从日志解析进度 - 修复版本
 */
function parse_progress_from_log_safe($log_file, $task_type = '') {
    if (!file_exists($log_file)) {
        return 0;
    }
    
    // 读取文件最后部分
    $file_size = @filesize($log_file);
    if ($file_size === false || $file_size == 0) {
        return 0;
    }
    
    $read_size = min($file_size, 16384); // 读取最后16KB
    
    $handle = @fopen($log_file, 'r');
    if (!$handle) {
        return 0;
    }
    
    @fseek($handle, -$read_size, SEEK_END);
    $content = @fread($handle, $read_size);
    @fclose($handle);
    
    if (empty($content)) {
        return 0;
    }
    
    // 根据任务类型使用不同的进度检测逻辑
    switch ($task_type) {
        case 'metadata':
            // 刮削数据复制任务进度检测
            if (preg_match('/已扫描 (\d+) 个视频目录/', $content, $matches)) {
                $scanned = intval($matches[1]);
                // 基于扫描目录数估算进度
                return min(95, intval($scanned / 5)); // 假设最多500个目录
            }
            
            if (preg_match('/成功处理元数据文件: (\d+) 个/', $content, $matches)) {
                $processed = intval($matches[1]);
                return min(95, intval($processed / 10)); // 假设最多1000个文件
            }
            break;
            
        case 'scan_only':
            // STRM扫描任务进度检测
            if (preg_match('/已处理 (\d+) 个视频文件/', $content, $matches)) {
                $processed = intval($matches[1]);
                return min(95, intval($processed / 200)); // 假设最多20000个文件
            }
            break;
            
        case 'incremental':
            // 增量更新任务进度检测
            if (preg_match('/已处理 (\d+) 个视频文件/', $content, $matches)) {
                $processed = intval($matches[1]);
                return min(95, intval($processed / 5)); // 假设最多500个文件
            }
            break;
            
        case 'full_update':
            // 全量更新任务进度检测
            if (preg_match('/已处理 (\d+) 个视频文件/', $content, $matches)) {
                $processed = intval($matches[1]);
                return min(95, intval($processed / 300)); // 假设最多30000个文件
            }
            
            if (preg_match('/第 (\d+) 批刮削数据/', $content, $matches)) {
                $batch = intval($matches[1]);
                return min(95, $batch * 10); // 每批10%
            }
            break;
    }
    
    // 通用进度检测（适用于所有任务类型）
    if (preg_match('/已处理 (\d+) 个视频文件/', $content, $matches)) {
        $processed = intval($matches[1]);
        return min(95, intval($processed / 100));
    }
    
    if (preg_match('/已扫描 (\d+) 个视频目录/', $content, $matches)) {
        $scanned = intval($matches[1]);
        return min(95, intval($scanned / 10));
    }
    
    if (preg_match('/成功处理元数据文件: (\d+) 个/', $content, $matches)) {
        $processed = intval($matches[1]);
        return min(95, intval($processed / 50));
    }
    
    // 如果找到完成标记，返回100%
    if (strpos($content, '刮削数据复制完成') !== false || 
        strpos($content, 'STRM扫描完成') !== false ||
        strpos($content, '增量更新完成') !== false ||
        strpos($content, '全量更新完成') !== false ||
        strpos($content, '🎉') !== false) {
        return 100;
    }
    
    // 如果找到错误标记，返回0%
    if (strpos($content, '❌') !== false || 
        strpos($content, '错误:') !== false ||
        strpos($content, '失败') !== false) {
        return 0;
    }
    
    // 如果日志有内容但没找到进度信息，根据日志大小估算
    if (strlen($content) > 500) {
        // 根据文件大小估算进度（粗略估计）
        $file_size = filesize($log_file);
        if ($file_size > 100000) { // 100KB以上
            return 50;
        } elseif ($file_size > 50000) { // 50-100KB
            return 30;
        } elseif ($file_size > 10000) { // 10-50KB
            return 15;
        } elseif ($file_size > 1000) { // 1-10KB
            return 5;
        }
    }
    
    return 0;
}

/**
 * 获取日志 - 使用文件操作替代shell_exec
 */
function get_logs($config) {
    $task_file = $config['task_path'] . 'current_task.json';
    
    if (!file_exists($task_file)) {
        return ['logs' => '暂无任务日志'];
    }
    
    $task_info = @json_decode(file_get_contents($task_file), true);
    $log_content = '';
    
    if ($task_info && isset($task_info['log_file']) && file_exists($task_info['log_file'])) {
        // 读取文件最后部分
        $file_size = @filesize($task_info['log_file']);
        $read_size = min($file_size, 10240); // 读取最后10KB
        
        if ($file_size > 0) {
            $handle = @fopen($task_info['log_file'], 'r');
            if ($handle) {
                @fseek($handle, -$read_size, SEEK_END);
                $log_content = @fread($handle, $read_size);
                @fclose($handle);
            }
        } else {
            $log_content = @file_get_contents($task_info['log_file']);
        }
    }
    
    return ['logs' => $log_content ?: '暂无日志内容'];
}

/**
 * 获取系统信息 - 安全版本，不使用shell_exec
 */
function get_system_info_safe($config) {
    // 检查符号链接状态
    $strm_path = '/www/wwwroot/strm_console/strm_files';
    $mount_path = '/www/wwwroot/strm_console/clouddrive';
    $logs_path = '/www/wwwroot/strm_console/docker_logs';
    $update_file = '/www/wwwroot/strm_console/last_full_update.txt';
    
    // STRM文件状态
    $strm_count = 0;
    if (file_exists($strm_path)) {
        $strm_count = count_strm_files($strm_path);
        $strm_status = "正常 (找到 {$strm_count} 个STRM文件)";
    } else {
        $strm_status = "目录不存在";
    }
    
    // 挂载点状态
    $mount_status = '未知';
    if (file_exists($mount_path)) {
        $files = @scandir($mount_path);
        $file_count = ($files === false) ? 0 : count($files) - 2;
        $mount_status = ($file_count > 0) ? "正常" : "目录为空";
    } else {
        $mount_status = "挂载点不存在";
    }
    
    // 最后全量更新时间
    $last_update = '未知';
    if (file_exists($update_file)) {
        $last_update = trim(file_get_contents($update_file));
    } else {
        $last_update = '从未进行全量更新';
    }
    
    return [
        'strm_count' => $strm_count,
        'mount_status' => $mount_status,
        'last_full_update' => $last_update
    ];
}

/**
 * 递归计算STRM文件数量
 */
function count_strm_files($dir) {
    $count = 0;
    $files = @scandir($dir);
    
    if ($files === false) {
        return 0;
    }
    
    foreach ($files as $file) {
        if ($file == '.' || $file == '..') continue;
        
        $path = $dir . '/' . $file;
        
        if (is_dir($path)) {
            $count += count_strm_files($path);
        } elseif (is_file($path) && pathinfo($path, PATHINFO_EXTENSION) === 'strm') {
            $count++;
        }
    }
    
    return $count;
}
?>