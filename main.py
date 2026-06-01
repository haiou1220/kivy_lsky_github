import os
import threading
from pathlib import Path
import uuid

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.clock import mainthread
from kivy.properties import StringProperty
from kivy import platform

FONT_PATH = Path(__file__).resolve().with_name("wqy-microhei.ttc")


def _android_permission(name, fallback):
    from android.permissions import Permission

    return getattr(Permission, name, fallback)


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
    try:
        mime_type = content_resolver.getType(parcelable_uri)
    except Exception:
        mime_type = None

    return None, mime_type


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
        from jnius import autoclass, jarray

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


def load_lsky_config():
    try:
        from lsky_config import LSKY_API_URL, LSKY_TOKEN
    except ImportError as exc:
        raise Exception("缺少私有配置文件 lsky_config.py，请填写图床地址和 token 后重新打包") from exc

    if not LSKY_API_URL or not LSKY_TOKEN:
        raise Exception("lsky_config.py 中的 LSKY_API_URL 或 LSKY_TOKEN 为空")

    return LSKY_API_URL, LSKY_TOKEN


def upload_to_lsky(image_path_or_uri: str) -> str:
    """上传图片到兰空图床，支持 Android content URI，返回图片直链"""
    import requests

    api_url, token = load_lsky_config()

    # 如果是 URI，先转为临时文件
    file_path = uri_to_file(image_path_or_uri)

    headers = {
        "Authorization": token,
        "Accept": "application/json",
    }
    with open(file_path, "rb") as f:
        files = {"file": (Path(file_path).name, f, "image/*")}
        resp = requests.post(api_url, headers=headers, files=files, timeout=30)

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
        self.selected_cache_path = None

    def request_android_permissions(self):
        """请求 Android 媒体访问权限"""
        from android.permissions import request_permissions

        perms = []
        # 根据 Android 版本决定需要哪些权限
        try:
            from android import api_version
            version = api_version() if callable(api_version) else api_version
            if version >= 33:  # Android 13+
                perms.append(_android_permission("READ_MEDIA_IMAGES", "android.permission.READ_MEDIA_IMAGES"))
            else:
                perms.append(_android_permission("READ_EXTERNAL_STORAGE", "android.permission.READ_EXTERNAL_STORAGE"))
        except:
            perms.append(_android_permission("READ_EXTERNAL_STORAGE", "android.permission.READ_EXTERNAL_STORAGE"))

        try:
            request_permissions(perms, self.permissions_callback)
        except Exception as exc:
            self.ids.status_label.text = f"权限请求失败: {exc}"

    def permissions_callback(self, permissions, grant_results):
        if all(grant_results):
            self.ids.status_label.text = "权限已授予"
        else:
            self.ids.status_label.text = "未授予存储权限，无法选择图片"

    def show_file_chooser(self):
        """调用系统原生图片选择器"""
        try:
            from plyer import filechooser

            filechooser.open_file(
                on_selection=self.on_file_selected,
                filters=["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp"]
            )
        except Exception as exc:
            self.ids.status_label.text = f"无法打开文件选择器: {exc}"

    @mainthread
    def on_file_selected(self, selection):
        """文件选择回调"""
        if selection:
            raw_path = str(selection[0])   # Android 上可能是 content:// URI
            self._remove_cached_file(self.selected_cache_path)
            self.selected_cache_path = None
            self.selected_path = raw_path
            self.ids.img_preview.source = ""
            self.ids.img_preview.texture = None
            self.ids.status_label.text = f"已选择: {self._display_selected_name(raw_path)}"
        else:
            self.ids.status_label.text = "未选择任何文件"

    def _display_selected_name(self, raw_path):
        if raw_path.startswith("content://"):
            return "系统相册图片"
        return os.path.basename(raw_path)

    def start_upload(self):
        """启动后台上传"""
        if not self.selected_path:
            self.ids.status_label.text = "请先选择一张图片！"
            return

        self.ids.upload_btn.disabled = True
        self.ids.status_label.text = "正在准备图片..."

        try:
            upload_path = self._prepare_upload_path(self.selected_path)
        except Exception as e:
            self._update_ui_on_error(str(e))
            return

        self.ids.status_label.text = "正在上传..."
        threading.Thread(target=self._do_upload, args=(upload_path,), daemon=True).start()

    def _prepare_upload_path(self, selected_path):
        if not selected_path.startswith("content://"):
            return selected_path

        cache_path = uri_to_file(selected_path)
        self._remove_cached_file(self.selected_cache_path, keep={cache_path})
        self.selected_cache_path = cache_path
        return cache_path

    def _do_upload(self, upload_path):
        """后台线程执行上传，并回调主线程更新UI"""
        try:
            url = upload_to_lsky(upload_path)
            self._update_ui_on_success(url)
        except Exception as e:
            self._update_ui_on_error(str(e))

    def _remove_cached_file(self, path, keep=None):
        if not path or (keep and path in keep):
            return

        try:
            os.unlink(path)
        except OSError:
            pass

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
            from kivy.core.clipboard import Clipboard

            Clipboard.copy(link)
            self.ids.status_label.text = "链接已复制"
        else:
            self.ids.status_label.text = "没有可复制的链接"


class LskyApp(App):
    font_path = StringProperty("")

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if FONT_PATH.exists():
            self.font_path = str(FONT_PATH)

    def build(self):
        return ImagePublisher()


if __name__ == "__main__":
    LskyApp().run()
