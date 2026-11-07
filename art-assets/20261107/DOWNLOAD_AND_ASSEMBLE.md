# 下载与恢复资产 ZIP

使用 Python 3 和 `RECEIVE_ASSETS.py`，可以下载本次归档的完整 ZIP 或二进制片段，恢复原始的 9 个 ZIP，并验证每一片和每个完整 ZIP 的大小及 SHA256。无需安装 Python 第三方库。

下载固定指向 [GitHub Release：art-assets-20261107](https://github.com/Konstantiy1453/brave-new-world/releases/tag/art-assets-20261107)。自动下载需要该 Release 及附件已经公开；草稿附件尚未公开时，可以先做本地合并验证。

## 开始下载

把 `RECEIVE_ASSETS.py` 和 `TRANSPORT_MANIFEST.json` 放在同一目录，在该目录打开 PowerShell：

```powershell
python .\RECEIVE_ASSETS.py --download
```

如果系统使用 Windows 的 Python 启动器，也可以执行：

```powershell
py -3 .\RECEIVE_ASSETS.py --download
```

只有脚本、没有清单时，`--download` 会从上述固定 Release 获取 `TRANSPORT_MANIFEST.json`。脚本会优先采用同目录清单，其次采用输出目录中的缓存清单；不会自动替换已有清单。

默认输出在脚本旁边的 `received_assets` 目录：

```text
received_assets/
  downloads/     下载的完整 ZIP、.001 等运输片段，以及未完成的 .part
  archives/      通过全部校验后恢复的原始 ZIP
```

指定另一块磁盘作为输出目录：

```powershell
python .\RECEIVE_ASSETS.py --download --output "E:\BNW_assets"
```

本次51个传输附件会还原9个原始ZIP，共约5.78GB。下载片段和恢复后的ZIP都会保留，接收约需12GB空间；再解压约10GB，建议预留至少25GB。此前失败而保留的文件还会额外占用空间。

看到 `ALL PASS` 后，将 `archives` 内9个ZIP全部解压到同一个空目录，再打开包内 `START_HERE.md`。模型和贴图的原相对目录会恢复。所有资产独立保存，尚未接入游戏。

## 只合并已有文件

将清单列出的所有下载附件放进 `<输出目录>\downloads`，保留清单中的完整文件名。例如 `...zip.001`、`...zip.002` 是 ZIP 原始字节的连续片段，不是可单独打开的 ZIP。

```powershell
python .\RECEIVE_ASSETS.py --assemble-only --output "E:\BNW_assets"
```

该模式不发起网络请求。清单默认仍在脚本同目录，也可指定：

```powershell
python .\RECEIVE_ASSETS.py --assemble-only --manifest "E:\清单\TRANSPORT_MANIFEST.json" --output "E:\BNW_assets"
```

没有指定 `--download` 时也按本地合并方式运行。已经通过校验的 ZIP 会保持原文件，不会重复覆盖。

## 中断、续传与错误处理

- 再次执行同一条命令即可继续。已验证的下载文件会跳过；未完成的下载保存在 `.part`。
- 有 `.part` 时会尝试 HTTP Range 续传。服务器返回完整内容 `200` 时，旧部分下载会另名保留，并从第 0 字节重新写入，避免错误追加。
- 每个文件最多自动尝试 3 次。网络仍有问题时脚本以非零退出码停止，保留未完成文件；稍后再次运行继续。
- 大小或 SHA256 不符的已有文件会保留为带 `.bad-时间-标识` 后缀的文件；不会直接覆盖。完整下载但校验失败的内容同样另名保留。
- `--assemble-only` 遇到缺片或坏片会停止并指出文件名。补齐正确文件，或使用 `--download`，再运行即可。
- 只有每个片段都通过校验、合并后的完整 ZIP 也通过大小和 SHA256 校验后，才会生成 `archives` 中的正式 ZIP。看到 `ALL PASS` 才表示清单中所有 ZIP 均通过。

请避免同时启动多个接收程序写入同一个输出目录。脚本保留下载片段，不会解压、执行模型文件、删除模型或自动修改游戏。

## 清单约定

`TRANSPORT_MANIFEST.json` 的 `archives` 数组依次描述原始 ZIP：

```json
{
  "archives": [
    {
      "filename": "example.zip",
      "bytes": 123,
      "sha256": "完整ZIP的64位十六进制SHA256",
      "parts": [
        {
          "name": "example.zip",
          "bytes": 123,
          "sha256": "该下载文件的64位十六进制SHA256",
          "url": "https://github.com/Konstantiy1453/brave-new-world/releases/download/art-assets-20261107/example.zip"
        }
      ]
    }
  ]
}
```

上例仅展示字段，SHA256 占位文字不能作为实际清单。直接上传的完整 ZIP 只有一个同名 part；分段 ZIP 则使用 `原ZIP名.001`、`.002` 等有序条目。接收程序拒绝包含目录、路径穿越、重复文件名或其他仓库/Release 下载地址的清单。GitHub 下载链接正常跳转到其 HTTPS 资产 CDN 时可以继续下载。
