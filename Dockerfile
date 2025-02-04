# 基础镜像（已支持多架构）
FROM --platform=linux/arm64 docker.io/python:3.11-slim-bullseye AS builder

MAINTAINER myh
# 增加语言utf-8
ENV LANG=zh_CN.UTF-8
ENV LC_CTYPE=zh_CN.UTF-8
ENV LC_ALL=C
ENV PYTHONPATH=/data/InStock
EXPOSE 9988

# 使用国内镜像地址加速
RUN sed -i "s@http://\(deb\|security\).debian.org@https://mirrors.aliyun.com@g" /etc/apt/sources.list && \
    echo  "[global]\n\
index-url = https://mirrors.aliyun.com/pypi/simple\n\
trusted-host = mirrors.aliyun.com" > /etc/pip.conf && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# 安装系统依赖（增加libta-lib-dev）
RUN apt-get update && \
    apt-get install -y cron gcc make python3-dev default-libmysqlclient-dev \
    build-essential pkg-config curl libta-lib-dev && \
    pip install supervisor mysqlclient requests arrow numpy SQLAlchemy PyMySQL \
    Logbook python_dateutil py_mini_racer tqdm beautifulsoup4 bokeh pandas \
    tornado mini-racer easytrader TA-Lib && \
    apt-get --purge remove -y gcc make python3-dev default-libmysqlclient-dev curl && \
    rm -rf /root/.cache/* /var/lib/apt/lists/* && \
    apt-get clean && apt-get autoclean && apt-get autoremove -y

WORKDIR /data
# InStock软件
COPY stock /data/InStock
COPY cron/cron.hourly /etc/cron.hourly
COPY cron/cron.workdayly /etc/cron.workdayly
COPY cron/cron.monthly /etc/cron.monthly

# 任务调度配置
RUN chmod 755 /data/InStock/instock/bin/run_*.sh && \
    chmod 755 /etc/cron.hourly/* /etc/cron.workdayly/* /etc/cron.monthly/* && \
    echo "SHELL=/bin/sh \n\
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin \n\
*/30 9,10,11,13,14,15 * * 1-5 /bin/run-parts /etc/cron.hourly \n\
30 17 * * 1-5 /bin/run-parts /etc/cron.workdayly \n\
30 10 * * 3,6 /bin/run-parts /etc/cron.monthly \n" > /var/spool/cron/crontabs/root && \
    chmod 600 /var/spool/cron/crontabs/root

ENTRYPOINT ["supervisord","-n","-c","/data/InStock/supervisor/supervisord.conf"]
