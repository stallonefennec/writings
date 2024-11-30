---
title: 部署xiaoya alist
description: 部署xiaoya alist
tags:
  - xiaoya
date: 2024-11-30
category: xiaoya
---

## 服务管理（请牢记以下命令）：
服务管理（请牢记以下命令）
查看日志：/opt/xiaoya/manage.sh logs

启动服务：/opt/xiaoya/manage.sh start

停止服务：/opt/xiaoya/manage.sh stop

重启服务：/opt/xiaoya/manage.sh restart

加载配置：/opt/xiaoya/manage.sh reload

更新服务：/opt/xiaoya/manage.sh update

高级用户自定义配置：/opt/xiaoya/env

修改env或者compose配置后，需要执行上面的加载配置reload命令生效！

服务正在部署，请查看日志等待部署成功后，尝试访问下面的地址
alist: http://10.170.0.2:5678, http://35.241.87.77:5678

webdav: http://10.170.0.2:5678/dav, http://35.241.87.77:5678/dav, 
默认用户密码: guest/guest_Api789

tvbox: http://10.170.0.2:5678/tvbox/my_ext.json, http://35.241.87.77:5678/tvbox/my_ext.json

emby: http://10.170.0.2:2345, http://35.241.87.77:2345, 
默认用户密码: xiaoya/1234

jellyfin: http://10.170.0.2:2346, http://35.241.87.77:2346,
默认用户密码：ailg/5678

服务正在后台部署，执行这个命令查看日志：/opt/xiaoya/manage.sh logs
部署alist需要10分钟，emby/jellyfin需要1-24小时，请耐心等待...
