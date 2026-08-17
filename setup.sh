#!/usr/bin/env bash
# my-stm 專案在新機器上的還原腳本
# 用法: ./setup.sh /path/to/new/project/root
#
# 這個腳本會：
#   1. clone 4 個 layer repo 並 checkout 到與原機器完全相同的 commit
#   2. 用 poky/oe-init-build-env 產生預設 build/conf/
#   3. 用 bblayers.conf.template（替換路徑）覆蓋預設的 bblayers.conf
#   4. 把自訂設定 append 到 local.conf
#   5. 複製 .claude/settings.local.json
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "用法: $0 <新機器上的專案根目錄，例如 /home/user/my-stm>" >&2
  exit 1
fi

ROOT="$(realpath -m "$1")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$ROOT"

clone_at() {
  local url="$1" dir="$2" commit="$3"
  if [ -d "$ROOT/$dir/.git" ]; then
    echo "[skip] $dir 已存在，略過 clone"
  else
    git clone "$url" "$ROOT/$dir"
  fi
  git -C "$ROOT/$dir" checkout "$commit"
}

echo "== 1/4 clone poky =="
clone_at "https://git.yoctoproject.org/poky" "poky" "6b7474f7ca29076d28df81a49feec6311fa18202"

echo "== 2/4 clone meta-openembedded =="
clone_at "https://github.com/openembedded/meta-openembedded" "meta-openembedded" "29a044218285fdc7fcdd63d5f0929cb3a27b6fed"

echo "== 3/4 clone meta-st-openstlinux =="
clone_at "https://github.com/STMicroelectronics/meta-st-openstlinux" "meta-st-openstlinux" "b0316f706bcf34e8449d43aba3c630030f2cc366"

echo "== 4/4 clone meta-st-stm32mp =="
clone_at "https://github.com/stmicroelectronics/meta-st-stm32mp" "meta-st-stm32mp" "49046b2a0ad4dc29117025c94838b9befff86f23"

echo "== 產生 build/conf 預設檔（透過 oe-init-build-env） =="
if [ ! -f "$ROOT/build/conf/local.conf" ]; then
  bash -c "cd '$ROOT' && source poky/oe-init-build-env build"
fi

echo "== 套用 bblayers.conf（替換為新機器路徑 $ROOT） =="
sed "s#__PROJECT_ROOT__#$ROOT#g" "$SCRIPT_DIR/bblayers.conf.template" > "$ROOT/build/conf/bblayers.conf"

echo "== 附加自訂 local.conf 設定 =="
if ! grep -q "STM32MP215F-DK custom settings" "$ROOT/build/conf/local.conf"; then
  cat "$SCRIPT_DIR/local.conf.custom" >> "$ROOT/build/conf/local.conf"
fi

echo "== 複製 Claude Code 專案設定 =="
mkdir -p "$ROOT/.claude"
cp "$SCRIPT_DIR/settings.local.json" "$ROOT/.claude/settings.local.json"

echo ""
echo "完成。接下來："
echo "  cd $ROOT"
echo "  source poky/oe-init-build-env build"
echo "  bitbake st-image-weston"
