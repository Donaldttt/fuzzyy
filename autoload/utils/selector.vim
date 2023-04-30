let s:fzf_list_len = 0
let s:fzf_list = []
let s:cwd = ''

let s:filetype_table = {
\ 'h'    :  'c',
\ 'hpp'  :  'cpp',
\ 'cc'   :  'cpp',
\ 'hh'   :  'cpp',
\ 'py'   :  'python',
\ 'js'   :  'javascript',
\ 'ts'   :  'typescript',
\ 'tsx'  :  'typescript',
\ 'jsx'  :  'typescript',
\ 'rs'   :  'rust',
\ 'json' :  'json',
\ 'yml'  :  'yaml',
\ 'md'   :  'markdown',
\ }

function! utils#selector#split(str)
    if has('win32')
        let sep = '\r\n'
    else
        let sep = '\n'
    endif
    return split(a:str, sep)
endfunction

function! utils#selector#getft(ft)
    if has_key(s:filetype_table, a:ft)
        return s:filetype_table[a:ft]
    endif
    return a:ft
endfunction

def Fuzzysearch9(li: list<string>, pattern: string, limit: number): list<any>
    var opts = {}
    if limit > 0
        opts['limit'] = limit
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

function! utils#selector#fuzzysearch(li, pattern, ...)
    if a:pattern == ''
        return [a:li, []]
    endif
    let ret = Fuzzysearch9(a:li, a:pattern, a:0 > 0 ? a:1 : -1)
    return ret
endfunction
" third argument is the size of return list

function! utils#selector#fuzzysearch_old(li, pattern, ...)
    let results = matchfuzzypos(a:li, a:pattern)
    let strs = results[0]
    let poss = results[1]
    let scores = results[2]
    if len(a:000) > 0 && type(a:1) == v:t_number && a:1 > 0
        let strs = strs[:a:1]
        let poss = poss[:a:1]
        let scores = scores[:a:1]
    endif

    let str_list = []
    let hi_list = []
    let idx = 0
    for str in strs
        call add(str_list, str)
        call add(hi_list,
            \ [idx + 1,
            \ reduce(poss[idx], { acc, val -> add(acc, val + 1) }, [])
            \])
        let idx += 1
    endfor

    return [str_list, hi_list]
endfunction

let s:input_timer2 = 0
function! s:input(wid, val, ...) abort
    let val = a:val.str
    let ret = s:fzf_list
    let hi_list = []
    let menu_wid = a:val.win_opts.partids.menu
    if val != ''
        let [ret, hi_list] = utils#selector#fuzzysearch(ret, val)
    endif

    if len(ret) > 7000
        call timer_stop(s:input_timer2)
        call g:MenuSetText(menu_wid, ret)
        let s:input_timer2 = timer_start(100, function('g:MenuSetHl', ['select', menu_wid, hi_list]))
    else
        call g:MenuSetText(menu_wid, ret)
        call g:MenuSetHl('select', menu_wid, hi_list)
    endif
endfunc

" params:
"   - list: list of string to be selected. can be empty at init state
"   - opts: dict of options
"       - comfirm_cb: callback to be called when user select an item.
"           comfirm_cb(menu_wid, result). result is a list like ['selected item']
"       - preview_cb: callback to be called when user move cursor on an item.
"           preview_cb(menu_wid, result). result is a list like ['selected item', opts]
"       - input_cb: callback to be called when user input something
"           input_cb(menu_wid, result). result is a list like ['input string', opts]
" return:
"   - a list [menu_wid, prompt_wid]
"   - if has a:1.preview = 1, then return [menu_wid, prompt_wid, preview_wid]
function! utils#selector#start(list, opts) abort
    let opts = a:opts 
    let s:fzf_list = a:list
    let s:cwd = getcwd()
    let s:fzf_list_len = len(a:list)

    let opts.move_cb = has_key(opts, 'preview_cb') ? opts.preview_cb : v:null
    let opts.select_cb = has_key(opts, 'select_cb') ? opts.select_cb : v:null
    let opts.input_cb = has_key(opts, 'input_cb') ? opts.input_cb : function('s:input')

    let ret = g:PopupSelection(opts)

    let menu_wid = ret[0]
    let prompt_wid = ret[1]

    call g:MenuSetText(menu_wid, a:list)
    return ret
endfunc
