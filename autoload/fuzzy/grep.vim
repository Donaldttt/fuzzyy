vim9script

import autoload 'utils/selector.vim'
import autoload 'utils/popup.vim'

var max_count = 1000
var rg_cmd = 'rg -M200 -S --vimgrep --max-count=' .. max_count .. ' -F "%s" "%s"'
var ag_cmd = 'ag -W200 -S --vimgrep --max-count=' .. max_count .. ' -F "%s" "%s"'
var grep_cmd = 'grep -n -r -i --max-count=' .. max_count .. ' "%s" "%s"'
var findstr_cmd = 'FINDSTR /S /N /I /O /i "%s" "%s/*"'
var sep_pattern = '\:\d\+:\d\+:'
var loading = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
var highlight = true

var cmd: string
# TODO no windows default
if executable('ag')
    cmd = ag_cmd
elseif executable('rg')
    cmd = rg_cmd
elseif executable('grep')
    cmd = grep_cmd
    sep_pattern = '\:\d\+:'
    highlight = false
elseif executable('findstr') # for Windows
    cmd = findstr_cmd
    sep_pattern = '\:\d\+:'
    highlight = false
endif

var cwd: string
var cwdlen = -1
var cur_pattern = ''
var cur_result = []
var menu_wid = -1
var cur_menu_item = ''
var job_running = 0
var ag_update_tid = 0
var last_pattern = ''
var last_result_len = -1
var last_result = []
var cur_dict = {}
var jid: job
var preview_wid = -1

# return:
#   [path, linenr]
def ParseResult(str: string): list<any>
    var seq = matchstrpos(str, sep_pattern)
    if seq[1] == -1
        return [v:null, -1, -1]
    endif
    # var path = str[: seq[1] - 1]
    var path = strpart(str, 0, seq[1])
    var linecol = split(seq[0], ':')
    var line = str2nr(linecol[0])
    var col: number
    if len(linecol) == 2
        col = str2nr(linecol[1])
    else
        col = 0
    endif
    return [path, line, col]
enddef

def Reducer(pattern: string, acc: dict<any>, val: string): dict<any>
    var seq = matchstrpos(val, sep_pattern)
    if seq[1] == -1
        return acc
    endif

    var linecol = split(seq[0], ':')
    var line: number = str2nr(linecol[0])
    var col: number
    if len(linecol) == 2
        col = str2nr(linecol[1])
    endif
    var path = strpart(val, 0, seq[1])
    var str = strpart(val, seq[2])
    var centerd_str = str
    var relative_path = strpart(path, len(cwd) + 1)

    var prefix = relative_path .. seq[0]
    var col_list = [col + len(prefix), len(pattern)]
    var final_str = prefix .. centerd_str
    acc.dict[final_str] = [line, col, len(pattern)]
    var obj = {
        prefix: prefix,
        centerd_str: centerd_str,
        col_list: col_list,
        final_str: final_str,
        line: line,
    }
    add(acc.objs, obj)
    add(acc.strs, final_str)
    add(acc.cols, col_list)
    return acc
enddef

def JobHandler(channel: channel, msg: string)
    var lists = selector.Split(msg)
    cur_result += lists
enddef

def JobStart(pattern: string)
    if type(jid) == v:t_job
        try | job_stop(jid) | catch | endtry
    endif
    cur_result = []
    if pattern == ''
        return
    endif
    job_running = 1
    var cmd_str = printf(cmd, escape(pattern, '"'), escape(cwd, '"'))
    jid = job_start(cmd_str, {
        out_cb: function('JobHandler'),
        out_mode: 'raw',
        exit_cb: function('ExitCb'),
    })
enddef

def ExitCb(id: job, status: number)
    if id == jid
        job_running = 0
    endif
enddef

def ResultHandle(lists: list<any>): list<any>
    if cur_pattern == ''
        return [[], [], {}]
    endif
    var result = reduce(lists, function('Reducer', [cur_pattern]),
         { 'strs': [], 'cols': [], 'objs': [], 'dict': {} })
    var strs = []
    var cols = []
    var idx = 1
    for r in result.objs
        add(strs, r.final_str)
        add(cols, [idx] + r.col_list)
        idx += 1
    endfor
    return [strs, cols, result.dict]
enddef

# async version
def Input(wid: number, args: dict<any>, ...li: list<any>)
    var pattern = args.str
    cur_pattern = pattern
    JobStart(pattern)
enddef

def UpdatePreviewHl()
    if !has_key(cur_dict, cur_menu_item) || !highlight || preview_wid < 0
        return
    endif
    var [path, linenr, colnr] = ParseResult(cur_menu_item)
    clearmatches(preview_wid)
    var hl_list = [cur_dict[cur_menu_item]]
    matchaddpos('cursearch', hl_list, 9999, -1,  {'window': preview_wid})
