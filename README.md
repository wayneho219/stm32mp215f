# my-stm 專案交接文件

產生時間：2026-08-17　原機器路徑：`/home/wayne/my-stm`

## 1. 專案概觀

這是一個 Yocto/OpenEmbedded 建置環境，目標板卡為 **STM32MP215F-DK**。

| 項目 | 值 |
|---|---|
| Yocto 版本代號 | scarthgap |
| DISTRO | openstlinux-weston |
| MACHINE | stm32mp21-disco |
| INIT_MANAGER | systemd |
| 平常編的 image | `st-image-weston`（在 `tmp-glibc/deploy/images/stm32mp21-disco/` 有找到對應的 rootfs 產物） |

專案由 4 個 git layer repo（`poky`、`meta-openembedded`、`meta-st-openstlinux`、`meta-st-stm32mp`）+ 一個 `build/` 建置目錄組成，`.claude/` 底下有 Claude Code 的專案權限設定。

## 2. 搬遷策略：只搬設定檔，不搬快取

`build/` 底下各子目錄大小（原機器實測）：

| 目錄 | 大小 | 搬遷？ | 原因 |
|---|---|---|---|
| `build/tmp-glibc/` | 94G | 否 | 建置暫存/輸出，可重新產生 |
| `build/downloads/` | 10G | 否 | 原始碼下載快取，新機器會重新下載 |
| `build/sstate-cache/` | 5.3G | 否 | 共享狀態快取，新機器會重新編譯產生 |
| `build/cache/` | 2.0M | 否 | bitbake parse cache，重新產生即可 |
| `build/conf/local.conf`（自訂 4 行） | 極小 | **是** | 板卡/發行版設定，見 `local.conf.custom` |
| `build/conf/bblayers.conf` | 極小 | **是（需改路徑）** | 內含絕對路徑，新機器路徑不同必須替換 |
| 4 個 layer repo（poky 等） | 共約 865M | 否，改用 git clone | 皆為乾淨 git repo，重新 clone 更乾淨 |
| `.claude/settings.local.json` | 極小 | 是 | Claude Code 權限設定，選用但建議帶過去 |

因為新機器路徑會跟原本的 `/home/wayne/my-stm` 不同，`bblayers.conf` 裡寫死的絕對路徑必須修改——這件事已經由 `setup.sh` 自動處理。

## 3. 這個 `handoff/` 資料夾裡有什麼

| 檔案 | 用途 |
|---|---|
| `README.md` | 本文件 |
| `repo-manifest.txt` | 4 個 layer repo 的 remote URL + branch + 確切 commit hash |
| `local.conf.custom` | 原機器 `local.conf` 檔尾的自訂 4 行（MACHINE/DISTRO/INIT_MANAGER） |
| `bblayers.conf.template` | 完整 `bblayers.conf`，路徑用 `__PROJECT_ROOT__` 佔位符 |
| `settings.local.json` | 原機器 `.claude/settings.local.json` 的複本 |
| `setup.sh` | 一鍵還原腳本，見下方步驟 |

**只需要把整個 `handoff/` 資料夾**（不到 5KB）複製到新機器即可，不需要搬其他任何東西。

## 4. 新機器操作步驟

### 4.1 前置需求
- 新機器需能連上網路（要 git clone Yocto/ST 的原始 repo）
- 建議至少保留 **150GB** 以上可用磁碟空間（原機器單是 `tmp-glibc` 就用掉 94G，從零開始 build 會重新產生類似規模的暫存資料）
- Host 端套件需求（gcc/python3/chrpath/diffstat 等 Yocto build 依賴套件），請依 Yocto Project 官方文件或 ST OpenSTLinux Getting Started 文件安裝，這裡未附上套件清單以免與你實際使用的 release 版本兜不起來

### 4.2 還原專案

```bash
# 把 handoff/ 資料夾複製到新機器後，執行：
cd /path/to/handoff
./setup.sh /home/<user>/my-stm    # 換成你在新機器上要放的路徑
```

腳本會依序：
1. clone `poky`、`meta-openembedded`、`meta-st-openstlinux`、`meta-st-stm32mp` 並 checkout 到 `repo-manifest.txt` 記錄的確切 commit（不受 origin 分支後續更新影響，版本與原機器完全一致）
2. `source poky/oe-init-build-env build` 產生預設 `build/conf/`
3. 用替換過路徑的 `bblayers.conf.template` 覆蓋預設 `bblayers.conf`
4. 把 `local.conf.custom` 附加到 `local.conf`
5. 複製 `.claude/settings.local.json` 到新專案的 `.claude/`

### 4.3 驗證

```bash
cd /home/<user>/my-stm
source poky/oe-init-build-env build
bitbake-layers show-layers        # 確認 4 個 layer 都有列出，路徑正確
bitbake st-image-weston           # 開始建置（第一次會重新下載原始碼，耗時較久）
```

## 5. 注意事項

- 4 個 layer repo 在原機器上 `git status` 皆為乾淨（無未提交修改、無 local patch），因此直接用 `repo-manifest.txt` 記錄的 commit 重新 clone 即可完整重現，不需要額外搬 `.git` 歷史。
- 原機器 `local.conf` 未設定 `ACCEPT_EULA` / `LICENSE_FLAGS_ACCEPTED`，若新機器建置時因授權要求中斷，屬於正常情況，依畫面提示處理即可。
- 若之後想加速新機器的第一次 build，可以另外把原機器的 `build/downloads/`（10G）和 `build/sstate-cache/`（5.3G）用 rsync 或隨身碟搬過去，放到新機器對應的 `build/downloads/`、`build/sstate-cache/` 底下即可，非必要步驟，不在這次交接範圍內。
