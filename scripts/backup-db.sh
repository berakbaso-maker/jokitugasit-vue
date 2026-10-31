#!/usr/bin/env bash
# =============================================================================
# backup-db.sh — backup harian database JokiTugasIT (Supabase Singapore)
#
# Kenapa ada: project Supabase lama (dkiwuayxsvzoapgxbxhd) pernah terhapus dan
# SELURUH data order hilang tanpa backup. Skrip ini mencegah itu terulang.
#
# Yang dilakukan:
#   1. pg_dump seluruh schema public (plain SQL, siap di-restore dengan psql)
#   2. verifikasi hasil dump (gzip valid, ukuran wajar, tabel inti ada,
#      jumlah baris cocok dengan database)
#   3. kirim ke channel Telegram penyimpanan (offsite, bukan cuma di laptop)
#   4. hapus dump lokal lebih tua dari RETENSI_HARI
#
# Cara restore (ke project Supabase baru / kosong):
#   gunzip -c ~/backups/jokitugasit/jokitugasit-YYYYmmdd-HHMM.sql.gz \
#     | psql "postgresql://postgres.<ref>:<password>@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres"
#
# Pakai:
#   ./scripts/backup-db.sh              # jalankan backup (senyap kalau sukses)
#   ./scripts/backup-db.sh --laporan    # selalu cetak ringkasan
#   RETENSI_HARI=30 ./scripts/backup-db.sh
# =============================================================================
set -euo pipefail

RETENSI_HARI="${RETENSI_HARI:-14}"
TUJUAN="${TUJUAN:-$HOME/backups/jokitugasit}"
ENV_SUPABASE="${ENV_SUPABASE:-$HOME/.hermes/secrets/jokitugasit-supabase-sg.env}"
TG_CLOUD="${TG_CLOUD:-$HOME/.hermes/scripts/tg_cloud.sh}"
LAPORAN=0
[[ "${1:-}" == "--laporan" ]] && LAPORAN=1

gagal() { echo "BACKUP GAGAL: $*" >&2; exit 1; }

[[ -f "$ENV_SUPABASE" ]] || gagal "file kredensial tidak ada: $ENV_SUPABASE"
# shellcheck disable=SC1090
set -a; source "$ENV_SUPABASE"; set +a

# Selalu lewat pooler: host `db.<ref>.supabase.co` hanya IPv6 dan sering
# tidak bisa di-resolve dari mesin ini (pg_dump gagal "could not translate").
export PGHOST="${PGHOST_POOLER:-aws-0-ap-southeast-1.pooler.supabase.com}"
export PGPORT="${PGPORT:-5432}"
export PGDATABASE="${PGDATABASE:-postgres}"
# Pooler butuh user ber-tenant (`postgres.<ref>`). File env menyimpan PGUSER=postgres
# untuk koneksi langsung, dan itu ditolak pooler: "(ENOIDENTIFIER) no tenant identifier".
export PGUSER="postgres.$SUPABASE_PROJECT_REF"
export PGSSLMODE="${PGSSLMODE:-require}"
export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-20}"

# pg_dump harus >= versi server (Supabase PG 17). Homebrew menaruh pg_dump 14
# di PATH, jadi kita cari yang 17 dulu supaya tidak "server version mismatch".
PG_DUMP_BIN="${PG_DUMP_BIN:-}"
if [[ -z "$PG_DUMP_BIN" ]]; then
  for kandidat in /opt/homebrew/opt/postgresql@17/bin/pg_dump /usr/local/opt/postgresql@17/bin/pg_dump; do
    [[ -x "$kandidat" ]] && { PG_DUMP_BIN="$kandidat"; break; }
  done
  PG_DUMP_BIN="${PG_DUMP_BIN:-pg_dump}"
fi
PG_DUMP_MAYOR=$("$PG_DUMP_BIN" --version | grep -oE '[0-9]+' | head -1)
(( PG_DUMP_MAYOR >= 17 )) || gagal "pg_dump terlalu tua ($("$PG_DUMP_BIN" --version)) — server PG 17. Set PG_DUMP_BIN=/path/pg_dump-17"

