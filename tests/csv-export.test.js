import { describe, expect, it } from 'vitest'
import { chunkRows, toCsv } from '../src/lib/csv'

describe('toCsv — formula injection', () => {
  it('menetralkan sel yang dimulai dengan =', () => {
    expect(toCsv([{ v: '=1+1' }], ['v'])).toBe("v\n'=1+1")
  })

  it('menetralkan +, -, @, dan tab', () => {
    expect(toCsv([{ v: '+62 812' }], ['v'])).toBe("v\n'+62 812")
    expect(toCsv([{ v: '-5' }], ['v'])).toBe("v\n'-5")
    expect(toCsv([{ v: '@user' }], ['v'])).toBe("v\n'@user")
    expect(toCsv([{ v: '\tcmd' }], ['v'])).toBe("v\n'\tcmd")
  })

  it('tetap mengutip sel yang berisi koma dan tanda kutip', () => {
    expect(toCsv([{ v: '=HYPERLINK("a","b")' }], ['v']))
      .toBe(`v\n"'=HYPERLINK(""a"",""b"")"`)
  })

  it('tidak mengubah teks biasa', () => {
    expect(toCsv([{ v: 'Andi Pratama' }], ['v'])).toBe('v\nAndi Pratama')
  })

  it('mengosongkan null/undefined', () => {
    expect(toCsv([{ a: null, b: undefined }], ['a', 'b'])).toBe('a,b\n,')
  })
})

describe('chunkRows', () => {
  it('memecah sesuai ukuran', () => {
    expect(chunkRows([1, 2, 3, 4, 5], 2)).toEqual([[1, 2], [3, 4], [5]])
  })

  it('mengembalikan satu chunk kalau lebih kecil', () => {
    expect(chunkRows([1, 2], 200)).toEqual([[1, 2]])
  })

  it('aman untuk input kosong / bukan array', () => {
    expect(chunkRows([], 10)).toEqual([])
    expect(chunkRows(null, 10)).toEqual([])
  })

  it('memakai default untuk 0 dan minimal 1 untuk nilai negatif', () => {
    expect(chunkRows([1, 2], 0)).toEqual([[1, 2]])
    expect(chunkRows([1, 2], -5)).toEqual([[1], [2]])
  })
})
