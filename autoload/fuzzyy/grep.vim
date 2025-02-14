vim9script

import autoload './utils/selector.vim'
import autoload './utils/popup.vim'
import autoload './utils/devicons.vim'

var matched_hl_offset = 0
var devicon_char_width = devicons.GetDeviconCharWidth()

# Options
var enable_devicons = exists('g:fuzzyy_devicons') && exists('g:WebDevIconsGetFileTypeSymbol') ?
    g:fuzzyy_devicons : exists('g:WebDevIconsGetFileTypeSymbol')
var respect_gitignore = exists('g:fuzzyy_grep_respect_gitignore') ?
    g:fuzzyy_grep_respect_gitignore : g:fuzzyy_respect_gitignore
var file_exclude = exists('g:fuzzyy_grep_exclude_file')
    && type(g:fuzzyy_grep_exclude_file) == v:t_list ?
    g:fuzzyy_grep_exclude_file : g:fuzzyy_exclude_file
var dir_exclude = exists('g:fuzzyy_grep_exclude_dir')
    && type(g:fuzzyy_grep_exclude_dir) == v:t_list ?
    g:fuzzyy_grep_exclude_dir : g:fuzzyy_exclude_dir
var include_hidden = exists('g:fuzzyy_grep_include_hidden') ?
    g:fuzzyy_grep_include_hidden : g:fuzzyy_include_hidden
var follow_symlinks = exists('g:fuzzyy_grep_follow_symlinks') ?
    g:fuzzyy_grep_follow_symlinks : g:fuzzyy_follow_symlinks
var ripgrep_options = exists('g:fuzzyy_grep_ripgrep_options')
    && type(g:fuzzyy_grep_ripgrep_options) == v:t_list ?
    g:fuzzyy_grep_ripgrep_options : g:fuzzyy_ripgrep_options

if enable_devicons
    matched_hl_offset = devicons.GetDeviconWidth() + 1
endif

var loading = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

var max_count = 1000

def Build_rg(): string
    var result = 'rg -M200 -S --vimgrep --max-count=' .. max_count .. ' -F'
    if include_hidden
        result ..= ' --hidden'
    endif
    if follow_symlinks
        result ..= ' --follow'
    endif
    if respect_gitignore
        result ..= ' --no-require-git'
    else
        result ..= ' --no-ignore'
    endif
    var dir_list_parsed = reduce(dir_exclude,
        (acc, dir) => acc .. "-g !" .. dir .. " ", "")
    var file_list_parsed = reduce(file_exclude,
        (acc, file) => acc .. "-g !" .. file .. " ", "")
    return result .. ' ' .. dir_list_parsed .. file_list_parsed ..
        ' ' .. join(ripgrep_options, ' ') .. ' %s "%s" "%s"'
enddef

def Build_ag(): string
    var result = 'ag -W200 -S --vimgrep --silent --max-count=' .. max_count .. ' -F'
    if include_hidden
        result ..= ' --hidden'
    endif
    if follow_symlinks
        result ..= ' --follow'
    endif
    if ! respect_gitignore
        result ..= ' --all-text'
    endif
    var dir_list_parsed = reduce(dir_exclude,
        (acc, dir) => acc .. "--ignore " .. dir .. " ", "")
    var file_list_parsed = reduce(file_exclude,
        (acc, file) => acc .. "--ignore " .. file .. " ", "")
    return result .. ' ' .. dir_list_parsed .. file_list_parsed .. ' %s "%s" "%s"'
enddef

def Build_grep(): string
    var result = 'grep -n -r -I --max-count=' .. max_count .. ' -F'
    if follow_symlinks
        result = substitute(result, ' -r ', ' -R ', '')
        if system('grep --version | head -1') =~# 'BSD'
            result ..= ' -S'
        endif
    endif
    var dir_list_parsed = reduce(dir_exclude,
        (acc, dir) => acc .. "--exclude-dir " .. dir .. " ", "")
    var file_list_parsed = reduce(file_exclude,
        (acc, file) => acc .. "--exclude " .. file .. " ", "")
    return result .. ' ' .. dir_list_parsed .. file_list_parsed .. ' %s "%s" "%s"'
