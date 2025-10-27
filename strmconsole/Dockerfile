FROM php:8.1-fpm

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    nginx \
    git \
    wget \
    curl \
    sudo \
    acl \
    && rm -rf /var/lib/apt/lists/*

# 安装PHP扩展
RUN docker-php-ext-install pdo pdo_mysql

# 配置nginx和PHP
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/php.ini /usr/local/etc/php/conf.d/custom.ini

# 创建必要的目录
RUN mkdir -p /var/www/html \
    && mkdir -p /var/log/strm_console \
    && mkdir -p /var/strm_files \
    && mkdir -p /docker/clouddrive \
    && mkdir -p /docker/logs

# 复制应用程序文件
COPY www/ /var/www/html/
COPY scripts/ /var/www/html/scripts/
COPY entrypoint.sh /usr/local/bin/

# 设置权限
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /var/www/html/scripts/*.sh \
    && chown -R www-data:www-data /var/www/html \
    && chown -R www-data:www-data /var/log/strm_console \
    && chown -R www-data:www-data /var/strm_files

# 暴露端口
EXPOSE 80

# 启动脚本
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]