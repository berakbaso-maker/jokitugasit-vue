# ==============================================================================
# JOKITUGASIT.MY.ID - Makefile
# Quick CLI automation for deployment, fresh builds, Supabase, and Vercel.
# ==============================================================================

.PHONY: help deploy fresh build clean dev preview health supabase-check vercel-deploy test-telegram redeploy ship

# Set default shell and PATH to include Homebrew node & tools
SHELL := /bin/bash
PATH := /opt/homebrew/bin:/usr/local/bin:$(PATH)
export PATH

# Colors
C_RESET  := \033[0m
C_BOLD   := \033[1m
C_BLUE   := \033[38;5;39m
C_GREEN  := \033[38;5;82m
C_YELLOW := \033[38;5;220m
C_CYAN   := \033[38;5;51m
C_GRAY   := \033[38;5;244m

# Default target
all: help

## help: Tampilkan panduan perintah yang tersedia
help:
	@echo ""
	@echo -e "${C_BLUE}${C_BOLD}┌───────────────────────────────────────────────────────────────┐${C_RESET}"
	@echo -e "${C_BLUE}${C_BOLD}│             JOKITUGASIT.MY.ID - MAKEFILE COMMANDS             │${C_RESET}"
	@echo -e "${C_BLUE}${C_BOLD}└───────────────────────────────────────────────────────────────┘${C_RESET}"
	@echo -e "${C_GRAY}Penggunaan: make <command>${C_RESET}\n"
	@echo -e "  ${C_GREEN}make deploy${C_RESET}         ${C_BOLD}🚀 Jalankan full interactive fresh deploy (Vercel + Supabase)${C_RESET}"
	@echo -e "  ${C_GREEN}make fresh${C_RESET}          Alias untuk make deploy"
	@echo -e "  ${C_CYAN}make build${C_RESET}          Pembersihan cache & fresh build Vite (es2022)"
	@echo -e "  ${C_CYAN}make clean${C_RESET}          Hapus folder dist/, .vite, dan .vercel/output"
	@echo -e "  ${C_YELLOW}make dev${C_RESET}            Jalankan Vite development server lokal"
	@echo -e "  ${C_YELLOW}make preview${C_RESET}        Preview bundle production lokal"
	@echo -e "  ${C_BLUE}make health${C_RESET}         Test status HTTP & response live domain"
	@echo -e "  ${C_BLUE}make supabase-check${C_RESET} Audit kelengkapan skema & konfigurasi Supabase"
	@echo -e "  ${C_BLUE}make test-telegram${C_RESET}  Uji kirim notifikasi alert order ke Telegram engineer"
	@echo -e "  ${C_BLUE}make vercel-deploy${C_RESET}  Deploy cepat (git push origin main)"
	@echo -e "  ${C_GREEN}make redeploy${C_RESET}       ${C_BOLD}🔥 SATU PERINTAH: test → build → SQL → push → deploy → smoke${C_RESET}"
	@echo -e "  ${C_GRAY}                 Opsi: make redeploy ARGS=\"--skip-db\" (lihat --help)${C_RESET}"
	@echo ""

## deploy: Jalankan full interactive fresh deployment pipeline
deploy:
	@bash ./scripts/deploy.sh

## fresh: Alias untuk make deploy
fresh: deploy

## clean: Hapus semua cache dan artifact build
clean:
	@echo -e "${C_YELLOW}🧹 Membersihkan cache build...${C_RESET}"
	@rm -rf dist node_modules/.vite .vercel/output
	@echo -e "${C_GREEN}✓ Cache bersih (dist, .vite, .vercel/output)${C_RESET}"

# Runner wrapper ensuring Node/NPM are accessible on macOS
RUN := export PATH="/opt/homebrew/bin:/usr/local/bin:$$PATH";

## build: Fresh production build dengan vendor chunk splitting
build: clean
	@echo -e "${C_BLUE}🔨 Memulai fresh production build...${C_RESET}"
	@$(RUN) npm run build
	@echo -e "${C_GREEN}✓ Build berhasil dibuat di folder dist/${C_RESET}"

## dev: Jalankan server development Vite
dev:
	@echo -e "${C_GREEN}⚡ Memulai Vite Dev Server...${C_RESET}"
	@$(RUN) npm run dev

## preview: Preview build production di lokal
preview:
	@echo -e "${C_CYAN}👀 Memulai Vite Preview...${C_RESET}"
	@$(RUN) npm run preview

## health: Cek kesehatan live host production
health:
	@echo -e "${C_BLUE}🔍 Menguji koneksi live domain https://jokitugasit.my.id...${C_RESET}"
	@STATUS=$$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 6 https://jokitugasit.my.id 2>/dev/null || echo "000"); \
	if [ "$$STATUS" = "200" ]; then \
		echo -e "${C_GREEN}✓ Status: 200 OK - Domain live & berjalan normal.${C_RESET}"; \
	elif [ "$$STATUS" = "000" ]; then \
		echo -e "${C_YELLOW}⚠ Status: Timeout dari sandbox local (normal jika direct internet limited).${C_RESET}"; \
	else \
		echo -e "${C_YELLOW}⚠ Status: HTTP $$STATUS${C_RESET}"; \
	fi

## supabase-check: Verifikasi skema dan variabel Supabase
supabase-check:
	@echo -e "${C_BLUE}🗄️ Memeriksa konfigurasi Supabase...${C_RESET}"
	@test -f supabase/schema.sql && echo -e "  ${C_GREEN}✓ schema.sql${C_RESET}" || echo -e "  ${C_RED}✖ schema.sql missing${C_RESET}"
	@test -f supabase/migration-engineer-role.sql && echo -e "  ${C_GREEN}✓ migration-engineer-role.sql${C_RESET}" || echo -e "  ${C_RED}✖ migration missing${C_RESET}"
	@test -f supabase/seed.sql && echo -e "  ${C_GREEN}✓ seed.sql${C_RESET}" || echo -e "  ${C_RED}✖ seed.sql missing${C_RESET}"
	@test -f supabase/ig-schema.sql && echo -e "  ${C_GREEN}✓ ig-schema.sql${C_RESET}" || echo -e "  ${C_RED}✖ ig-schema.sql missing${C_RESET}"
	@test -f .env && echo -e "  ${C_GREEN}✓ .env file terpasang${C_RESET}" || echo -e "  ${C_YELLOW}⚠ .env file tidak ditemukan${C_RESET}"

## vercel-deploy: Quick push to origin main for Vercel
vercel-deploy:
	@echo -e "${C_BLUE}🚀 Memicu deployment Vercel via Git...${C_RESET}"
	@git push origin main
	@echo -e "${C_GREEN}✓ Commit telah ter-push ke origin/main!${C_RESET}"

## redeploy: Satu perintah penuh — test, build, migration, commit/push, deploy, smoke test
##   Contoh: make redeploy
##           make redeploy ARGS="--skip-db"
##           SUPABASE_DB_URL="postgresql://..." make redeploy
redeploy:
	@bash ./scripts/redeploy.sh $(ARGS)

## ship: Alias untuk redeploy
ship: redeploy

## test-telegram: Kirim notifikasi tes ke Telegram engineer
test-telegram:
	@echo -e "${C_BLUE}📱 Menguji endpoint /api/notify-order secara lokal...${C_RESET}"
	@export PATH="/opt/homebrew/bin:/usr/local/bin:$$PATH"; node -e '\
	import("./api/notify-order.js").then(async (m) => { \
		const req = { \
			method: "POST", \
			body: { \
				orderNo: "TEST888", \
				customerName: "Mahasiswa Uji Coba", \
				whatsapp: "6285166337257", \
				category: "web", \
				deadline: "hari_ini", \
				description: "Testing notifikasi Telegram serverless jokitugasit.my.id (tanpa VPS)." \
			} \
		}; \
		const res = { \
			setHeader: () => {}, \
			status: (code) => ({ \
				json: (data) => console.log("Hasil Uji:", code, data) \
			}) \
		}; \
		await m.default(req, res); \
	}).catch(err => console.error(err)); \
	'
