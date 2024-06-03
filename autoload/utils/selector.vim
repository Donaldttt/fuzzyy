vim9script

import autoload './popup.vim'
import autoload './search.vim'
import './devicons.vim'

var fzf_list: list<string>
var cwd: string
var menu_wid: number
var prompt_str: string
var matched_hl_offset = 0
var devicon_char_width = devicons.GetDeviconCharWidth()
var enable_devicons = exists('g:fuzzyy_devicons') && exists('g:WebDevIconsGetFileTypeSymbol') ?
    g:fuzzyy_devicons : exists('g:WebDevIconsGetFileTypeSymbol')

if enable_devicons
    matched_hl_offset = devicons.GetDeviconWidth() + 1
endif
export var windows: dict<any>

var filetype_table = {
    h:  'c',
    hpp:  'cpp',
    cc:  'cpp',
    hh:  'cpp',
    py:  'python',
    js:  'javascript',
    ts:  'typescript',
    tsx:  'typescript',
    jsx:  'typescript',
    rs:  'rust',
    json:  'json',
    yml:  'yaml',
    md:  'markdown',
}

var enable_dropdown = exists('g:fuzzyy_dropdown') ? g:fuzzyy_dropdown : 0

# This function is used to render the menu window.
# params:
# - str_list: list of string to be displayed in the menu window
# - hl_list: list of highlight positions
# - opts: dict of options
#       - add devicons: add devicons to every entry
export def UpdateMenu(str_list: list<string>, hl_list: list<list<any>>, ...opts: list<any>)
    if enable_devicons
        if len(opts) > 0 && opts[0] == 1
            devicons.AddDevicons(str_list)
        endif
        popup.MenuSetText(menu_wid, str_list)
        popup.MenuSetHl('select', menu_wid, hl_list)
        devicons.AddColor(menu_wid)
    else
        popup.MenuSetText(menu_wid, str_list)
        popup.MenuSetHl('select', menu_wid, hl_list)
    endif
enddef

export def MenuGetCursorItem(): string
    var bufnr = winbufnr(windows.menu)
    var cursorlinepos = line('.', windows.menu)
    return getbufline(bufnr, cursorlinepos, cursorlinepos)[0]
enddef

export def Split(str: string): list<string>
    var sep: string
    if has('win32') && stridx(str, "\r\n") >= 0
        sep = '\r\n'
    else
        sep = '\n'
    endif
    return split(str, sep)
enddef

export def GetFt(ft: string): string
    if has_key(filetype_table, ft)
        return filetype_table[ft]
    endif
    return ft
enddef

export def GetPrompt(): string
    return prompt_str
enddef

export def ReplaceCloseCb(Close_cb: func)
    popup.SetPopupWinProp(menu_wid, 'close_cb', Close_cb)
enddef

export def Exit()
    popup_close(menu_wid)
enddef

def Input(wid: number, args: dict<any>, ...li: list<any>)
    var val = args.str
    prompt_str = val
    var hl_list = []
    menu_wid = args.win_opts.partids.menu
    var ret: list<string>
    [ret, hl_list] = search.FuzzySearch(fzf_list, val)

    if enable_devicons
         map(ret, 'g:WebDevIconsGetFileTypeSymbol(v:val) .. " " .. v:val')
         hl_list = reduce(hl_list, (a, v) => {
            v[1] += matched_hl_offset
            return add(a, v)
         }, [])
    endif

    popup.MenuSetText(menu_wid, ret)
    popup.MenuSetHl('select', menu_wid, hl_list)
    if enable_devicons
        devicons.AddColor(menu_wid)
    endif
enddef

# For split callbacks
def CloseTab(wid: number, result: dict<any>)
    if has_key(result, 'cursor_item')
        var buf = result.cursor_item
        if enable_devicons
            buf = strcharpart(buf, devicon_char_width + 1)
        endif
        execute 'tabnew ' .. buf
    endif
enddef

def CloseVSplit(wid: number, result: dict<any>)
    if has_key(result, 'cursor_item')
        var buf = result.cursor_item
        if enable_devicons
            buf = strcharpart(buf, devicon_char_width + 1)
        endif
        var bufnr = bufnr(buf)
        if bufnr >= 0
            # this is necessary for special buffer like terminal buffers
            execute 'vert sb ' .. bufnr
        else
            execute 'vsp ' .. buf
        endif
    endif
enddef

def CloseSplit(wid: number, result: dict<any>)
    if has_key(result, 'cursor_item')
        var buf = result.cursor_item
        if enable_devicons
            buf = strcharpart(buf, devicon_char_width + 1)
        endif
        var bufnr = bufnr(buf)
        if bufnr >= 0
            execute 'sb ' .. bufnr
        else
            execute 'sp ' .. buf
        endif
    endif
enddef

def SetVSplitClose()
    ReplaceCloseCb(function('CloseVSplit'))
    Exit()
enddef

def SetSplitClose()
    ReplaceCloseCb(function('CloseSplit'))
    Exit()
enddef

def SetTab()
    ReplaceCloseCb(function('CloseTab'))
    Exit()
enddef

export var split_edit_callbacks = {
    "\<c-v>": function('SetVSplitClose'),
    "\<c-s>": function('SetSplitClose'),
    "\<c-t>": function('SetTab'),
}

# This function spawn a popup picker for user to select an item from a list.
# params:
#   - list: list of string to be selected. can be empty at init state
#   - opts: dict of options
#       - select_cb: callback to be called when user select an item.
#           select_cb(menu_wid, result). result is a list like ['selected item']
#       - preview_cb: callback to be called when user move cursor on an item.
#           preview_cb(menu_wid, result). result is a list like ['selected item', opts]
#       - input_cb: callback to be called when user input something. If input_cb
#           is not set, then the input will be used as the pattern to filter the
#           list. If input_cb is set, then the input will be passed to given callback.
#           input_cb(menu_wid, result). the second argument result is a list ['input string', opts]
#       - preview: wheather to show preview window, default 1
#       - width: width of the popup window, default 80. If preview is enabled,
#           then width is the width of the total layout.
#       - xoffset: x offset of the popup window. The popup window is centered
#           by default.
#       - scrollbar: wheather to show scrollbar in the menu window.
#       - preview_ratio: ratio of the preview window. default 0.5
# return:
#   A dictionary:
#    {
#        menu: menu_wid,
#        prompt: prompt_wid,
#        preview: preview_wid,
#    }
export def Start(li_raw: list<string>, opts: dict<any>): dict<any>
    cwd = getcwd()
    prompt_str = ''

    enable_devicons = has_key(opts, 'enable_devicons') ? opts.enable_devicons : 0

    opts.move_cb = has_key(opts, 'preview_cb') ? opts.preview_cb : v:null
    opts.select_cb = has_key(opts, 'select_cb') ? opts.select_cb : v:null
    opts.input_cb = has_key(opts, 'input_cb') ? opts.input_cb : function('Input')
    opts.dropdown = enable_dropdown

    windows = popup.PopupSelection(opts)
    menu_wid = windows.menu
    fzf_list = li_raw
    var li = copy(li_raw)
    if enable_devicons
         devicons.AddDevicons(li)
    endif
    popup.MenuSetText(menu_wid, li)
    if enable_devicons
        devicons.AddColor(menu_wid)
    endif

    return windows
enddef
