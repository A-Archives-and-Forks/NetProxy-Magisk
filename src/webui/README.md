# NetProxy WebUI

基于 Material Design 3 的现代化 NetProxy 管理界面。

## 功能特性

✨ **Material You 设计**
- 遵循 Material Design 3 规范
- 支持浅色/深色/自动主题
- 流畅的动画和过渡效果

📊 **核心功能**
- 实时服务状态监控
- 配置文件管理（创建/编辑/删除/切换）
- UID 白名单管理
- 日志查看（服务日志 + Xray 日志）
- 流量统计

🚀 **技术栈**
- Parcel - 零配置构建工具
- mdui - Material Design 3 组件库
- KernelSU API - 系统权限调用

## 开发

### 安装依赖
```bash
npm install
```

### 开发模式
```bash
npm start
```
访问 http://localhost:1234

### 构建生产版本
```bash
npm run build
```
输出到 `dist/` 目录

## 项目结构

```
src/
├── index.html      # 主页面
├── app.js          # 主应用逻辑
└── style.css       # 自定义样式
```

## 页面说明

### 1. 状态页
- 服务运行状态
- 当前使用的配置文件
- 运行时间
- 流量统计

### 2. 配置页
- 配置文件列表
- 新建/编辑/删除配置
- 切换当前配置

### 3. 白名单页
- UID 白名单管理
- 添加/删除 UID
- 应用搜索

### 4. 日志页
- 服务日志实时查看
- Xray 日志实时查看
- 日志刷新功能

## 部署

构建完成后，将 `dist/` 目录内容复制到：
```
/data/adb/modules/netproxy/webroot/
```

## 许可

本项目用于 NetProxy Magisk 模块的 Web 管理界面。
