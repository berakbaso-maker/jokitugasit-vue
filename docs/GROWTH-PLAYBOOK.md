# Growth Playbook — Campaign, Consent & 14-Day Validation

Panduan operasional untuk modul kampanye (V4) di `jokitugasit-vue`.
Fokus: **distribusi berizin**, bukan blast DM.

- Modul: `/ops/campaigns`
- Consent: `/ops/prospects` (kolom Consent)
- Atribusi: link `?campaign=CMP-…&utm_source=…`
- Feature flag: `VITE_ENABLE_CAMPAIGNS` (default aktif)

---

## 1. Aturan dasar

1. **Tidak ada blast DM.** Campaign hanya mengukur materi, target, link, dan hasil.
2. **Izin dulu.** Admin harus setuju sebelum materi dibagikan. Persetujuan admin
   untuk membagikan materi **bukan** izin menyerahkan data anggota.
3. **Consent bukan biner.** `UNKNOWN` ≠ boleh dikirimi pesan otomatis.
4. **Opt-out itu final.** `OPTED_OUT` = DNC; re-import tidak menghapusnya.
5. **Sample kecil tidak disimpulkan.** Di bawah 5 klien lunas, angka hanya indikator.

---

## 2. Model consent

| Status | Arti | Boleh manual DM? | Boleh otomatis? |
|---|---|---|---|
| `UNKNOWN` | Ditemukan/diimpor, belum ada keputusan | Ya, setelah review | **Tidak** |
| `OPTED_IN` | Menyatakan setuju dihubungi | Ya | Ya (jika kanal mendukung) |
| `OPTED_OUT` | Menolak / minta berhenti | Tidak | Tidak |

Sumber izin: `WEBSITE_FORM`, `INBOUND_IG_DM`,
`ADMIN_PARTNER_SHARED_OPT_IN`, `MANUAL_CONTACT`.

Aturan teknis (ditegakkan database):

- `outreach_eligibility(prospect, channel)` → `MANUAL_DM` boleh untuk `UNKNOWN`;
  `AUTOMATED_DM` butuh `OPTED_IN`; semua kanal diblokir jika `OPTED_OUT`.
- `set_prospect_consent(..., 'OPTED_OUT')` otomatis menyalakan DNC.
- Opt-in saat DNC aktif ditolak — lepas DNC dulu dengan alasan.
- `clear_do_not_contact` mereset consent ke `UNKNOWN`, bukan diam-diam `OPTED_IN`.

---

## 3. Anatomi campaign

| Field | Arti |
|---|---|
| `objective` | `ADMIN_DISTRIBUTION`, `DIRECT_OUTREACH`, `REFERRAL`, `INBOUND` |
| `channel` | `INSTAGRAM_MANUAL_DM`, `IG_STORY_PARTNER`, `WHATSAPP_REFERRAL`, `WEBSITE_OPT_IN` |
| `code` | `CMP-XXXXXXXX` — dipakai di link |
| `cost_rupiah` | Biaya nyata (iklan, hadiah, transport) |
| `time_value_rupiah` | Nilai waktu outreach (opsional, untuk CAC jujur) |
| `targets` | Akun angkatan yang jadi sasaran |
| `events` | Inquiry, deal, paid, referral_paid (otomatis dari database) |

**Link yang dibagikan:**

```text
https://jokitugasit.my.id/request?campaign=CMP-XXXXXXXX&utm_source=instagram&utm_medium=instagram_dm&utm_campaign=CMP-XXXXXXXX
```

- Kode campaign harus `ACTIVE` agar diakui.
- Kode referral tetap bisa ditambahkan: `&ref=REF-XXXX`.
- Atribusi dikunci setelah request dibuat (first valid touch).

---

## 4. Hipotesis yang diuji (V1)

| Hipotesis | Cara ukur |
|---|---|
| Admin bersedia membagikan jasa | admin approached → izin → link dibagikan → inquiry |
| Landing page dipahami | view → CTA → konsultasi → order (dari campaign events) |
| Referral 10% memotivasi | partner aktif → inquiry via kode → order lunas |
| DM manual lebih baik dari distribusi admin | conversion per channel, denominator terpisah |

Jangan mencampur denominator antar-channel.

---

## 5. Rencana 14 hari (contoh, bukan jaminan)

