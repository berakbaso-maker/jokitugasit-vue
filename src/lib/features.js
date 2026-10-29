/**
 * Feature flag modul CRM/outreach.
 *
 * Default: aktif. Set VITE_ENABLE_CRM=false di environment frontend
 * untuk menyembunyikan menu dan memblokir route CRM tanpa menghapus
 * data atau mengubah website publik.
 */
export const crmEnabled = import.meta.env.VITE_ENABLE_CRM !== 'false'
