vim9script

import autoload './popup.vim'
import './devicons.vim'

var raw_list: list<string>
var cwd: string
var menu_wid: number
var prompt_str: string
var menu_hl_list: list<any>
var enable_devicons = devicons.Enabled()
var reuse_windows = exists('g:fuzzyy_reuse_windows')
    && type(g:fuzzyy_reuse_windows) == v:t_list ?
    g:fuzzyy_reuse_windows : ['netrw']
var async_step = exists('g:fuzzyy_async_step')
    && type(g:fuzzyy_async_step) == v:t_number ?
    g:fuzzyy_async_step : 10000
var root_patterns = exists('g:fuzzyy_root_patterns')
    && type(g:fuzzyy_root_patterns) == v:t_list ?
    g:fuzzyy_root_patterns : ['.git', '.hg', '.svn']

var wins: dict<any>

var enable_dropdown = exists('g:fuzzyy_dropdown') ? g:fuzzyy_dropdown : false
var enable_counter = exists('g:fuzzyy_counter') ? g:fuzzyy_counter : true
var enable_preview = exists('g:fuzzyy_preview') ? g:fuzzyy_preview : true

# Experimental: export total number of results/matches for the current search
# Can be used to update the menu title on input to show the number of matches
export var total_results: number

# This function is used to render the menu window.
# params:
# - str_list: list of string to be displayed in the menu window
# - hl_list: list of highlight positions
export def UpdateMenu(str_list: list<string>, hl_list: list<list<any>>)
    var new_list = copy(str_list)
    if enable_devicons
        devicons.AddDevicons(new_list)
        popup.MenuSetText(new_list)
        popup.MenuSetHl('select', hl_list)
        devicons.AddColor(menu_wid)
    else
        popup.MenuSetText(new_list)
        popup.MenuSetHl('select', hl_list)
    endif
enddef

# This function is used to get the line under the cursor in the menu window.
# params:
# - stripped: get the line after striping the devicon or any other prefix
# return:
# - the line under the cursor
export def MenuGetCursorItem(): string
    var bufnr = winbufnr(wins.menu)
    var cursorlinepos = line('.', wins.menu)
    var bufline = getbufline(bufnr, cursorlinepos, cursorlinepos)[0]
    if enable_devicons
        bufline = devicons.RemoveDevicon(bufline)
    endif
    return bufline
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

export def GetRootDir(): string
  var dir = getcwd()
  var cur: string
  while 1
    for pattern in root_patterns
      if !empty(globpath(dir, pattern, 1))
        return dir
      endif
    endfor
    [cur, dir] = [dir, fnamemodify(dir, ':h')]
    if cur == dir | break | endif
  endwhile
  return getcwd()
enddef

# Search pattern @pattern in a list of strings @li
# if pattern is empty, return [li, []]
# params:
#  - li: list of string to be searched
#  - pattern: string to be searched
#  - args: dict of options
#      - limit: max number of results
# return:
# - a list [str_list, hl_list]
#   - str_list: list of search results
#   - hl_list: list of highlight positions
#       - [[line1, col1], [line1, col2], [line2, col1], ...]
export def FuzzySearch(li: list<string>, pattern: string, ...args: list<any>): list<any>
    if pattern == ''
        total_results = len(raw_list)
        return [copy(li), []]
    endif
    var opts = {}
    if len(args) > 0 && args[0] > 0
        opts['limit'] = args[0]
    endif
    var results: list<any> = matchfuzzypos(li, pattern, opts)
    var strs = results[0]
    var poss = results[1]
    var scores = results[2]

    total_results = len(strs)

    var str_list = []
    var hl_list = []
    for idx in range(0, len(strs) - 1)
        add(str_list, strs[idx])
        var poss_result = MergeContinusNumber(poss[idx])

        # convert char index to byte index for highlighting
        for idx2 in range(len(poss_result))
            var temp = []
            var r = poss_result[idx2]
            add(temp, byteidx(strs[idx], r[0] - 1) + 1)
            if len(poss_result[idx2]) == 2
                add(temp, byteidx(strs[idx], r[0] - 1 + r[1]) + 1 - temp[0])
            endif
            poss_result[idx2] = temp
        endfor

        hl_list += reduce(poss_result, (acc, val) => add(acc, [idx + 1] + val), [])
    endfor
    return [str_list, hl_list]