enddef

def Build_git(): string
    var result = 'git grep -n -I --column --untracked --exclude-standard -F'
    var version = system('git version')->split('\M\s\+')[-1]->trim()
    var [major, minor] = split(version, '\M.')[0 : 1]
    # -m/--max-count option added in git version 2.38.0
    if str2nr(major) > 2 || ( str2nr(major) == 2 && str2nr(minor) >= 38 )
        result ..= ' --max-count=' .. max_count
    endif
    return result ..  ' %s "%s" "%s"'
enddef

var findstr_cmd = 'FINDSTR /S /N /O /P /L %s "%s" "%s/*"'

# Script scoped vars reset for each invocation of Start(). Allows directory
# change between invocations and git-grep only to be used when in git repo.
var cmd: string
var sep_pattern: string
var highlight: bool
# Set to ignore case option for grep programs that do not support smart case
# When set, smart case will be emulated by adding ignore case option when
# search pattern does not include any characters Vim considers upper case
var ignore_case: string

def InsideGitRepo(): bool
    return stridx(system('git rev-parse --is-inside-work-tree'), 'true') == 0
enddef

def Build()
    if executable('rg')
        cmd = Build_rg()
        ignore_case = ''
        sep_pattern = '\:\d\+:\d\+:'
        highlight = true
    elseif executable('ag')
        cmd = Build_ag()
        ignore_case = ''
        sep_pattern = '\:\d\+:\d\+:'
        highlight = true
    elseif respect_gitignore && executable('git') && InsideGitRepo()
        cmd = Build_git()
        ignore_case = '-i'
        sep_pattern = '\:\d\+:\d\+:'
        highlight = true
    elseif executable('grep')
        cmd = Build_grep()
        ignore_case = '-i'
        sep_pattern = '\:\d\+:'
        highlight = false
    elseif executable('findstr') # for Windows
        cmd = findstr_cmd
        ignore_case = '/I'
        sep_pattern = '\:\d\+:'
        highlight = false
    else
        echoerr 'Please install ag, rg, grep or findstr to run :FuzzyGrep'
    endif
enddef

var cwd: string
var cwdlen: number
var cur_pattern = ''
var cur_result = []
var menu_wid = -1
var cur_menu_item = ''
var job_running = 0
var update_tid = 0
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
        return [null, -1, -1]
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
    # note: git-grep command returns relative paths, but we want to generate
    # a path relative to the cwd provided (not the current Vim working dir)
    # note2: also currently required for Git-Bash and friends, as this fixes
    # windows file separator in paths returned from external commands like rg
    var absolute_path = fnamemodify(path, ':p')
    var str = strpart(val, seq[2])
    var centerd_str = str
    var relative_path = strpart(absolute_path, cwdlen + 1)

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

def JobStart(pattern: string)
    if type(jid) == v:t_job
        try | job_stop(jid) | catch | endtry
    endif
    cur_result = []
    if pattern == ''
        return
    endif
    job_running = 1
    var cmd_str: string
    # fudge smart-case for grep programs that don't natively support it
    # adds ignore case option to arguments when no upper case chars found
    if !empty(ignore_case) && match(pattern, '\u') == -1
        cmd_str = printf(cmd, ignore_case, escape(pattern, '"'), escape(cwd, '"'))
    else
        cmd_str = printf(cmd, '', escape(pattern, '"'), escape(cwd, '"'))
    endif
    jid = job_start(cmd_str, {
        out_cb: function('JobOutCb'),
        out_mode: 'raw',
        exit_cb: function('JobExitCb'),
        err_cb: function('JobErrCb'),
    })
enddef

def JobOutCb(channel: channel, msg: string)
    var lists = selector.Split(msg)
    cur_result += lists
enddef

def JobErrCb(channel: channel, msg: string)
    echoerr msg
enddef

def JobExitCb(id: job, status: number)
    if id == jid
        job_running = 0
    endif
