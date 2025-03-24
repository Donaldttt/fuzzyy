vim9script

var devicon_char_width = 0
var devicon_byte_width = 0

# Options
var glyph_func = exists('g:fuzzyy_devicons_glyph_func') ? g:fuzzyy_devicons_glyph_func : (
    exists('g:WebDevIconsGetFileTypeSymbol') ? 'g:WebDevIconsGetFileTypeSymbol' : ''
)
var color_func = exists('g:fuzzyy_devicons_color_func') ? g:fuzzyy_devicons_color_func : ''

var enabled = exists('g:fuzzyy_devicons') && !empty(glyph_func) ? g:fuzzyy_devicons : !empty(glyph_func)

export def Enabled(): bool
    return enabled
enddef

export def GetDevicon(str: string): string
    return function(glyph_func)(str)
enddef

if enabled
    var test_devicon = GetDevicon('a.lua')
    devicon_char_width = strcharlen(test_devicon)
    devicon_byte_width = strlen(test_devicon)
endif

def SetHl()
    hi fuzzyyDevicon_yellow ctermfg=215 guifg=#f5c06f
    hi fuzzyyDevicon_blue ctermfg=109 guifg=#89b8c2
    hi fuzzyyDevicon_red ctermfg=9 guifg=#e27878
    hi fuzzyyDevicon_green ctermfg=107 guifg=#8faa54
    hi fuzzyyDevicon_magenta ctermfg=13 guifg=#a093c7
    hi fuzzyyDevicon_cyan ctermfg=14 guifg=#89b8c2
    hi fuzzyyDevicon_orange ctermfg=214 guifg=#f09f17
    hi fuzzyyDevicon_pink ctermfg=204 guifg=#ee6e73
    hi fuzzyyDevicon_dark_blue ctermfg=30 guifg=#44788e
    hi fuzzyyDevicon_light_blue ctermfg=109 guifg=#89b8c2
    hi fuzzyyDevicon_grey ctermfg=248 guifg=#6b7089
enddef
SetHl()

augroup FuzzyyDevicons
    autocmd!
    autocmd ColorScheme * SetHl()
augroup END

var devicons_color_table = {
    '__default__': 'blue',
    '*.lua': 'blue',
    '*.js': 'yellow',
    '*.ts': 'yellow',
    '*.go': 'blue',
    '*.c': 'blue',
    '*.cpp': 'dark_blue',
    '*.java': 'red',
    '*.php': 'magenta',
    '*.rb': 'red',
    '*.sh': 'dark_blue',
    '*.html': 'yellow',
    '*.css': 'blue',
    '*.scss': 'blue',
    '*.less': 'blue',
    '*.json': 'pink',
    '*.toml': 'grey',
    '*.sql': 'dark_blue',
    '*.md': 'yellow',
    '*.tex': 'blue',
    '*.vue': 'green',
    '*.swift': 'red',
    '*.kotlin': 'yellow',
    '*.dart': 'blue',
    '*.elm': 'blue',
    '*.vala': 'magenta',
    '*.vim': 'green',
    '*.png': 'dark_blue',
    '*.py': 'orange',
    'LICENSE': 'magenta',
}
map(devicons_color_table, (_, val) => {
    return 'fuzzyyDevicon_' .. val
})

export def AddColor(wid: number)
    if !empty(color_func)
        win_execute(wid, color_func .. '()')
        return
    endif
    var added: list<string>
    for ft in reverse(sort(keys(devicons_color_table)))
        var icon = GetDevicon(ft)
        if index(added, icon) != -1
            continue
        endif
        var charnr = char2nr(icon)
        var charhex = printf('%x', charnr)
        try
        matchadd(devicons_color_table[ft], '\v%u' .. charhex, 99, -1, { window: wid })
        add(added, icon)
        catch | endtry
    endfor
enddef

export def GetDeviconOffset(): number
    return devicon_byte_width + 1
enddef

export def RemoveDevicon(str: string): string
    return strcharpart(str, devicon_char_width + 1)
enddef

export def AddDevicons(li: list<string>): list<string>
    if !empty(li) && stridx(li[0], ':') != -1
        map(li, (_, val) => {
            return GetDevicon(split(val, ':')[0]) .. ' ' .. val
        })
    else
        map(li, 'GetDevicon(v:val) .. " " .. v:val')
    endif
    return li
enddef
