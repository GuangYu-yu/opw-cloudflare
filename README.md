## 简介

通过 [CloudflareST-Rust](https://github.com/GuangYu-yu/CloudflareST-Rust) 测试和选择速度最快的 Cloudflare IP 地址，并使用这些优化的 IP 自动更新 Cloudflare DNS 记录，从而优化对 Cloudflare 服务的访问。主要针对 OpenWrt 路由器，但也可在各种 Linux 环境中运行。

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/GuangYu-yu/opw-cloudflare)

## 脚本功能

- 自动测速 Cloudflare IP
- 自动更新 Cloudflare DNS 记录
- 自动推送测速和解析的结果
- 可以将优选 IP 提交到 GitHub

## 安装说明

运行前安装依赖

`bash` `curl`

选择其中一条来首次运行

使用 Github api 地址（需要安装 `jq` `base64`）

```
curl -s "https://api.github.com/repos/GuangYu-yu/opw-cloudflare/contents/cfopw.sh" | jq -r '.content' | base64 -d | bash
```

使用 GitHub raw 地址
```
curl -ksSL https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh | bash
```

使用 GitHub 镜像地址

```
curl -ksSL https://ghproxy.cc/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh | bash
```

后续运行，打开主菜单

`bash cf`

## 文件说明

- `cf`: 主菜单脚本
- `cf_push.sh`: 推送消息服务
- `cfopw.sh`: 初始安装脚本
- `cf.yaml`: 配置文件
- `setup_cloudflarest.sh`: 获取最新 CloudflareST 文件
- `start_ddns.sh`: 测速并解析到 Cloudflare

## 特别功能

- 支持多个测速配置以及多个 Cloudflare 账户
- 较为详细的推送消息
- 从 URL 获取最新 CIDR
- 支持分别设置和测速 IPv4 和 IPv6
- 假设解析组名称为`www`，那么可以通过`bash cf start www`立即执行

## 注意事项

提交到 GitHub ，需要先复制私库中对应文件的原始 URL ,将临时 Token 替换为自建令牌，库中没有该文件会自动创建
