vim9script

# Exports one function, to get a terminal color number from a color name

# Copied from https://github.com/tiagofumo/vim-nerdtree-syntax-highlight,
# which copied from https://github.com/chriskempson/vim-tomorrow-theme.
# Removed support for fewer than 256 colors, and updated for vim9script
# Also updated to use American rather than British English (I personally
# write in British English, but Fuzzyy generally uses American English)

# Returns an approximate gray index for the given gray level
def GrayNumber(x: number): number
    if x < 14
        return 0
    else
        var n = (x - 8) / 10
        var m = (x - 8) % 10
        if m < 5
            return n
        else
            return n + 1
        endif
    endif
enddef

# Returns the actual gray level represented by the gray index
def GrayLevel(n: number): number
    if n == 0
        return 0
    else
        return 8 + (n * 10)
    endif
enddef

# Returns the palette index for the given gray index
def GrayColor(n: number): number
    if n == 0
        return 16
    elseif n == 25
        return 231
    else
        return 231 + n
    endif
enddef

# Returns an approximate color index for the given color level
def RgbNumber(x: number): number
    if x < 75
        return 0
    else
        var n = (x - 55) / 40
        var m = (x - 55) % 40
        if m < 20
            return n
        else
            return n + 1
        endif
    endif
enddef

# Returns the actual color level for the given color index
def RgbLevel(n: number): number
    if n == 0
        return 0
    else
        return 55 + (n * 40)
    endif
enddef

# Returns the palette index for the given R/G/B color indices
def RgbColor(x: number, y: number, z: number): number
    return 16 + (x * 36) + (y * 6) + z
enddef

# Returns the palette index to approximate the given R/G/B color levels
def Rgb(r: number, g: number, b: number): number
  # Get the closest gray
  var gx = GrayNumber(r)
  var gy = GrayNumber(g)
  var gz = GrayNumber(b)

  # Get the closest color
  var x = RgbNumber(r)
  var y = RgbNumber(g)
  var z = RgbNumber(b)

  if gx == gy && gy == gz
    # There are two possibilities
    var dgr = GrayLevel(gx) - r
    var dgg = GrayLevel(gy) - g
    var dgb = GrayLevel(gz) - b
    var dgray = (dgr * dgr) + (dgg * dgg) + (dgb * dgb)
    var dr = RgbLevel(gx) - r
    var dg = RgbLevel(gy) - g
    var db = RgbLevel(gz) - b
    var drgb = (dr * dr) + (dg * dg) + (db * db)
    if dgray < drgb
      # Use the gray
      return GrayColor(gx)
    else
      # Use the color
      return RgbColor(x, y, z)
    endif
  else
    # Only one possibility
    return RgbColor(x, y, z)
  endif
enddef

# Returns the palette index to approximate the '#rrggbb' hex string
export def Hex(hex: string): number
    var r = str2nr(strpart(hex, 1, 2), 16)
    var g = str2nr(strpart(hex, 3, 2), 16)
    var b = str2nr(strpart(hex, 5, 2), 16)
    return Rgb(r, g, b)
enddef

# Returns approximate cterm color number from color name or hex color
export def TermColor(val: string): number
    if stridx(val, '#') == 0
        return Hex(val)
    endif
    if !has_key(v:colornames, val)
        echoerr "color name '" .. val .. "' not found"
    endif
    return Hex(get(v:colornames, val))
enddef

# for name in uniq(keys(v:colornames))
#     if index([202, 203, 204, 205, 206], TermColor(name)) != -1
#         echo name .. ': ' .. TermColor(name)
#     endif
#     if name =~ '^\w\+$'
#         exe 'hi fuzzyyDeviconNew_' .. name .. ' ctermfg=' .. TermColor(name) .. ' guifg=' .. name
#     endif
# endfor
