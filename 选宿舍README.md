# 宿舍选择系统使用指南

本项目采用 **Netlify 托管网页 + Supabase 保存数据** 的方案。

- Netlify：负责把网页发布到网上，生成可分享的网址。
- Supabase：负责保存宿舍、学生选择记录，并处理学号唯一、宿舍满员判断。

## 文件说明

- `index.html`：学生入口页，进入男生或女生填写页。
- `male.html`：男生宿舍填写页，只显示男生宿舍。
- `female.html`：女生宿舍填写页，只显示女生宿舍。
- `admin.html`：管理员后台，可添加宿舍、查看名单、撤销记录、导出 CSV。
- `assets/`：网页使用的校标、背景图等素材，部署时必须一起上传。
- `supabase-schema.sql`：Supabase 数据库建表和规则脚本。
- `supabase-safe-rerun.sql`：已有测试数据时推荐使用的安全重跑脚本，会先备份旧记录再清理不合规/重复学号。
- `netlify.toml`：Netlify 部署配置。

## 一、Supabase 数据库配置

1. 打开 Supabase，进入你的项目。
2. 打开左侧 `SQL Editor`。
3. 如果是第一次建库，复制 `supabase-schema.sql` 的全部内容。
4. 如果已经测试过、库里有旧记录，推荐复制 `supabase-safe-rerun.sql` 的全部内容。
5. 粘贴到 SQL Editor 中并运行。

运行成功后，Supabase 会创建：

- `dorms` 表：保存宿舍信息。
- `records` 表：保存学生选择记录。
- `choose_dorm` 函数：提交宿舍选择时检查满员、性别、学号唯一。

当前规则：

- 学号格式必须是 `120242227xxx`。
- 同一个学号只能占用一个宿舍。
- 男生只能选择男生宿舍，女生只能选择女生宿舍。
- 宿舍满员后不能继续选择。

如果运行 SQL 时提示重复学号，可以直接改用 `supabase-safe-rerun.sql`。

如果你确认全部都是测试数据，也可以先清空记录：

```sql
delete from public.records;
```

然后重新运行 `supabase-schema.sql`。

如果 Supabase SQL Editor 页面出现“浏览器扩展可能导致了错误”，通常不是 SQL 问题，而是浏览器翻译或插件干扰：

1. 关闭 Chrome 自带翻译。
2. 暂停第三方翻译插件。
3. 刷新页面。
4. 仍然不行就用无痕窗口或 Edge 打开 Supabase。

## 二、Netlify 部署

1. 确保 GitHub 仓库中包含这些文件：

```text
index.html
male.html
female.html
admin.html
netlify.toml
supabase-schema.sql
assets/
```

2. 打开 Netlify。
3. 选择 `Add new site`。
4. 选择 `Import an existing project`。
5. 选择 GitHub 仓库 `Hu-up/Choose_dormitory`。
6. 构建设置保持：

```text
Build command: 留空
Publish directory: .
```

`netlify.toml` 已经配置好，Netlify 会直接发布项目根目录。

## 三、发布后的链接

假设 Netlify 给你的站点地址是：

```text
https://your-site.netlify.app
```

那么实际使用链接是：

```text
学生入口页：https://your-site.netlify.app/
男生直达页：https://your-site.netlify.app/male.html
女生直达页：https://your-site.netlify.app/female.html
管理员后台：https://your-site.netlify.app/admin.html
```

发给同学时，推荐发学生入口页：

```text
https://your-site.netlify.app/
```

如果想分开发，也可以男生发 `male.html`，女生发 `female.html`。

管理员后台 `admin.html` 不要发到班级群里。

## 四、管理员使用流程

1. 打开：

```text
https://your-site.netlify.app/admin.html
```

2. 在 `宿舍管理` 中添加宿舍：

- 宿舍号
- 性别
- 容量

3. 添加后，男生/女生填写页会读取同一个 Supabase 数据库。
4. 学生提交后，进入 `选择名单` 查看记录。
5. 需要整理名单时，点击 `导出名单` 下载 CSV。
6. 如果学生填错，可以在后台撤销对应记录。

## 五、学生使用流程

学生打开入口页后：

1. 选择男生宿舍或女生宿舍。
2. 填写姓名。
3. 填写学号，格式必须类似：

```text
120242227001
```

4. 点击想选择的宿舍卡片。
5. 如果宿舍已满，系统会提示选择其他宿舍。

学生页会每 15 秒同步一次宿舍余量，提交后也会立即刷新。

## 六、常见问题

### 管理员添加宿舍后，学生页看不到

检查以下几点：

- 添加宿舍时性别是否选对。
- 男生页只显示男生宿舍，女生页只显示女生宿舍。
- 学生页是否刷新，或等待 15 秒自动同步。
- Supabase 的 `dorms` 表中是否真的有这条宿舍记录。
- Netlify 是否已经部署最新版文件。

如果担心缓存，可以在网址后加：

```text
?v=2
```

例如：

```text
https://your-site.netlify.app/male.html?v=2
```

### 学生重复提交怎么办

同一个学号再次提交，会更新原来的选择，不会新增第二条记录。

如果同一个学号被不同姓名使用，系统会提示学号已被其他姓名使用。

### Supabase 会不会过一会儿断开

正常使用时不会因为打开一会儿就断开。

Supabase 免费项目需要注意：如果项目长期没有活动，免费项目可能会暂停。选宿舍前建议你提前打开 Supabase 项目和网页测试一次，确认数据库处于可用状态。

### Netlify 和 Supabase 分别负责什么

- Netlify 负责网页能被大家访问。
- Supabase 负责数据能被大家共享。

只用 Netlify 不能实现多人同步数据；必须保留 Supabase 或其他数据库。

## 七、正式使用前检查清单

正式发给同学前，建议按顺序检查：

1. Netlify 网站能打开。
2. `male.html` 能显示男生宿舍。
3. `female.html` 能显示女生宿舍。
4. `admin.html` 能打开后台。
5. 后台新增一个测试宿舍，学生页能看到。
6. 用测试学号提交一次选择。
7. 后台 `选择名单` 能看到测试记录。
8. 撤销测试记录。
9. 导出 CSV 能正常打开。

全部通过后，再把学生入口链接发给同学。
