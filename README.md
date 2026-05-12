# 宿舍选择网页部署说明

这是一个静态网页 + Supabase 在线数据库版本。部署后，同学们打开学生填写页，宿舍余量和选择名单会同步到同一份数据库。

## 页面说明

- `index.html`：学生入口页，进入男生或女生填写页。
- `male.html`：男生宿舍填写页，只能选择男生宿舍。
- `female.html`：女生宿舍填写页，只能选择女生宿舍。
- `admin.html`：管理员后台，可管理宿舍、查看名单、撤销记录和导出 CSV。

## 1. 创建 Supabase 数据库

1. 打开 Supabase，新建一个项目。
2. 进入项目后，打开 SQL Editor。
3. 将 `supabase-schema.sql` 的全部内容复制进去并运行。
4. 在 Project Settings -> API 中找到：
   - Project URL
   - anon public key

## 2. 填写网页数据库配置

分别打开 `male.html`、`female.html` 和 `admin.html`，找到这两行：

```js
const SUPABASE_URL = "https://YOUR-PROJECT.supabase.co";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
```

把它们都替换成你的 Supabase Project URL 和 anon public key。

## 3. 部署网页

把这些文件和文件夹一起上传到任意静态网站平台，例如：

- `index.html`
- `male.html`
- `female.html`
- `admin.html`
- `assets/`

- Netlify
- Vercel
- GitHub Pages
- Cloudflare Pages

部署完成后：

- 发给同学：`https://你的网站/index.html`
- 男生直达：`https://你的网站/male.html`
- 女生直达：`https://你的网站/female.html`
- 管理员自己使用：`https://你的网站/admin.html`

## 重要提醒

当前拆分可以防止同学在正常填写页面误删或修改配置。请不要把 `admin.html` 链接发到班级群里。更严格的权限控制需要接 Supabase 登录或额外的管理员认证。

## 更新数据库规则

如果你已经运行过旧版 `supabase-schema.sql`，这次仍然需要把新版 `supabase-schema.sql` 复制到 Supabase SQL Editor 里再运行一次。

新版规则包括：

- 学号必须符合 `120242227xxx` 格式。
- 学号单独唯一，同一个学号不能被不同姓名重复占用。
- 默认宿舍规模调整为男生 32 间、女生 21 间，共 212 个床位。
