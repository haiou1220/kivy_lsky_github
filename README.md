# 兰空图床上传工具

这是一个基于 Kivy 的 Android 图片上传小工具。应用会调用系统文件选择器选择图片，然后上传到兰空图床，并返回图片链接。

## 私有配置

项目根目录需要创建一个本地私有配置文件 `lsky_config.py`：

```python
LSKY_API_URL = "https://your-domain.example.com/api/v1/upload"
LSKY_TOKEN = "Bearer your_lsky_pro_token"
```

注意：

- `lsky_config.py` 已加入 `.gitignore`，不要提交到 Git 仓库。
- 打包 APK 时，`lsky_config.py` 会作为本地源码文件被 Buildozer 打进 APK。
- 如果 token 曾经提交或推送到公开仓库，建议到兰空图床后台重新生成 token。

## 本地运行

进入虚拟环境后运行：

```bash
source venv/bin/activate
python main.py
```

桌面环境主要用于检查界面和基础逻辑；Android 文件选择、权限、`content://` URI 处理需要在真机或模拟器上验证。

## Android 打包

进入虚拟环境后执行：

```bash
source venv/bin/activate
buildozer android debug
```

打包成功后 APK 通常生成在：

```text
bin/imageuploader-0.1-arm64-v8a-debug.apk
```

当前配置要点：

- `requirements` 包含 `python3`、`hostpython3`、`kivy`、`requests`、`plyer`。
- `android.permissions` 包含 `INTERNET`、`READ_MEDIA_IMAGES`、`READ_EXTERNAL_STORAGE`。
- `source.exclude_dirs = tests, bin, venv`，避免把虚拟环境和构建产物打进 APK。
- `source.include_exts` 包含 `py`、`kv`、图片格式和字体文件，因此 `lsky_config.py` 与 `wqy-microhei.ttc` 会被包含进 APK。

## 工程文件说明

- `main.py`：应用入口和主逻辑。负责界面控制、Android 权限请求、系统文件选择、`content://` URI 转缓存文件、上传图片和复制链接。
- `lsky.kv`：Kivy UI 布局文件。定义状态文本、图片预览、选择图片按钮、上传按钮、链接输入框和复制按钮。
- `lsky_config.py`：本地私有配置文件。保存 `LSKY_API_URL` 和 `LSKY_TOKEN`，被 `.gitignore` 忽略，不应提交。
- `buildozer.spec`：Buildozer 打包配置。定义应用名、包名、版本、依赖、权限、Android API/NDK、源码包含和排除规则。
- `.gitignore`：Git 忽略规则。忽略 `.buildozer/`、`bin/`、`venv/`、`lsky_config.py` 和 Python 缓存文件。
- `wqy-microhei.ttc`：中文字体文件。应用启动时注册为默认字体，避免中文显示异常。
- `bin/`：Buildozer 输出目录，存放生成的 APK。该目录不提交。
- `.buildozer/`：Buildozer 构建缓存和 Android 工程中间产物。该目录不提交。
- `venv/`：Python 虚拟环境目录。该目录不提交。

## 常见问题

如果选择图片后闪退，优先检查 Android `content://` URI 处理逻辑和 `adb logcat` 崩溃日志。

如果上传失败，检查：

- `lsky_config.py` 是否存在。
- `LSKY_API_URL` 是否是兰空图床 API 上传地址。
- `LSKY_TOKEN` 是否以 `Bearer ` 开头。
- 手机网络是否可访问图床域名。