enddef

def ResultHandle(lists: list<any>): list<any>
    if cur_pattern == ''
        return [[], [], {}]
    endif
    var result = reduce(lists, function('Reducer', [cur_pattern]),
         { strs: [], cols: [], objs: [], dict: {} })
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
    matchaddpos('fuzzyyPreviewMatch', hl_list, 9999, -1,  {window: preview_wid})
enddef

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    if enable_devicons
        result = strcharpart(result, devicon_char_width + 1)
    endif
    var last_item = opts.last_cursor_item
    var [relative_path, linenr, colnr] = ParseResult(result)
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

    win_execute(preview_wid, 'syntax clear')
    var path = cwd .. '/' .. relative_path
    if !filereadable(path)
        if relative_path == null
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, path .. ' not found')
        endif
        return
    endif

    if path != last_path
        var preview_bufnr = winbufnr(preview_wid)
        var content = readfile(path)
        noautocmd popup_settext(preview_wid, content)
        setwinvar(preview_wid, '&filetype', '')
        win_execute(preview_wid, 'silent! doautocmd filetypedetect BufNewFile ' .. path)
        noautocmd win_execute(preview_wid, 'silent! setlocal nospell nolist')
        if empty(getwinvar(preview_wid, '&filetype')) || getwinvar(preview_wid, '&filetype') == 'conf'
            var modelineft = selector.FTDetectModelines(content)
            if !empty(modelineft)
                win_execute(preview_wid, 'set filetype=' .. modelineft)
            endif
        endif
    endif
    if path != last_path || linenr != last_linenr
        win_execute(preview_wid, 'norm! ' .. linenr .. 'G')
        win_execute(preview_wid, 'norm! zz')
    endif
    UpdatePreviewHl()
enddef

def Select(wid: number, result: list<any>)
    var [relative_path, line, col] = ParseResult(result[0])
    if relative_path == null
        return
    endif
    if enable_devicons
        relative_path = strcharpart(relative_path, devicon_char_width + 1)
    endif
    var path = cwd .. '/' .. relative_path
    selector.MoveToUsableWindow()
    exe 'edit ' .. fnameescape(path)
    if col > 0
        cursor(line, col)
    else
        exe 'norm! ' .. line .. 'G'
    endif
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
        popup_setoptions(menu_wid, {title: string(len(cur_result)) .. loading[loadidx]})
    else
        popup_setoptions(menu_wid, {title: string(len(cur_result))})
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

    if enable_devicons
        map(strs, (_, val) => {
            return g:WebDevIconsGetFileTypeSymbol(split(val, ':')[0]) .. ' ' .. val
        })
        hl_list = reduce(hl_list, (a, v) => {
            v[1] += matched_hl_offset
            return add(a, v)
        }, [])
    endif

    selector.UpdateMenu(strs, hl_list)
    UpdatePreviewHl()
    last_pattern = cur_pattern
    last_result_len = cur_result_len
enddef

def CloseCb(...li: list<any>)
    timer_stop(update_tid)
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

export def Start(opts: dict<any> = {})
    Build()
    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    cwdlen = len(cwd)
    cur_pattern = ''
    cur_result = []
    cur_menu_item = ''
    job_running = 0

    update_tid = 0
    last_pattern = ''
    last_result_len = -1
    last_result = []
    cur_dict = {}

    var wids = selector.Start([], extend(opts, {
        select_cb: function('Select'),
        input_cb: function('Input'),
        preview_cb: function('Preview'),
        close_cb: function('CloseCb'),
        enable_devicons: enable_devicons,
        key_callbacks: selector.split_edit_callbacks
     }))
    menu_wid = wids.menu
    if menu_wid == -1
        return
    endif
    preview_wid = wids.preview
    setwinvar(menu_wid, '&wrap', 0)
    update_tid = timer_start(100, function('UpdateMenu'), {repeat: -1})
    if len(get(opts, 'search', '')) > 0
        popup.SetPrompt(opts.search)
    endif
    # Profiling()
enddef
