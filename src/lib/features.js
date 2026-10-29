/**
 * Feature flag modul CRM/outreach.
 *
 * Default: aktif. Set VITE_ENABLE_CRM=false di environment frontend
 * untuk menyembunyikan menu dan memblokir route CRM tanpa menghapus
 * data atau mengubah website publik.
 */
export const crmEnabled = import.meta.env.VITE_ENABLE_CRM !== 'false'

/** Sub-modul CRM. Default aktif, kecuali inbound (butuh app review Meta). */
export const outreachEnabled = crmEnabled && import.meta.env.VITE_ENABLE_OUTREACH !== 'false'
export const campaignsEnabled = crmEnabled && import.meta.env.VITE_ENABLE_CAMPAIGNS !== 'false'
export const referralEnabled = crmEnabled && import.meta.env.VITE_ENABLE_REFERRAL !== 'false'
export const inboundEnabled = crmEnabled && import.meta.env.VITE_ENABLE_INBOUND === 'true'