| Metrik | Target eksperimen |
|---|---:|
| Akun angkatan dipetakan | 20 |
| Admin diajak komunikasi | maks. 20, personal |
| Admin setuju berbagi | 3–5 |
| Link campaign aktif | 3–5 |
| Inquiry nyata | 5–10 |
| Qualified leads | 2–3 |
| Closing | evaluasi aktual |

**Aturan:** tidak ada follow-up berulang ke non-responder. Jika admin menolak,
campaign target ditandai `DECLINED` dan tidak dijadwalkan ulang otomatis.

---

## 6. Operasional harian

1. Buka `/ops/campaigns` → lihat inquiry/paid per campaign.
2. Buka `/ops/outreach` → tindak lanjuti yang membalas.
3. Catat hasil di antrean (bukan di campaign; event campaign otomatis dari request).
4. Prospek yang menolak → **Opt-out** (DNC).
5. Jangan mengubah link campaign yang sudah disebar; buat campaign baru bila perlu.

Mingguan:

- Bandingkan channel: admin vs direct vs referral vs inbound.
- Hitung CAC: `(biaya + nilai waktu) / klien lunas`.
- Hentikan channel dengan biaya tinggi tanpa deal setelah sample cukup.

---

## 7. Metrik & CAC

```text
conversion     = klien lunas / inquiry
CAC            = (biaya campaign + nilai waktu) / klien lunas
komisi         = 10% × nilai eligible (database)
pendapatan     = omzet − komisi (belum biaya/pajak)
```

- `CAC` kosong (`—`) jika belum ada klien lunas.
- Jangan sebut “net profit” sebelum biaya operasional dan pajak.
- Jika `paid_clients < 5`, tampilkan sebagai “data kecil”.

---

## 8. Matriks kelayakan discovery (H3C)

| Metode | Status | Catatan |
|---|---|---|
| Input manual akun/prospek | ✅ | Data minimal, alasan jelas |
| Admin membagikan link/materi | ✅ prioritas | Butuh izin admin |
| Form opt-in website | ✅ | Consent tercatat `WEBSITE_FORM` |
| CSV dari sumber sah | ✅ | Wajib basis izin + provenance |
| Official Meta API untuk data yang tersedia | ⚠️ kondisional | Verifikasi endpoint/scope/permitted use |
| Scraping followers/following via private API/cookie | ⛔ | Tidak diimplementasikan |
| Browser bot blast DM / bypass limit | ⛔ | Tidak diimplementasikan |

---

## 9. Template admin distribution (manual)

> Halo kak, izin perkenalan. Saya software engineer yang membuka konsultasi
> coding, debugging, integrasi API/database, dan jasa pengembangan software.
> Saya ingin memperkenalkan website saya kepada teman-teman IT di angkatan
> kakak. Ada juga referral fee 10% jika rekomendasinya menghasilkan transaksi.
> Apakah berkenan bila saya kirim ringkasan jasa dan link website untuk
> dipertimbangkan dibagikan melalui kanal angkatan? Terima kasih, kak.

Materi setelah admin **mengizinkan**:

> Lagi butuh bantuan debugging, integrasi API, database, atau konsultasi teknis
> project? Ada jasa software engineering dengan portofolio dan konsultasi awal.
> Detail: `{referral_url}`. Layanan ini membantu problem solving dan mentoring;
> penilaian dan hasil akademik tetap menjadi tanggung jawab mahasiswa.

---

## 10. Inbound API (belum aktif)

Fitur inbound otomatis **OFF** (`VITE_ENABLE_INBOUND=false`). Aktivasi hanya
setelah:

1. Akun IG professional + Meta app + izin yang benar.
2. App review/live mode sesuai aturan Meta.
3. Verifikasi window respons & aturan messaging di dokumentasi resmi.
4. Webhook signature, dedupe, eligibility check, dan fallback manual teruji.

Selama belum, semua balasan dilakukan manual dari aplikasi Instagram.
Kebijakan Meta dapat berubah — status ini harus diverifikasi ulang saat implementasi.

---

## 11. Yang tidak boleh dilakukan

- Membeli/mengumpulkan daftar follower untuk blast.
- Mengirim DM otomatis ke `UNKNOWN`.
- Mengubah campaign/atribusi setelah deal untuk mengakali komisi.
- Menyimpulkan pemenang channel dari 1–2 transaksi.
- Menjanjikan nilai/kelulusan atau menyamarkan kepengarangan karya.