enddef

var async_list: list<string>
var async_limit: number
var async_pattern: string
var async_results: list<any>
var async_tid: number
var AsyncCb: func

def InputAsyncCb(result: list<any>)
    var strs = []
    var hl_list = []
    var hl_offset = enable_devicons ? devicons.GetDeviconOffset() : 0
    var idx = 1
    for item in result
        add(strs, item[0])
        hl_list += reduce(item[1], (acc, val) => {
            var pos = copy(val)
            pos[0] += hl_offset
            add(acc, [idx] + pos)
            return acc
        }, [])
        idx += 1
    endfor
    UpdateMenu(strs, hl_list)
    if enable_counter
        popup_setoptions(menu_wid, {title: total_results})
    endif
enddef

def InputAsync(wid: number, result: string)
    if result != ''
        async_tid = FuzzySearchAsync(raw_list, result, 200, function('InputAsyncCb'))
    else
        timer_stop(async_tid)
        var strs = raw_list[: 100]
        UpdateMenu(strs, [])
        if enable_counter
            popup_setoptions(menu_wid, {title: len(raw_list)})
        endif
    endif
enddef

# merge continus numbers and convert them from string index to vim column
# [1,3] means [start index, length
# eg. [1,2,3,4,5,7,9] -> [[1,5], [7], [9]]
# eg. [2,3,4,5,6,8,10] -> [[2,5], [8], [10]]
def MergeContinusNumber(li: list<number>): list<any>
    var last_pos = li[0]
    var start_pos = li[0]
    var pos_len = 1
    var poss_result = []
    for idx in range(1, len(li) - 1)
        var pos = li[idx]
        if pos == last_pos + 1
            pos_len += 1
        else
            # add 1 because vim column starts from 1 and string index starts from 0
            if pos_len > 1
                add(poss_result, [start_pos + 1, pos_len])
            else
                add(poss_result, [start_pos + 1])
            endif
            start_pos = pos
            last_pos = pos
            pos_len = 1
        endif
        last_pos = pos
    endfor
    if pos_len > 1
        add(poss_result, [start_pos + 1, pos_len])
    else
        add(poss_result, [start_pos + 1])
    endif
    return poss_result
enddef

def Worker(tid: number)
    var li = async_list[: async_step]
    var results: list<any> = matchfuzzypos(li, async_pattern)
    var processed_results = []

    var strs = results[0]
    var poss = results[1]
    var scores = results[2]

    total_results += len(strs)

    for idx in range(len(strs))
        # merge continus number
        var poss_result = MergeContinusNumber(poss[idx])

        # convert char index to byte index for highlighting
        for idx2 in range(len(poss_result))
            var temp = []
            var r = poss_result[idx2]
            add(temp, byteidx(strs[idx], r[0] - 1) + 1)
            if len(poss_result[idx2]) == 2
                add(temp, byteidx(strs[idx], r[0] - 1 + r[1]) + 1 - temp[0])
            endif
            poss_result[idx2] = temp
        endfor

        add(processed_results, [strs[idx], poss_result, scores[idx]])
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

    if len(async_results) >= async_limit
        async_results = async_results[: async_limit]
    endif
    AsyncCb(async_results)

    async_list = async_list[async_step + 1 :]
    if len(async_list) == 0
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
    total_results = 0
    AsyncCb = Cb
    async_tid = timer_start(50, function('Worker'), {repeat: -1})
    Worker(async_tid)
    return async_tid
