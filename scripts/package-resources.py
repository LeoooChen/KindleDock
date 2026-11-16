#!/usr/bin/env python3
from pathlib import Path
import html,sys
root=Path(__file__).resolve().parent.parent
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
style='<meta charset="utf-8"><style>body{font:15px -apple-system,BlinkMacSystemFont,sans-serif;color:#17313b;padding:22px;line-height:1.55}h1{font-size:27px}h2{font-size:18px}pre{white-space:pre-wrap;font:11px Menlo,monospace}li{margin:10px 0}.tag{color:#307e78}</style>'
(out/'Welcome.html').write_text(style+'''<h1>KindleDock</h1><p class="tag">Your Kindle, back in Finder. / 让 Kindle 回到 Finder。</p>
<p>Install the menu-bar app and the required macFUSE runtime together. No Homebrew or Amazon account is needed.</p>
<p>安装菜单栏应用及所需运行组件，不需要 Homebrew 或亚马逊账号。已有 macFUSE 5.5 或更新版本时，安装器会保留它。</p>
<ul><li>Apple Silicon · macOS 15.4+</li><li>Connect by USB; supported Kindle storage appears in Finder automatically.</li><li>首次使用需授权 macFUSE 文件系统扩展，不能由安装器代为同意。</li></ul>''')
(out/'Conclusion.html').write_text(style+'''<h1>You're ready to connect.</h1><p>KindleDock is in Applications and opens in your menu bar.</p>
<ol><li>If prompted, enable macFUSE under System Settings → General → Login Items &amp; Extensions → File System Extensions.</li><li>Connect and unlock your Kindle. Open Finder → Locations → Kindle.</li><li>If another transfer app is running, quit it and choose Mount in KindleDock.</li></ol>
<h2>中文说明</h2><p>如提示未授权，请在“系统设置 → 通用 → 登录项与扩展 → 文件系统扩展”中启用 macFUSE。然后连接并解锁 Kindle，Finder 侧栏“位置”会出现 Kindle。</p>
<p>No Recovery Mode security changes are needed. 无需降低安全性或开启内核扩展。</p>
<p>Finder eject releases the Mac's virtual volume. To read while charging, also tap Disconnect on the Kindle screen.</p>''')
parts=[style+'<h1>Licenses / 许可说明</h1><p>KindleDock is free. Its MIT license and the separate macFUSE license follow. Bundled libmtp and libusb use LGPL-2.1-or-later; their full license texts are included inside the app.</p>']
for label,path in [('KindleDock — MIT',root/'LICENSE'),('macFUSE — separate vendor license',root/'packaging/MACFUSE-LICENSE.txt')]:
    parts.append('<h2>'+label+'</h2><pre>'+html.escape(path.read_text())+'</pre>')
(out/'License.html').write_text(''.join(parts))
