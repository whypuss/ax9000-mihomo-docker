---
name: ax9000-mihomo-operator
description: "AX9000 宿主機 Mihomo 代理營運專家。結合 README 教學流程與生產環境 Config 規則，自動化執行配置同步、流量分流注入、安全脫敏與文檔備份。"
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [router, mihomo, proxy, ax9000, automation]
    related_skills: [ax9000-mihomo-management]
---

# AX9000 Mihomo 代理營運專家

本技能是 AX9000 代理環境的「全自動運行時」，基於現有生產級 README 教學與 Config 模板，實現從配置獲取到 GitHub 同步的閉環管理。

## 1. 核心職責
- **配置還原**：從 Router 獲取原始配置，執行脫敏，並注入「電視盒子 (192.168.31.39) YouTube 分流」規則。
- **文檔守護**：維護 `README.md` 的教學完整性，確保 Git 記錄中不含真實憑證。
- **運行時調度**：使用 `delegate_task` 自動檢查配置有效性，避免手動操作帶來的 OOM 或連線鎖死。

## 2. 營運流程 (自動化腳本)

### A. 同步與安全注入 (執行邏輯)
```python
# 讀取路由器 Config
# 執行脫敏 (Regex 替換 server/uuid/password/sni 為 YOUR-PLACEHOLDER)
# 注入分流規則 (SRC-IP-CIDR,192.168.31.39/32,auto)
# 同步 README.md (確保包含前置需求、SSH、Docker 安裝等教學)
# Git 提交與推送
```

### B. 故障排查工作流
若發現透明代理不生效：
1. **檢查狀態**：`ssh root@192.168.1.59 'docker ps'`
2. **重啟 mihoho**：`ssh root@192.168.1.59 'docker restart mihomo'`
3. **校驗規則**：`ssh root@192.168.1.59 'iptables -t nat -L PREROUTING -n'`

## 3. 分流規則守則
- **電視盒子 (192.168.31.39)**: 必須明確指定 `SRC-IP-CIDR` 轉向 `auto` 組。
- **其他所有設備**: 必須保持 `MATCH,DIRECT` 的兜底規則。
- **AI 站點**: 使用 `DOMAIN-KEYWORD` 保障登錄認證。

## 4. 最佳實踐 ( Pitfalls )
- **不要直接刪除文件**：若需清理配置，使用本技能的脫敏腳本，勿手動刪除生產目錄。
- **Git 狀態確認**：每次 `git push` 前，先運行 `git status` 檢查是否有未脫敏文件被加入。
- **SSH 安全**：使用 `sshpass` 或正確的 `host-key` 指定參數登入，避免觸發路由器安全鎖。
"