vim9script

import autoload 'utils/selector.vim'
import autoload 'utils/devicons.vim'
import autoload 'ignore_tree/ignore_tree.vim'
import autoload 'ignore_tree/find_builder.vim'
import autoload 'ignore_tree/fd_builder.vim'
import autoload 'ignore_tree/gci_builder.vim'

var last_result_len: number
var cur_pattern: string
var last_pattern: string
var in_loading: number
var cwd: string
var cwdlen: number
var cur_result: list<string>
var jid: job
var menu_wid: number
var files_update_tid: number
var cache: dict<any>
var cmdstr: string
var matched_hl_offset = 0
var devicon_char_width = devicons.GetDeviconCharWidth()
var fuzzyy_custom_ignore = {}

var commands: dict<any>
var has_git = executable('git') ? v:true : v:false

def InsideGitRepo(): bool
    if has_git
        return stridx(system('git rev-parse --is-inside-work-tree'), 'true') == 0
    else
        echom 'fuzzyy: git is not installed'
        return v:false
    endif
enddef

if exists('g:fuzzyy_custom_ignore')
    fuzzyy_custom_ignore = g:fuzzyy_custom_ignore
else
    fuzzyy_custom_ignore = ignore_tree.MakeIgnoreTree()
endif

if executable('fd')
    commands = {
        'default': fd_builder.Build(fuzzyy_custom_ignore),
        'gitignore': 'fd --type f -H -E .git'
    }
else
    if has('win32')
        commands = {
            'default': gci_builder.Build(fuzzyy_custom_ignore)
        }
    else
        commands = {
            'default': find_builder.Build(fuzzyy_custom_ignore)
        }
    endif
    # TODO bugs
    if has_git && InsideGitRepo()
        commands.gitignore = 'git ls-files --cached --other --exclude-standard --full-name .'
    else
        commands.gitignore = v:null
    endif
endif

if has_git
    commands.only_git_files = 'git ls-files'
endif

def GetOrDefault(name: string, default: any): any
    if exists(name)
        return eval(name)
    endif
    return default
enddef

var enable_devicons = exists('g:fuzzyy_devicons') && exists('g:WebDevIconsGetFileTypeSymbol') ?
    g:fuzzyy_devicons : exists('g:WebDevIconsGetFileTypeSymbol')
if enable_devicons
    # devicons take 3/4(macvim) chars position plus 1 space
    matched_hl_offset = devicons.GetDeviconWidth() + 1
endif

# options
var respect_gitignore = GetOrDefault('g:files_respect_gitignore', 0)
var only_git_files = GetOrDefault('g:files_only_git_files', 0)

def InitConfig()
    cmdstr = ''
    if only_git_files
        && commands.only_git_files != v:null
        && InsideGitRepo()
        cmdstr = commands.only_git_files
    elseif respect_gitignore
        && commands.gitignore != v:null
        && InsideGitRepo()
        cmdstr = commands.gitignore
    else
        cmdstr = commands.default
    endif
enddef

InitConfig()

def ProcessResult(list_raw: list<string>, ...args: list<any>): list<string>
    var limit = -1
    var li: list<string>
    if len(args) > 0
        li = list_raw[: args[0]]
    else
        li = list_raw
    endif
    if enable_devicons
         return map(li, 'g:WebDevIconsGetFileTypeSymbol(v:val) .. " " .. v:val')
    endif
    return li
enddef

def Select(wid: number, result: list<any>)
    var path = result[0]
    if enable_devicons
        path = strcharpart(path, devicon_char_width + 1)
    endif
    execute('edit ' .. path)
enddef

def AsyncCb(result: list<any>)
    var strs = []
    var hl_list = []
    var idx = 1
    for item in result
        add(strs, item[0])
        hl_list += reduce(item[1], (acc, val) => {
            var pos = copy(val)
            pos[0] += matched_hl_offset
            add(acc, [idx] + pos)
            return acc
        }, [])
        idx += 1
    endfor
    selector.UpdateMenu(ProcessResult(strs), hl_list)
enddef