enddef

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    var last_item = opts.last_cursor_item
    var [path, linenr, colnr] = ParseResult(result)
    var last_path: string
    var last_linenr: number
    if type(last_item) == v:t_string  && type(last_item) == v:t_string && last_item != ''
        try
        [last_path, last_linenr, _] = ParseResult(last_item)
        catch
            return
        endtry
    else
        [last_path, last_linenr] = ['', -1]
    endif
    cur_menu_item = result

    if !path || !filereadable(path)
        if path == v:null
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, path .. ' not found')
        endif
        return
    endif

    if path != last_path
        var preview_bufnr = winbufnr(preview_wid)
        var fileraw = readfile(path)
        var ext = fnamemodify(path, ':e')
        var ft = selector.GetFt(ext)
        popup_settext(preview_wid, fileraw)
        # set syntax won't invoke some error cause by filetype autocmd
        try
            setbufvar(preview_bufnr, '&syntax', ft)
        catch
        endtry
    endif
    if path != last_path || linenr != last_linenr
        win_execute(preview_wid, 'norm ' .. linenr .. 'G')
        win_execute(preview_wid, 'norm! zz')
    endif
    UpdatePreviewHl()
enddef

def Select(wid: number, result: list<any>)
    var [path, linenr, _] = ParseResult(result[0])
    if path == v:null
        return
    endif
    exe 'edit ' .. path
    exe 'norm! ' .. linenr .. 'G'
    exe 'norm! zz'
enddef

def UpdateMenu(...li: list<any>)
    var cur_result_len = len(cur_result)
    if cur_pattern == ''
        selector.UpdateMenu([], [])
        last_pattern = cur_pattern
        last_result_len = cur_result_len
        popup_setoptions(menu_wid, {title: 0})
        return
    endif

    if job_running
        var time = float2nr(str2float(reltime()->reltimestr()[4 : ]) * 1000)
        var speed = 100
        var loadidx = (time % speed) / len(loading)
        popup_setoptions(menu_wid, {'title': string(len(cur_result)) .. loading[loadidx]})
    else
        popup_setoptions(menu_wid, {'title': string(len(cur_result))})
    endif

    if last_pattern == cur_pattern
        && cur_result_len == last_result_len
        return
    endif

    var strs: list<string>
    var cols: list<list<number>>
    if cur_result_len == 0
        # we should use last result to do fuzzy search
        # [strs, cols, cur_dict] = ResultHandle(last_result[: 2000])
        strs = []
        cols = []
    else
        last_result = cur_result
        [strs, cols, cur_dict] = ResultHandle(cur_result[: 200])
    endif

    var hl_list = cols
    if !highlight
        hl_list = []
    endif

    selector.UpdateMenu(strs, hl_list)
    UpdatePreviewHl()
    last_pattern = cur_pattern
    last_result_len = cur_result_len
enddef

def CloseCb(...li: list<any>)
    timer_stop(ag_update_tid)
    if type(jid) == v:t_job && job_status(jid) == 'run'
        job_stop(jid)
    endif
enddef

def Profiling()
    profile start ~/.vim/vim.log
    profile func Start
    profile func UpdateMenu
    profile func Preview
    profile func UpdatePreviewHl
    profile func JobHandler
    profile func ResultHandle
    profile func Reducer
enddef

export def Start(windows: dict<any>, ...keyword: list<any>)
    if cmd == ''
        echoe 'Please install ag, rg, grep or findstr to run :FuzzyGrep'
        return
    endif
    cwd = getcwd()
    cwdlen = len(cwd)
    cur_pattern = ''
    cur_result = []
    cur_menu_item = ''
    job_running = 0

    ag_update_tid = 0
    last_pattern = ''
    last_result_len = -1
    last_result = []
    cur_dict = {}

    var wids = selector.Start([],
     {
        select_cb:  function('Select'),
        input_cb:  function('Input'),
        preview_cb:  function('Preview'),
        preview:  windows.preview,
        width: windows.width,
        preview_ratio: windows.preview_ratio,
        scrollbar:  0,
        close_cb:  function('CloseCb'),
     })
    menu_wid = wids.menu
    if menu_wid == -1
        return
    endif
    preview_wid = wids.preview
    setwinvar(menu_wid, '&wrap', 0)
    ag_update_tid = timer_start(100, function('UpdateMenu'), {'repeat': -1})
    if len(keyword) > 0
        popup.SetPrompt(keyword[0])
    endif
    # Profiling()
enddef
