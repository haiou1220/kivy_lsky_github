import os
import threading
import requests
from pathlib import Path
import uuid

# 1. 全局默认字体配置（必须在任何 Kivy 导入前）
from kivy.config import Config
Config.set('kivy', 'default_font', ['WQY', 'wqy-microhei.ttc'])

# 2. 注册字体
from kivy.core.text import LabelBase
LabelBase.register(name='WQY', fn_regular='wqy-microhei.ttc')

# 3. 现在导入其余 Kivy 组件
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.image import Image
from kivy.uix.textinput import TextInput
from kivy.clock import mainthread
from kivy.core.clipboard import Clipboard
from kivy import platform

# 4. 导入 plyer 文件选择器
from plyer import filechooser

# 5. Android 权限相关 (仅在 Android 上导入)
if platform == "android":
    from android.permissions import request_permissions, Permission
    from jnius import autoclass, jarray

try:
    from lsky_config import LSKY_API_URL, LSKY_TOKEN
except ImportError as exc:
    raise RuntimeError(
        "缺少私有配置文件 lsky_config.py，请在项目根目录创建并填写 "
        "LSKY_API_URL 和 LSKY_TOKEN。"
    ) from exc


def _guess_extension(display_name, mime_type):
    if display_name:
        suffix = Path(display_name).suffix
        if suffix:
            return suffix

    if mime_type:
        mime_map = {
            "image/jpeg": ".jpg",
            "image/png": ".png",
            "image/gif": ".gif",
            "image/webp": ".webp",
            "image/bmp": ".bmp",
        }
        return mime_map.get(mime_type.lower(), ".jpg")

    return ".jpg"


def _android_uri_metadata(content_resolver, parcelable_uri):
    display_name = None
    mime_type = content_resolver.getType(parcelable_uri)

    cursor = None
    try:
        OpenableColumns = autoclass("android.provider.OpenableColumns")
        cursor = content_resolver.query(parcelable_uri, None, None, None, None)
        if cursor and cursor.moveToFirst():
            name_index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if name_index >= 0:
                display_name = cursor.getString(name_index)
    except Exception:
        pass
    finally:
        if cursor:
            cursor.close()

    return display_name, mime_type


def uri_to_file(uri):
    """
    将 Android content:// URI 复制到临时文件，返回临时文件路径。
    如果传入的是普通文件路径，则直接返回原路径。
    """
    if not uri.startswith("content://"):
        return uri

    if platform != "android":
        return uri

    # Android 专用：通过 ContentResolver 打开输入流
    try:
        PythonActivity = autoclass("org.kivy.android.PythonActivity")
        activity = PythonActivity.mActivity
        content_resolver = activity.getContentResolver()
        parcelable_uri = autoclass("android.net.Uri").parse(uri)
        input_stream = content_resolver.openInputStream(parcelable_uri)
        display_name, mime_type = _android_uri_metadata(content_resolver, parcelable_uri)

        cache_dir = activity.getCacheDir().getAbsolutePath()
        suffix = _guess_extension(display_name, mime_type)
        temp_path = os.path.join(cache_dir, f"selected_{uuid.uuid4().hex}{suffix}")

        with open(temp_path, "wb") as f:
            buffer = jarray.zeros(8192, "b")
            while True:
                bytes_read = input_stream.read(buffer)
                if bytes_read <= 0:
                    break
                f.write(bytes((b & 0xFF for b in buffer[:bytes_read])))
        input_stream.close()
        return temp_path
    except Exception as e:
        raise Exception(f"无法转换 URI 到文件: {e}")


def upload_to_lsky(image_path_or_uri: str) -> str:
    """上传图片到兰空图床，支持 Android content URI，返回图片直链"""
    # 如果是 URI，先转为临时文件
    file_path = uri_to_file(image_path_or_uri)

    headers = {
        "Authorization": LSKY_TOKEN,
        "Accept": "application/json",
    }
    with open(file_path, "rb") as f:
        files = {"file": (Path(file_path).name, f, "image/*")}
        resp = requests.post(LSKY_API_URL, headers=headers, files=files, timeout=30)

    # 如果是临时文件，上传后删除
    if file_path != image_path_or_uri and os.path.exists(file_path):
        os.unlink(file_path)

    if resp.status_code != 200:
        raise Exception(f"HTTP {resp.status_code}: {resp.text}")
    data = resp.json()
    if not data.get("status"):
        raise Exception(f"兰空返回错误: {data.get('message', '未知错误')}")
    try:
        return data["data"]["links"]["url"]
    except KeyError:
        if "url" in data.get("data", {}):
            return data["data"]["url"]
        raise Exception("未找到图片链接，返回数据结构异常")