mkdir -p "$TUJUAN"
CAP="$(date +%Y%m%d-%H%M)"
NAMA="jokitugasit-$CAP.sql.gz"
FILE="$TUJUAN/$NAMA"
SEMENTARA="$FILE.part"

# ---------- 1. dump ----------
"$PG_DUMP_BIN" --no-owner --no-privileges --clean --if-exists \
  | gzip -9 > "$SEMENTARA" || { rm -f "$SEMENTARA"; gagal "pg_dump error"; }
mv "$SEMENTARA" "$FILE"

# ---------- 2. verifikasi ----------
gzip -t "$FILE" 2>/dev/null || gagal "file gzip rusak"
UKURAN=$(wc -c < "$FILE" | tr -d ' ')
(( UKURAN > 20000 )) || gagal "dump terlalu kecil ($UKURAN byte) — curiga kosong/gagal"

# CATATAN: jangan `gunzip -c file | grep -q` di skrip ber-`pipefail`.
# grep -q berhenti di baris pertama yang cocok -> gunzip kena SIGPIPE ->
# pipeline dianggap gagal (141) walau tabelnya ADA. Pakai process substitution.
for tabel in requests payments commissions partners profiles request_status_notifications; do
  if ! grep -q "CREATE TABLE public.$tabel" <(gunzip -c "$FILE"); then
    gagal "tabel inti $tabel tidak ada di dump"
  fi
done

# pg_dump menutup file dengan penanda ini. Kalau tidak ada, dump terpotong
# (koneksi putus di tengah) walau gzip-nya tetap valid.
if ! grep -q "PostgreSQL database dump complete" <(gunzip -c "$FILE"); then
  gagal "dump tidak lengkap (penanda 'dump complete' tidak ada)"
fi

JUMLAH_TABEL=$(grep -c "^CREATE TABLE public\." <(gunzip -c "$FILE"))
(( JUMLAH_TABEL >= 30 )) || gagal "hanya $JUMLAH_TABEL tabel di dump (harusnya >= 30)"

# jumlah baris harus sama dengan database (deteksi dump terpotong)
CEK_TABEL=(requests payments partners)
for tabel in "${CEK_TABEL[@]}"; do
  DB_N=$(psql -tA -c "select count(*) from public.$tabel" 2>/dev/null | tr -d ' ')
  # Hitung baris data di blok COPY tabel ini. Dibandingkan sebagai string
  # (index/==), bukan regex, supaya tidak terjebak escaping backslash.
  DUMP_N=$(awk -v t="$tabel" '
    {
      if (!dalam && index($0, "COPY public." t " ") == 1) { dalam=1; next }
      if (dalam && $0 == "\\.") { dalam=0; next }
      if (dalam) n++
    }
    END {print n+0}' <(gunzip -c "$FILE"))
  [[ "$DB_N" == "$DUMP_N" ]] || gagal "jumlah baris $tabel beda: db=$DB_N dump=$DUMP_N"
done

# ---------- 3. kirim offsite ----------
OFFSITE="lokal"
if [[ -x "$TG_CLOUD" ]]; then
  if "$TG_CLOUD" storage "$FILE" --caption "Backup JokiTugasIT $CAP ($(du -h "$FILE" | cut -f1))" >/dev/null 2>&1; then
    OFFSITE="telegram"
  else
    OFFSITE="GAGAL-telegram"
  fi
fi

# ---------- 4. retensi ----------
DIBUANG=$(find "$TUJUAN" -name 'jokitugasit-*.sql.gz' -type f -mtime +"$RETENSI_HARI" -print -delete | wc -l | tr -d ' ')

RINGKASAN="backup ok: $NAMA ($(du -h "$FILE" | cut -f1)) | offsite=$OFFSITE | dibuang=$DIBUANG | retensi=${RETENSI_HARI}h"

# Senyap kalau sukses (supaya cron tidak berisik), tapi:
#   - --laporan  -> selalu cetak
#   - Senin      -> cetak (heartbeat mingguan, bukti cron masih hidup)
#   - offsite gagal -> cetak sebagai peringatan
if (( LAPORAN )) || [[ "$(date +%u)" == "1" ]] || [[ "$OFFSITE" == "GAGAL-telegram" ]]; then
  echo "$RINGKASAN"
fi