enddef

export def ReplaceCloseCb(Close_cb: func)
    popup.SetPopupWinProp(menu_wid, 'close_cb', Close_cb)
enddef

export def ReplaceSelectCb(Select_cb: func)
    popup.SetPopupWinProp(menu_wid, 'select_cb', Select_cb)
enddef

export def Close()
    popup_close(menu_wid)
enddef

export def CloseWithSelection()
    popup_close(menu_wid, [MenuGetCursorItem()])
enddef

export def UpdateList(li: list<string>)
    raw_list = li
enddef

def Input(wid: number, result: string)
    prompt_str = result
    menu_hl_list = []
    var ret: list<string>
    [ret, menu_hl_list] = FuzzySearch(raw_list, prompt_str)

    if enable_devicons
        devicons.AddDevicons(ret)
        var hl_offset = devicons.GetDeviconOffset()
         menu_hl_list = reduce(menu_hl_list, (a, v) => {
            v[1] += hl_offset
            return add(a, v)
         }, [])
    endif

    popup.MenuSetText(ret)
    popup.MenuSetHl('select', menu_hl_list)
    if enable_devicons
        devicons.AddColor(menu_wid)
    endif
    if enable_counter
        popup_setoptions(menu_wid, {title: total_results})
    endif
enddef

export def RefreshMenu()
    Input(menu_wid, {str: prompt_str})
enddef

def Cleanup()
    timer_stop(async_tid)
enddef

# For split callbacks
def SelectTab(wid: number, result: list<any>)
    if !empty(result) && !empty(result[0])
        var [buf, line, col] = split(result[0] .. ':0:0', ':')[0 : 2]
        var bufnr = bufnr(buf)
        if bufnr > 0 && !filereadable(buf)
            # for special buffers that cannot be edited
            execute 'tabnew'
            execute 'buffer ' .. bufnr
        elseif cwd ==# getcwd()
            execute 'tabnew ' .. fnameescape(buf)
        else
            var path = cwd .. '/' .. buf
            execute 'tabnew ' .. fnameescape(path)
        endif
        if str2nr(line) > 0
            if str2nr(col) > 0
                cursor(str2nr(line), str2nr(col))
            else
                exe 'norm! ' .. line .. 'G'
            endif
            exe 'norm! zz'
        endif
    endif
enddef

def SelectVSplit(wid: number, result: list<any>)
    if !empty(result) && !empty(result[0])
        var [buf, line, col] = split(result[0] .. ':0:0', ':')[0 : 2]
        var bufnr = bufnr(buf)
        if bufnr > 0 && !filereadable(buf)
            # for special buffers that cannot be edited
            # avoid :sbuffer to bypass 'switchbuf=useopen'
            execute 'vnew'
            execute 'buffer ' .. bufnr
        elseif cwd ==# getcwd()
            execute 'vsp ' .. fnameescape(buf)
        else
            var path = cwd .. '/' .. buf
            execute 'vsp ' .. fnameescape(path)
        endif
        if str2nr(line) > 0
            if str2nr(col) > 0
                cursor(str2nr(line), str2nr(col))
            else
                exe 'norm! ' .. line .. 'G'
            endif
            exe 'norm! zz'
        endif
    endif
enddef

def SelectSplit(wid: number, result: list<any>)
    if !empty(result) && !empty(result[0])
        var [buf, line, col] = split(result[0] .. ':0:0', ':')[0 : 2]
        var bufnr = bufnr(buf)
        if bufnr > 0 && !filereadable(buf)
            # for special buffers that cannot be edited
            # avoid :sbuffer to bypass 'switchbuf=useopen'
            execute 'new'
            execute 'buffer ' .. bufnr
        elseif cwd ==# getcwd()
            execute 'sp ' .. fnameescape(buf)
        else
            var path = cwd .. '/' .. buf
            execute 'sp ' .. fnameescape(path)
        endif
        if str2nr(line) > 0
            if str2nr(col) > 0
                cursor(str2nr(line), str2nr(col))
            else
                exe 'norm! ' .. line .. 'G'
            endif
            exe 'norm! zz'
        endif
    endif
