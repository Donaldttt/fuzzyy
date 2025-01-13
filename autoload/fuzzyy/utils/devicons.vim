vim9script

var devicon_char_width = 0
var devicon_width = 0
if exists('g:WebDevIconsGetFileTypeSymbol')
    var test_devicon = g:WebDevIconsGetFileTypeSymbol('a.lua')
    devicon_char_width = strcharlen(test_devicon)
    devicon_width = len(test_devicon)
endif

def SetHl()
    hi fuzzyy_yellow ctermfg=215 guifg=#f5c06f
    hi fuzzyy_blue ctermfg=109 guifg=#89b8c2
    hi fuzzyy_red ctermfg=9 guifg=#e27878
    hi fuzzyy_green ctermfg=107 guifg=#8faa54
    hi fuzzyy_magenta ctermfg=13 guifg=#a093c7
    hi fuzzyy_cyan ctermfg=14 guifg=#89b8c2
    hi fuzzyy_orange ctermfg=214 guifg=#f09f17
    hi fuzzyy_pink ctermfg=204 guifg=#ee6e73
    hi fuzzyy_dark_blue ctermfg=30 guifg=#44788e
    hi fuzzyy_light_blue ctermfg=109 guifg=#89b8c2
    hi fuzzyy_grey ctermfg=248 guifg=#6b7089
enddef
SetHl()

augroup FuzzyyDevicons
    autocmd!
    autocmd ColorScheme * SetHl()
augroup END

var devicons_color_table = {
    'a.lua': 'fuzzyy_blue',
    'a.python': 'fuzzyy_blue',
    'a.js': 'fuzzyy_yellow',
    'a.ts': 'fuzzyy_yellow',
    'a.go': 'fuzzyy_blue',
    'a.c': 'fuzzyy_blue',
    'a.cpp': 'fuzzyy_dark_blue',
    'a.java': 'fuzzyy_red',
    'a.php': 'fuzzyy_magenta',
    'a.rb': 'fuzzyy_red',
    'a.sh': 'fuzzyy_dark_blue',
    'a.html': 'fuzzyy_yellow',
    'a.css': 'fuzzyy_blue',
    'a.scss': 'fuzzyy_blue',
    'a.less': 'fuzzyy_blue',
    'a.json': 'fuzzyy_pink',
    'a.toml': 'fuzzyy_grey',
    'a.sql': 'fuzzyy_dark_blue',
    'a.md': 'fuzzyy_yellow',
    'a.tex': 'fuzzyy_blue',
    'a.vue': 'fuzzyy_green',
    'a.swift': 'fuzzyy_red',
    'a.kotlin': 'fuzzyy_yellow',
    'a.dart': 'fuzzyy_blue',
    'a.elm': 'fuzzyy_blue',
    'a.vim': 'fuzzyy_green',
    'a.png': 'fuzzyy_dark_blue',
    'a.py': 'fuzzyy_orange',
    'LICENSE': 'fuzzyy_magenta',
}
var others_color = 'fuzzyy_yellow'

export def AddColor(wid: number)
    for ft in keys(devicons_color_table)
        var icon = g:WebDevIconsGetFileTypeSymbol(ft)
        var charnr = char2nr(icon)
        var charhex = printf('%x', charnr)
        try
        matchadd(devicons_color_table[ft], '\v%u' .. charhex, 99, -1, { window: wid })
        catch | endtry
    endfor
enddef

export def GetDeviconCharWidth(): number
    return devicon_char_width
enddef

export def GetDeviconWidth(): number
    return devicon_width
enddef

export def AddDevicons(li: list<string>): list<string>
    map(li, 'g:WebDevIconsGetFileTypeSymbol(v:val) .. " " .. v:val')
    return li
enddef
