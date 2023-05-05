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

# This function is used to render the menu window.
# params:
# - str_list: list of string to be displayed in the menu window
# - hl_list: list of highlight positions
export def UpdateMenu(str_list: list<string>, hl_list: list<list<any>>)
    popup.MenuSetText(menu_wid, str_list)
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

def Null(li: list<any>)
enddef
def g:WorkerTest()
    var li = ['abc', 'aca', 'ghi', 'jkl', 'mno', 'pqr', 'stu', 'vwx', 'yz']->repeat(3)
    var pattern = 'ac'
    var r = FuzzySearchAsync(li, 'ac', 100, function(Null))
    for i in range(100)
        echom async_results
        sleep 100m
    endfor
enddef

var async_list: list<string>
var async_limit: number
var async_pattern: string
var async_results: list<any>
var async_tid: number
var AsyncCb: func
def Worker(tid: number)
    const ASYNC_LIMIT = 1000
    var li = async_list[: ASYNC_LIMIT]
    var results: list<any> = matchfuzzypos(li, async_pattern)
    var processed_results = []

    var strs = results[0]
    var poss = results[1]
    var scores = results[2]
    for idx in range(len(strs))
        add(processed_results, [strs[idx], poss[idx], scores[idx]])
    endfor
    async_results += processed_results
    sort(async_results, (a, b) => {
        if a[2] < b[2]
            return 1
        elseif a[2] > b[2]
            return -1
        else
            return a[0] > b[0] ? 1 : -1
        endif
    })
    AsyncCb(async_results)

    async_list = async_list[ASYNC_LIMIT + 1 :]
    if len(async_results) >= async_limit || len(async_list) == 0
        timer_stop(tid)
        return
    endif
enddef

# Using timer to mimic async search. This is a workaround for the lack of async
# support in vim. It uses timer to do the search in the background, and calls
# the callback function when part of the results are ready.
# This function only allows one outstanding call at a time. If a new call is
# made before the previous one finishes, the previous one will be canceled.
# params:
#  - li: list of string to be searched
#  - pattern: string to be searched
#  - limit: max number of results
#  - Cb: callback function
# return:
#  timer id
export def FuzzySearchAsync(li: list<string>, pattern: string, limit: number, Cb: func): number
    # only one outstanding call at a time
    timer_stop(async_tid)
    if pattern == ''
        return -1
    endif
    async_list = li
    async_limit = limit
    async_pattern = pattern
    async_results = []
    AsyncCb = Cb
    async_tid = timer_start(100, function('Worker'), {'repeat': -1})
    Worker(async_tid)
    return async_tid
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

# This function spawn a popup picker for user to select an item from a list.
# params:
#   - list: list of string to be selected. can be empty at init state
#   - opts: dict of options
#       - comfirm_cb: callback to be called when user select an item.
#           comfirm_cb(menu_wid, result). result is a list like ['selected item']
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
#   - a list [menu_wid, prompt_wid]
#   - if has preview = 1, then return [menu_wid, prompt_wid, preview_wid]
export def Start(li: list<string>, opts: dict<any>): list<number>
    fzf_list = li
    cwd = getcwd()
    prompt_str = ''

    opts.move_cb = has_key(opts, 'preview_cb') ? opts.preview_cb : v:null
    opts.select_cb = has_key(opts, 'select_cb') ? opts.select_cb : v:null
    opts.input_cb = has_key(opts, 'input_cb') ? opts.input_cb : function('Input')

    var ret = popup.PopupSelection(opts)
    menu_wid = ret[0]
    popup.MenuSetText(menu_wid, li)
    return ret
enddef