enddef

def SelectQuickFix(wid: number, _: list<any>)
    var bufnr = winbufnr(wid)
    var lines: list<any>
    lines = reverse(getbufline(bufnr, 1, "$"))
    filter(lines, (_, val) => !empty(val))
    map(lines, (_, val) => {
        var [path, line, col] = split(val .. ':1:1', ':')[0 : 2]
        var text = split(val, ':' .. line .. ':' .. col .. ':')[-1]
        if enable_devicons
            if path == text
                text = devicons.RemoveDevicon(text)
            endif
            path = devicons.RemoveDevicon(path)
        endif
        var dict = {
            filename: path,
            lnum: str2nr(line),
            col: str2nr(col),
            text: text }
        return dict
    })
    setqflist(lines)
    exe 'copen'
enddef

def SetVSplitClose()
    ReplaceSelectCb(function('SelectVSplit'))
    CloseWithSelection()
enddef

def SetSplitClose()
    ReplaceSelectCb(function('SelectSplit'))
    CloseWithSelection()
enddef

def SetTabClose()
    ReplaceSelectCb(function('SelectTab'))
    CloseWithSelection()
enddef

def SetQuickFixClose()
    ReplaceSelectCb(function('SelectQuickFix'))
    CloseWithSelection()
enddef

export var split_edit_callbacks = {
    "\<c-v>": function('SetVSplitClose'),
    "\<c-s>": function('SetSplitClose'),
    "\<c-t>": function('SetTabClose'),
    "\<c-q>": function('SetQuickFixClose'),
}

export def MoveToUsableWindow(buf: any = null)
    var c = 0
    var wincount = winnr('$')
    var buftype = !empty(buf) && !getbufvar(buf, '&buftype') ?
        getbufvar(buf, '&buftype') : null
    var filetype = !empty(buf) && !getbufvar(buf, '&filetype') ?
        getbufvar(buf, '&filetype') : null
    while ( !empty(&buftype) && index(reuse_windows + [buftype], &buftype) == -1 &&
            index(reuse_windows + [filetype], &filetype) == -1 && c < wincount )
        wincmd w
        c = c + 1
    endwhile
enddef

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
export def Start(li_raw: list<string>, opts: dict<any> = {}): dict<any>
    if popup.active
        return { menu: -1, prompt: -1, preview: -1 }
    endif
    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    prompt_str = ''

    enable_devicons = enable_devicons && has_key(opts, 'devicons') ? opts.devicons : 0
    if has_key(opts, 'counter')
        enable_counter = opts.counter
    endif

    opts.preview_cb = has_key(opts, 'preview_cb') ? opts.preview_cb : null
    opts.select_cb = has_key(opts, 'select_cb') ? opts.select_cb : null
    opts.input_cb = has_key(opts, 'input_cb') ? opts.input_cb : (
        has_key(opts, 'async') && opts.async ? function('InputAsync') : function('Input')
    )
    opts.dropdown = has_key(opts, 'dropdown') ? opts.dropdown : enable_dropdown
    opts.preview = has_key(opts, 'preview') ? opts.preview : enable_preview

    wins = popup.PopupSelection(opts)
    menu_wid = wins.menu
    raw_list = li_raw
    var li = copy(li_raw)
    if opts.input_cb == function('InputAsync')
        li = li[: 100]
    endif
    if enable_devicons
         devicons.AddDevicons(li)
    endif
    popup.MenuSetText(li)
    if enable_devicons
        devicons.AddColor(menu_wid)
    endif

    if enable_counter
        popup_setoptions(menu_wid, {title: len(raw_list)})
    endif

    autocmd User PopupClosed ++once Cleanup()
    return wins
enddef
