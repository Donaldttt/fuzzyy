vim9script

import './popup.vim'

var fzf_list: list<string>
var cwd: string
var menu_wid: number
var prompt_str: string

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

export def UpdateMenu(test_list: list<string>, hl_list: list<list<any>>)
    popup.MenuSetText(menu_wid, test_list)
    popup.MenuSetHl('select', menu_wid, hl_list)
enddef

export def Split(str: string): list<string>
    var sep: string
    if has('win32')
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

# if pattern is empty, return [li, []]
# params:
#  - li: list of string to be searched
#  - pattern: string to be searched
#  - args: dict of options
#      - limit: max number of results
# return:
# - a list [str_list, hl_list]
#   - str_list: list of string to be displayed
#   - hl_list: list of highlight positions
#       - [[line1, col1], [line1, col2], [line2, col1], ...]
export def FuzzySearch(li: list<string>, pattern: string, ...args: list<any>): list<any>
    if pattern == ''
        return [li, []]
    endif
    var opts = {}
    if len(args) > 0 && args[0] > 0
        opts['limit'] = args[0]
    endif
    var results: list<any> = matchfuzzypos(li, pattern, opts)
    var strs = results[0]
    var poss = results[1]
    var scores = results[2]

    var str_list = []
    var hl_list = []
    var idx = 0
    for str in strs
        add(str_list, str)
        add(
        hl_list,
        [idx + 1, reduce(poss[idx], (acc, val) => add(acc, val + 1), [])])
        idx += 1
    endfor
    return [str_list, hl_list]
enddef

export def GetPrompt(): string
    return prompt_str
enddef

def Input(wid: number, args: dict<any>, ...li: list<any>)
    var val = args.str
    prompt_str = val
    var hi_list = []
    menu_wid = args.win_opts.partids.menu
    var ret: list<string>
    [ret, hi_list] = FuzzySearch(fzf_list, val)
    popup.MenuSetText(menu_wid, ret)
    popup.MenuSetHl('select', menu_wid, hi_list)
enddef

# params:
#   - list: list of string to be selected. can be empty at init state
#   - opts: dict of options
#       - comfirm_cb: callback to be called when user select an item.
#           comfirm_cb(menu_wid, result). result is a list like ['selected item']
#       - preview_cb: callback to be called when user move cursor on an item.
#           preview_cb(menu_wid, result). result is a list like ['selected item', opts]
#       - input_cb: callback to be called when user input something
#           input_cb(menu_wid, result). result is a list like ['input string', opts]
# return:
#   - a list [menu_wid, prompt_wid]
#   - if has a:1.preview = 1, then return [menu_wid, prompt_wid, preview_wid]
export def Start(list: list<string>, opts: dict<any>): list<number>
    fzf_list = list
    cwd = getcwd()
    prompt_str = ''

    opts.move_cb = has_key(opts, 'preview_cb') ? opts.preview_cb : v:null
    opts.select_cb = has_key(opts, 'select_cb') ? opts.select_cb : v:null
    opts.input_cb = has_key(opts, 'input_cb') ? opts.input_cb : function('Input')

    var ret = popup.PopupSelection(opts)
    menu_wid = ret[0]
    popup.MenuSetText(menu_wid, list)
    return ret
enddef
