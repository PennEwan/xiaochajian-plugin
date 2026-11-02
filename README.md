# CDK 充值 · Codex 插件

Windows 上的 Codex 插件：侧边栏打开一个小窗口，粘贴卡密即可完成充值。

> 仅支持 **Windows 10/11**。macOS 暂不支持。

## 让 AI 帮你装（一句话）

把下面这句发给 Codex / 任何能执行命令的助手：

> 帮我装这个 Codex 插件：https://github.com/PennEwan/xiaochajian-plugin

助手会读本仓库的 `AGENTS.md`，自己执行 `marketplace add` + `plugin add`，装完提示你重启 Codex。

## 自己装（两条命令）

```bash
codex plugin marketplace add PennEwan/xiaochajian-plugin
codex plugin add codex-native-assist@cdk-native
```

装完**完全退出 Codex 再打开**，侧边栏出现「CDK 充值」。

## 没有 Codex CLI（桌面版用户）

```powershell
irm https://raw.githubusercontent.com/PennEwan/xiaochajian-plugin/main/install.ps1 | iex
```

GitHub 打不开时用备用：

```powershell
irm https://fastly.jsdelivr.net/gh/PennEwan/xiaochajian-plugin@main/install.ps1 | iex
```

## 使用

点侧边栏「CDK 充值」→ 粘贴卡密（Ctrl+V）→ 点「一键充值」。

首次约 10–20 秒（后台会开一次浏览器读取登录态），之后再充 1 秒内。

## 升级

重跑一次安装命令即可（会覆盖旧版本）。

## 排错

| 现象 | 处理 |
|---|---|
| 看不到「CDK 充值」 | 完全退出 Codex（含托盘）再打开 |
| 提示「读取登录状态失败」 | 点窗口里的链接，复制页面内容，粘到「手动粘贴登录信息」 |
| 提示「使用中 / 已使用」 | 卡密被占用或已充过，换一张未使用的卡 |
| 其他 | 跑 `irm https://raw.githubusercontent.com/PennEwan/xiaochajian-plugin/main/diag.ps1 \| iex` 把输出发给客服 |