class ImagePublisher(BoxLayout):
    """主界面控件容器"""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.selected_path = None
        self.preview_cache_path = None

        # 如果是 Android，启动时请求权限
        if platform == "android":
            self.request_android_permissions()

    def request_android_permissions(self):
        """请求 Android 媒体访问权限"""
        perms = []
        # 根据 Android 版本决定需要哪些权限
        try:
            from android import api_version
            if api_version >= 33:  # Android 13+
                perms.append(Permission.READ_MEDIA_IMAGES)
            else:
                perms.append(Permission.READ_EXTERNAL_STORAGE)
        except:
            perms.append(Permission.READ_EXTERNAL_STORAGE)

        request_permissions(perms, self.permissions_callback)

    def permissions_callback(self, permissions, grant_results):
        if all(grant_results):
            self.ids.status_label.text = "权限已授予"
        else:
            self.ids.status_label.text = "未授予存储权限，无法选择图片"

    def show_file_chooser(self):
        """调用系统原生图片选择器"""
        filechooser.open_file(
            on_selection=self.on_file_selected,
            filters=["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp"]
        )

    @mainthread
    def on_file_selected(self, selection):
        """文件选择回调"""
        if selection:
            raw_path = str(selection[0])   # Android 上可能是 content:// URI
            self.ids.status_label.text = "正在读取图片..."
            threading.Thread(target=self._prepare_selected_file, args=(raw_path,), daemon=True).start()
        else:
            self.ids.status_label.text = "未选择任何文件"

    def _prepare_selected_file(self, raw_path):
        try:
            file_path = uri_to_file(raw_path)
            self._update_selected_file(file_path, raw_path.startswith("content://"))
        except Exception as e:
            self._update_ui_on_error(str(e))

    @mainthread
    def _update_selected_file(self, file_path, is_cache_file):
        if self.preview_cache_path and self.preview_cache_path != file_path:
            try:
                os.unlink(self.preview_cache_path)
            except OSError:
                pass

        self.selected_path = file_path
        self.preview_cache_path = file_path if is_cache_file else None
        self.ids.img_preview.source = file_path
        self.ids.img_preview.reload()
        self.ids.status_label.text = f"已选择: {os.path.basename(file_path)}"

    def start_upload(self):
        """启动后台上传"""
        if not self.selected_path:
            self.ids.status_label.text = "请先选择一张图片！"
            return

        self.ids.upload_btn.disabled = True
        self.ids.status_label.text = "正在上传..."
        threading.Thread(target=self._do_upload, daemon=True).start()

    def _do_upload(self):
        """后台线程执行上传，并回调主线程更新UI"""
        try:
            url = upload_to_lsky(self.selected_path)
            self._update_ui_on_success(url)
        except Exception as e:
            self._update_ui_on_error(str(e))

    @mainthread
    def _update_ui_on_success(self, url):
        self.ids.link_input.text = url
        self.ids.status_label.text = "上传成功！"
        self.ids.upload_btn.disabled = False

    @mainthread
    def _update_ui_on_error(self, error_msg):
        self.ids.status_label.text = f"上传失败: {error_msg}"
        self.ids.upload_btn.disabled = False

    def copy_link(self):
        """复制链接到剪贴板"""
        link = self.ids.link_input.text.strip()
        if link:
            Clipboard.copy(link)
            self.ids.status_label.text = "链接已复制"
        else:
            self.ids.status_label.text = "没有可复制的链接"


class LskyApp(App):
    def build(self):
        return ImagePublisher()


if __name__ == "__main__":
    LskyApp().run()
