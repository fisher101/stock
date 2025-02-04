# 基础镜像（已支持多架构）
FROM docker.io/python:3.11-slim-bullseye

MAINTAINER myh
# 区域设置
ENV LANG=zh_CN.UTF-8 \
    LC_CTYPE=zh_CN.UTF-8 \
    LC_ALL=C \
    PYTHONPATH=/data/InStock \
    PIP_NO_CACHE_DIR=1

EXPOSE 9988

# 系统级配置
RUN sed -i "s@http://\(deb\|security\).debian.org@https://mirrors.aliyun.com@g" /etc/apt/sources.list && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# 安装系统依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cron \
    libta-lib-dev \
    pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装Python依赖
COPY requirements.txt /tmp/
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    pip check && \
    rm /tmp/requirements.txt

# 应用部署
WORKDIR /data
COPY stock /data/InStock
COPY cron/cron.hourly /etc/cron.hourly
COPY cron/cron.workdayly /etc/cron.workdayly
COPY cron/cron.monthly /etc/cron.monthly

# 配置定时任务
RUN chmod 755 /data/InStock/instock/bin/run_*.sh && \
    chmod 755 /etc/cron.hourly/* /etc/cron.workdayly/* /etc/cron.monthly/* && \
    echo "SHELL=/bin/sh\n\
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin\n\
*/30 9,10,11,13,14,15 * * 1-5 /bin/run-parts /etc/cron.hourly\n\
30 17 * * 1-5 /bin/run-parts /etc/cron.workdayly\n\
30 10 * * 3,6 /bin/run-parts /etc/cron.monthly\n" > /var/spool/cron/crontabs/root && \
    chmod 600 /var/spool/cron/crontabs/root

ENTRYPOINT ["supervisord", "-n", "-c", "/data/InStock/supervisor/supervisord.conf"]
