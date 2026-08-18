# 基于 AI Coding 的校园住宿资源配置平台

面向学院集中选宿场景的在线宿舍与床位选择系统。项目用于替代共享表格抢占床位的传统方式，通过学生名单校验、床位唯一锁定、开放时间控制、操作日志和管理员后台，提升选宿流程的公平性、可追溯性和管理效率。

## 在线入口

- 学生入口：https://ncepu-cce-dorm.netlify.app
- 男生填写：https://ncepu-cce-dorm.netlify.app/male.html
- 女生填写：https://ncepu-cce-dorm.netlify.app/female.html
- 管理员后台：https://ncepu-cce-dorm.netlify.app/admin.html

如果微信内置浏览器无法直接打开，建议复制链接到系统浏览器、Chrome、Edge 或 Safari 中访问。

## 项目背景

学院约 222 名学生需要集中完成宿舍床位选择。原方案依赖共享表格抢占，存在一人占用多个床位、误删误改他人信息、操作记录难追溯、规则约束弱和公平性争议等问题。

本项目将共享表格流程产品化为一个具备服务端校验、并发控制和后台管理能力的在线系统。

## 核心能力

- 学生端按性别拆分为男生填写页和女生填写页。
- 支持学生在系统开放前预填写姓名和学号，刷新页面后保留本地草稿。
- 系统开放后，学生可选择宿舍和 1-4 床位。
- 服务端校验姓名、学号、性别是否匹配名单。
- 每名学生只能确认一个床位，确认后不可修改。
- 每个床位只能被一名学生占用，避免多人并发抢同一床位造成冲突。
- 管理员可维护宿舍、名单、开放状态、开始时间、截止时间。
- 支持查看和导出选择结果。
- 记录选宿和系统设置操作日志，便于争议追溯。

## 技术栈

- 前端：HTML、CSS、JavaScript
- 部署：Netlify
- 后端：Supabase
- 数据库：PostgreSQL
- 数据同步：Supabase REST API 与 RPC
- 权限与规则：RLS 策略、唯一约束、数据库函数
- 数据导入：Excel 提取脚本生成前端配置和 SQL 数据脚本

## 数据规模

当前配置：

- 学生人数：222 人
- 宿舍数量：57 间
- 床位数量：222 个
- 并发测试：20 人同时抢同一床位时，仅允许 1 人成功提交，其余请求由服务端拦截

## 目录结构

```text
.
├── index.html                         # 学生入口页
├── male.html                          # 男生宿舍填写页
├── female.html                        # 女生宿舍填写页
├── admin.html                         # 管理员后台
├── assets/                            # 图片素材与前端数据配置
│   └── dorm-data.js                   # 由 Excel 生成的宿舍和学生名单前端配置
├── tools/                             # 数据提取、同步和测试脚本
├── netlify.toml                       # Netlify 部署配置
├── supabase-schema.sql                # 基础建表脚本
├── supabase-excel-data.sql            # 宿舍和学生名单数据脚本
├── supabase-controls-lock-audit.sql   # 开放时间、确认锁定、日志功能脚本
├── supabase-bed-selection.sql         # 床位选择与并发冲突控制脚本
└── 宿舍选择系统说明报告.md             # 完整说明和交接报告
```

## Supabase 数据表

- `dorms`：宿舍配置表，保存宿舍号、性别和容量。
- `allowed_students`：允许选宿名单表，保存学号、姓名和性别。
- `records`：最终选宿记录表，保存学生选择的宿舍和床位。
- `system_settings`：系统开放状态、开始时间和截止时间。
- `audit_log`：操作日志表，记录选宿和系统设置变更。

## 关键 SQL 文件说明

- `supabase-schema.sql`：首次建库时使用。
- `supabase-excel-data.sql`：宿舍名单或学生名单变化时使用。
- `supabase-controls-lock-audit.sql`：配置开放时间、确认后不可修改、操作日志等功能。
- `supabase-bed-selection.sql`：启用床位 1-4 选择和床位唯一锁定。
- `supabase-fix-audit-log-rls.sql`：修复日志表 RLS 权限问题。
- `supabase-cleanup-concurrency-test.sql`：清理并发测试数据。

正式使用前不要随意重复运行清理脚本，避免误删正式选宿记录。

## 更新宿舍或学生名单

1. 将最新 Excel 放入项目文件夹。
2. 运行 `tools/extract_dorm_excel.py`。
3. 检查生成的 `assets/dorm-data.js` 和 `supabase-excel-data.sql`。
4. 在 Supabase SQL Editor 中运行最新的 `supabase-excel-data.sql`。
5. 重新部署 Netlify。

## 部署方式

本项目是静态前端项目，部署目录为项目根目录。

Netlify 配置：

```text
Build command: 留空
Publish directory: .
```

也可以使用 Netlify CLI 直接部署：

```bash
npx netlify-cli deploy --prod --dir .
```

## 正式使用前检查

- 学生入口可以打开。
- 男生页只显示男生宿舍。
- 女生页只显示女生宿舍。
- 管理员后台可以同步 Supabase 数据。
- 系统设置可以正常保存开放状态和时间。
- 测试学生可以成功选择一个床位。
- 同一学生重复提交会被拦截。
- 同一床位多人同时提交时只允许一个人成功。
- 管理员后台可以查看记录和操作日志。
- 测试数据已清理。

## 项目价值

本项目将容易产生争议的共享表格选宿流程，转化为具备规则校验、权限控制、并发保护和数据追溯能力的在线资源配置系统。它体现了从真实场景出发，借助 AI Coding 快速完成需求拆解、原型实现、数据库建模、部署上线和迭代优化的完整产品闭环。
