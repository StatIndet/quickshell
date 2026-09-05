# CMake 安装布局

Clavis Shell 使用标准 CMake 安装，不维护应用内版本管理器：

```text
/etc/xdg/quickshell/clavis/       QML 源码、assets、scripts、matugen
/lib/qt6/qml/Clavis/              Clavis 原生 QML modules
/lib/qt6/qml/M3Shapes/            Material 3 shapes module
/usr/lib/systemd/user/            Clavis 自己的 clavis-shell.service
```

路径通过 `CMAKE_INSTALL_PREFIX`、`CMAKE_INSTALL_LIBDIR`、
`CLAVIS_QML_BUILD_DIR`、`CLAVIS_QML_INSTALL_DIR`、
`CLAVIS_CONFIG_INSTALL_DIR` 和 `CLAVIS_SYSTEMD_USER_INSTALL_DIR` 覆盖；安装支持
`DESTDIR`，CMake 文件不调用 sudo。`clavis-clipboard.service` 不属于这个仓库，
由 key-cli wheel 安装到同一个标准 systemd user-unit 目录。

用户 XDG 配置目录由 Quickshell 自己选择：`~/.config/quickshell/clavis` 存在时优先，
否则回退到 `/etc/xdg/quickshell/clavis`。开发 import tree 位于 `build/qml`，不复制
到系统 Qt import 根。

Matugen 内置 registry 与模板继续由 `core/CMakeLists.txt` 安装至
`${CLAVIS_CONFIG_INSTALL_DIR}/matugen/`。QML 通过 `Paths.builtinMatugenDir`
（`Quickshell.shellDir + "/matugen"`），脚本通过自身 `scripts/lib/` 相对于 shell root
的位置定位资源，因此 source-tree 与系统安装使用相同相对布局，不依赖旧 `defaults/`
路径。用户 registry 是独立的 `$CLAVIS_CONFIG_HOME/matugen/`；安装不会创建或写入
任何用户 HOME，也不会复制内置模板作为用户 defaults。新增脚本与 jq 解析文件由现有
scripts 目录安装规则自动包含，无需新的原生 plugin 或 Python 运行时。
