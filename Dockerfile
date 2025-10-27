FROM php:8.1-fpm

# ��װϵͳ����
RUN apt-get update && apt-get install -y \
    nginx \
    git \
    wget \
    curl \
    sudo \
    acl \
    && rm -rf /var/lib/apt/lists/*

# ��װPHP��չ
RUN docker-php-ext-install pdo pdo_mysql

# ����nginx��PHP
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/php.ini /usr/local/etc/php/conf.d/custom.ini

# ������Ҫ��Ŀ¼
RUN mkdir -p /var/www/html \
    && mkdir -p /var/log/strm_console \
    && mkdir -p /var/strm_files \
    && mkdir -p /docker/clouddrive \
    && mkdir -p /docker/logs

# ����Ӧ�ó����ļ�
COPY www/ /var/www/html/
COPY scripts/ /var/www/html/scripts/
COPY entrypoint.sh /usr/local/bin/

# ����Ȩ��
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /var/www/html/scripts/*.sh \
    && chown -R www-data:www-data /var/www/html \
    && chown -R www-data:www-data /var/log/strm_console \
    && chown -R www-data:www-data /var/strm_files

# ��¶�˿�
EXPOSE 80

# �����ű�
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]