# NetProxy WebUI

基于 Material Design 3 的现代化 NetProxy 管理界面。

## 功能特性

✨ **现代化 UI 设计**
- 遵循 Material Design 3 规范
- 支持 Material You (Monet) 动态取色

📊 **核心功能**
- **仪表盘**: 实时网络速度、流量统计、出站模式切换、网络连通性检测
- **节点管理**: 支持订阅/本地节点管理、延迟测试、节点排序、清理无效节点
- **应用代理**: 分应用代理设置（黑/白名单模式）、应用搜索、批量操作
- **日志查看**: 服务/Xray/TProxy 多维度日志实时查看与导出
- **高级设置**: 路由规则、DNS 配置、模块设置、OnePlus 兼容性修复

🚀 **技术栈**
- **构建工具**: Parcel (零配置构建)
- **UI 框架**: MDUI (Material Legend)
- **图表库**: uPlot (高性能实时图表)
- **底层交互**: KernelSU API (系统权限调用)

## 开发指南

### 安装依赖
```bash
npm install
```

### 启动开发服务器
```bash
npm start
```
访问 http://localhost:1234

### 构建生产版本
```bash
npm run build
```
输出产物位于 `src/module/webroot/` 目录 (由 `build_webui.py` 脚本处理)

## 项目结构

```
src/
├── app.js               # 应用入口
├── index.html           # 主页面模板
├── i18n/                # 国际化资源
│   └── i18n-service.js  # 国际化服务
├── services/            # 业务逻辑层 (Service)
│   ├── app-service.js   # 应用管理服务
│   ├── config-service.js# 配置/订阅服务
│   ├── settings-service.js # 设置/日志服务
│   ├── shell-service.js # 底层 Shell 交互
│   └── status-service.js# 状态监控服务
├── ui/                  # 界面视图层 (View)
│   ├── ui-core.js       # UI 核心控制器
│   ├── app-page.js      # 应用代理页
│   ├── config-page.js   # 节点配置页
│   ├── logs-page.js     # 日志页
│   ├── settings-page.js # 设置页
│   └── status-page.js   # 状态仪表盘
├── styles/              # 样式文件
│   ├── components/      # 组件级样式
│   ├── monet.css        # Material You 动态取色
│   └── index.css        # 样式入口
└── utils/               # 工具函数
```

## 页面功能导航

### 1. 状态 (Status)
- 服务启停控制
- 实时网速曲线 (uPlot)
- 流量统计环形图
- 出站模式切换 (规则/全局/直连)
- 内外网 IP 显示

### 2. 节点 (Config)
- 节点分组展示
- 节点延迟测试与排序
- 订阅更新与管理
- 配置文件导入/导出

### 3. 应用 (Apps)
- 黑名单/白名单模式切换
- 系统应用/用户应用筛选
- 应用图标懒加载显示
- 关键字搜索

### 4. 设置 (Settings)
- **基础设置**: 代理端口、IPv6、UDP/TCP 开关
- **路由设置**: 自定义路由规则、Clash 规则导入
- **DNS 设置**: DNS 服务器、Hosts 管理
- **模块设置**: 开机自启、兼容性修复
- **日志管理**: 日志查看、自动刷新、日志导出

## 部署

本项目作为 NetProxy Magisk 模块的一部分，构建后的文件会被打包进模块的 `webroot` 目录。
推荐使用 `build_webui.py` 脚本进行完整构建流程。

## 许可

本项目遵循 GPL3.0 许可证。
