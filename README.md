# System Integration Quality Control

系統整合品質管制工具 - 使用 GitHub Actions 對專案進行安全掃描，產生報告並自動發布到 GitHub Pages。

## 功能

### 安全掃描
- **SSDLC 檢核** - 安全開發生命週期檢查
- **SAST 源碼掃描** - 靜態應用程式安全測試 (Semgrep)
- **弱點掃描** - 依賴套件漏洞掃描 (Trivy)
- **滲透測試** - Web 應用程式滲透測試 (OWASP ZAP + Nuclei)

### SEO/AEO 檢查
- **連結檢查** - 檢查內部/外部連結是否正常 (404 偵測)
- **Meta 標籤** - 檢查 title、description、Open Graph、Twitter Card
- **Schema 結構化資料** - 驗證 JSON-LD (WebPage、Article、Person 等)
- **SGE/AEO 標記** - 檢查 AI 搜尋引擎優化標記 (.key-answer, .key-takeaway 等)
- **E-E-A-T 信號** - 檢查專業認證、權威來源連結、作者資訊
- **Core Web Vitals** - 檢查圖片 lazy loading、尺寸宣告、preconnect 等
- **YMYL 檢查** - 健康/財務/法律內容的特殊要求

## 使用方式

### GitHub Actions

1. 進入 GitHub Repository
2. 點選 **Actions** 頁籤
3. 選擇 **Security Scanner** workflow
4. 點選 **Run workflow**
5. 填入參數：
   - **repos**: GitHub repo URLs (JSON array)
     ```json
     ["https://github.com/owner/repo1", "https://github.com/owner/repo2"]
     ```
   - **web_url**: 上線網址（選填，用於滲透測試）
   - **scan_depth**: 掃描深度 (`quick` / `standard` / `deep`)

### 本地執行

本地執行和 GitHub Actions 使用**完全相同的腳本**。

```bash
# 1. Clone 本專案
git clone https://github.com/your-org/system-integration-quality-control.git
cd system-integration-quality-control

# 2. 設定環境變數
export REPOS_JSON='["https://github.com/owner/repo"]'
export WEB_URL="https://your-site.com"  # 選填
export PAT_TOKEN="ghp_xxxxx"             # 私有 repo 需要

# 3. 執行掃描
./scripts/entrypoint.sh

# 4. 推送報告到 GitHub
git add docs/
git commit -m "Add scan report $(date '+%Y%m%d-%H%M%S')"
git push origin main
```

#### 其他執行方式

```bash
# 用參數執行
PAT_TOKEN="ghp_xxx" ./scripts/entrypoint.sh '["https://github.com/owner/repo"]' "https://site.com"

# 跳過工具安裝（已裝過）
SKIP_SETUP=true ./scripts/entrypoint.sh '["..."]' "https://..."
```

## 報告

掃描完成後，報告發布至 GitHub Pages：

```
https://{username}.github.io/{repo-name}/
```

報告包含：
- **首頁**：所有專案摘要列表
- **專案報告**：各專案詳細掃描結果
- **滲透測試報告**：Web 滲透測試結果

### 報告欄位

| 欄位 | 說明 |
|------|------|
| 專案名稱 | 從 repo URL 解析 |
| 連結 | repo / web 超連結 |
| 測試時間 | 掃描執行時間 |
| SSDLC | 通過數/總數（可點擊查看詳細） |
| SAST | 發現數量（可點擊查看詳細） |
| 弱點 | Critical/High 數量（可點擊查看詳細） |
| 滲透 | 發現數量（可點擊查看詳細） |
| 連結 | 正常/總數（可點擊查看詳細） |
| Meta | 通過數/總數（可點擊查看詳細） |
| Schema | 通過數/總數（可點擊查看詳細） |
| SGE | 通過數/總數（可點擊查看詳細） |

## 掃描深度

| 深度 | 說明 |
|------|------|
| `quick` | 僅掃描 CRITICAL/HIGH 等級漏洞 |
| `standard` | 掃描 CRITICAL/HIGH/MEDIUM 漏洞 |
| `deep` | 完整掃描含 misconfiguration |

## 設定私有專案掃描

1. 建立 GitHub Personal Access Token (PAT)
   - 前往 Settings → Developer settings → Personal access tokens
   - 建立具有 `repo` 權限的 token

2. 在 Repository Settings 新增 Secret
   - 名稱：`PAT_TOKEN`
   - 值：你的 PAT

## 工具需求

### GitHub Actions
自動安裝，無需手動設定。

### 本地執行
- **必要**：
  - `jq` - JSON 解析
  - `git` - 版本控制
  - Python 3 + pip

- **建議**：
  - Docker（用於 Trivy、OWASP ZAP）
  - Nuclei（滲透測試）

```bash
# macOS
brew install jq

# Ubuntu/Debian
apt-get install jq

# 安裝 Python 工具（會自動安裝）
pip install semgrep checkov pip-audit
```

## 目錄結構

```
.
├── .github/workflows/
│   └── security-scan.yml       # GitHub Actions workflow
├── scripts/
│   ├── entrypoint.sh           # 統一入口（Action/Local 共用）
│   ├── setup-tools.sh          # 工具安裝
│   ├── scan-all.sh             # 核心掃描邏輯
│   ├── scanners/
│   │   ├── sast.sh             # SAST 掃描 (Semgrep)
│   │   ├── vulnerability.sh    # 弱點掃描 (Trivy)
│   │   ├── ssdlc.sh            # SSDLC 檢核
│   │   ├── pentest.sh          # 滲透測試 (ZAP + Nuclei)
│   │   ├── links.sh            # 連結檢查
│   │   ├── seo.sh              # SEO 整合器
│   │   └── seo/
│   │       ├── meta.sh         # Meta 標籤檢查
│   │       ├── schema.sh       # JSON-LD Schema 驗證
│   │       ├── sge.sh          # SGE/AEO 標記檢查
│   │       ├── eeat.sh         # E-E-A-T 信號檢查
│   │       ├── cwv.sh          # Core Web Vitals 檢查
│   │       └── ymyl.sh         # YMYL 內容檢查
│   └── report/
│       ├── generate-project-report.sh
│       └── generate-index.sh
└── docs/                       # GitHub Pages 內容
    └── scans/
        └── {scan-id}/
```

## 擴充掃描器

新增掃描器只需：

1. 在 `scripts/scanners/` 建立新腳本
2. 在 `scripts/scan-all.sh` 加入呼叫
3. 在報告模板加入對應區塊

## 注意事項

1. **僅用於授權測試** - 僅掃描您有權限測試的專案和網站
2. **Web 滲透測試需謹慎** - 對外部網站進行滲透測試可能違法，請確保有書面授權
3. **私有倉庫需授權** - 掃描私有 GitHub 專案需設定 PAT_TOKEN

## License

MIT