def Input(wid: number, val: dict<any>, ...li: list<any>)
    var pattern = val.str
    cur_pattern = pattern

    # when in loading state, files_update_menu will handle the input
    if in_loading
        return
    endif

    var file_list = cur_result

    if pattern != ''
        selector.FuzzySearchAsync(cur_result, cur_pattern, 200, function('AsyncCb'))
    else
        selector.UpdateMenu(ProcessResult(cur_result, 100), [])
        popup_setoptions(menu_wid, {'title': len(cur_result)})
    endif

enddef

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    if enable_devicons
        result = strcharpart(result, devicon_char_width + 1)
    endif
    if !has_key(opts.win_opts.partids, 'preview')
        return
    endif
    var preview_wid = opts.win_opts.partids['preview']
    if !filereadable(result)
        if result == ''
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, result .. ' not found')
        endif
        return
    endif
    var preview_bufnr = winbufnr(preview_wid)
    var fileraw = readfile(result, '', 70)
    var ext = fnamemodify(result, ':e')
    var ft = selector.GetFt(ext)
    popup_settext(preview_wid, fileraw)
    # set syntax won't invoke some error cause by filetype autocmd
    try
        setbufvar(preview_bufnr, '&syntax', ft)
    catch
    endtry
enddef

def FilesJobStart(path: string, cmd: string)
    if type(jid) == v:t_job && job_status(jid) == 'run'
        job_stop(jid)
    endif
    cur_result = []
    if path == ''
        return
    endif
    if cmd == ''
        in_loading = 0
        cur_result += glob(cwd .. '/**', 1, 1, 1)
        selector.UpdateMenu(ProcessResult(cur_result), [])
        return
    endif
    jid = job_start(cmd, {
        out_cb: function('JobHandler'),
        out_mode: 'raw',
        exit_cb: function('ExitCb'),
        err_cb: function('ErrCb'),
        cwd: path
    })
enddef

def ErrCb(channel: channel, msg: string)
    # echom ['err']
enddef

def ExitCb(j: job, status: number)
    in_loading = 0
    timer_stop(files_update_tid)
	if last_result_len <= 0
        selector.UpdateMenu(ProcessResult(cur_result, 100), [])
	endif
    popup_setoptions(menu_wid, {'title': len(cur_result)})
enddef

def JobHandler(channel: channel, msg: string)
    var lists = selector.Split(msg)
    cur_result += lists
enddef

def Profiling()
    profile start ~/.vim/vim.log
    profile func Input
    profile func Reducer
    profile func Preview
    profile func JobHandler
    profile func FilesUpdateMenu
enddef

def FilesUpdateMenu(...li: list<any>)
    var cur_result_len = len(cur_result)
    popup_setoptions(menu_wid, {'title': string(len(cur_result))})
    if cur_result_len == last_result_len
        return
    endif
    last_result_len = cur_result_len

        if cur_pattern != last_pattern
            selector.FuzzySearchAsync(cur_result, cur_pattern, 200, function('AsyncCb'))
            if cur_pattern == ''
                selector.UpdateMenu(ProcessResult(cur_result, 100), [])
            endif
            last_pattern = cur_pattern
        endif
enddef

def Close(wid: number, opts: dict<any>)
    if type(jid) == v:t_job && job_status(jid) == 'run'
        job_stop(jid)
    endif
    timer_stop(files_update_tid)
enddef

export def Start(windows: dict<any>, ...args: list<any>)
    last_result_len = -1
    cur_result = []
    cur_pattern = ''
    last_pattern = '@!#-='
    cwd = getcwd()
    cwdlen = len(cwd)
    in_loading = 1
    var wids = selector.Start([], {
        select_cb:  function('Select'),
        preview_cb:  function('Preview'),
        input_cb:  function('Input'),
        close_cb:  function('Close'),
        preview:  windows.preview,
        width: windows.width,
        preview_ratio: windows.preview_ratio,
        scrollbar: 0,
        enable_devicons: enable_devicons,
        key_callbacks: selector.split_edit_callbacks,
    })
    var cmd: string
    if len(args) > 0 && type(args[0]) == 1
        cmd = args[0]
    else
        cmd = cmdstr
    endif
    FilesJobStart(cwd, cmd)
    menu_wid = wids.menu
    timer_start(50, function('FilesUpdateMenu'))
    files_update_tid = timer_start(400, function('FilesUpdateMenu'), {'repeat': -1})
    # Profiling()
enddef

