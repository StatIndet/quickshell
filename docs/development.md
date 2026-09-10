# 开发流程

先安装外部 QML 运行时依赖 M3Shapes（Arch：`qt6-m3shapes-git`）。
Clavis 不编译或安装它；`build/qml` 继续只为 Clavis 原生模块提供开发导入路径。
从旧 checkout 迁移时，清理旧构建目录中的 `build/qml/M3Shapes`，避免遮蔽系统模块；
不要向该目录复制系统模块或创建同名软链接。

源码开发使用 Quickshell 的 XDG 配置优先级和 CMake 生成的 import tree：

```bash
mkdir -p ~/.config/quickshell
ln -sfn ~/Projects/clavis ~/.config/quickshell/clavis

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build

QML_IMPORT_PATH="$PWD/build/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" key shell
```

源码目录优先于 `/etc/xdg/quickshell/clavis`。QML 保存后可热重载；C++ plugin 需要
重新构建并重新加载 Shell。Shell/CLI 日志由各自工具负责，不在文档或脚本中使用
`nohup`、`disown` 或丢弃到 `/dev/null`。

正式安装由发行版打包流程负责；本仓库默认只构建和测试源码，不创建运行时版本快照。
