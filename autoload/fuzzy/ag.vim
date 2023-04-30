let s:max_count = 1000000
let s:rg_cmd = 'rg --column -M200 --vimgrep --max-count='.s:max_count.' "%s" "%s"'
let s:ag_cmd = 'ag --column -W200 --vimgrep --max-count='.s:max_count.' "%s" "%s"'
let s:grep_cmd = 'grep -n -r --max-count='.s:max_count.' "%s" "%s"'
let s:sep_pattern = '\:\d\+:\d\+:'
let s:loading = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

if executable('ag')
    let s:cmd = s:ag_cmd
elseif executable('grep') && v:false
    let s:cmd = s:grep_cmd
    let s:sep_pattern = '\:\d\+:'
elseif executable('rg') && v:false
    " not sure why rg has bad delay using job_start
    let s:cmd = s:rg_cmd
endif

" @return [path, linenr]
function! s:parse_agstr(str)
    let seq = matchstrpos(a:str, s:sep_pattern)
    if seq[1] == -1
        return [v:null, -1, -1]
    endif
    let path = a:str[:seq[1] - 1]
    let linecol = split(seq[0], ':')
    if len(linecol) == 2
        let [line, col] = linecol
    else
        let line = linecol[0]
        let col = 0
    endif
    return [path, line, col]
endfunction

function! s:reducer(pattern, acc, val)
    let seq = matchstrpos(a:val, s:sep_pattern)
    if seq[1] == -1
        return a:acc
    endif

    let linecol = split(seq[0], ':')
    if len(linecol) == 2
        let [line, col] = linecol
    else
        let line = linecol[0]
        let col = 0
    endif
    let path = a:val[:seq[1] - 1]
    let str = a:val[seq[2]:]
    let colstart = max([col - 40, 0])
    let centerd_str = strpart(str, colstart , colstart + 40)
    let relative_path = path[len(s:cwd) + 1:]

    let offset = len(relative_path) + len(seq[0]) + 1
    try
    let match_cols = matchfuzzypos([str], a:pattern)[1]
    catch
        echoerr [a:val, centerd_str, a:pattern]
    endtry

    let final_str = relative_path . seq[0] . centerd_str
    let col_list = []
    if len(match_cols) > 0
        let col_list = reduce(match_cols[0], { a, v -> add(a, v + offset) }, [])
        let a:acc.dict[final_str] = match_cols[0]
    endif
    let obj = {
    \ 'prefix': relative_path . seq[0],
    \ 'centerd_str': centerd_str,
    \ 'col_list': col_list,
    \ }
    call add(a:acc.objs, obj)
    call add(a:acc.strs, final_str)
    call add(a:acc.cols, col_list)
    return a:acc
endfunction

function! s:ag_job_start(pattern)
    if type(s:jid) == v:t_job
        call job_stop(s:jid)
    endif
    let s:cur_result = []
    if a:pattern == ''
        return
    endif
    let s:job_running = 1
    " -W100 is necessary
    let cmd_str = printf(s:cmd, a:pattern, s:cwd)
    let s:jid = job_start(cmd_str, {
    \ 'out_cb': function('s:job_handler'),
    \ 'out_mode': 'raw',
    \ 'exit_cb': function('s:exit_cb'),
    \ })
endfunction

func! s:exit_cb(jid, status)
    if a:jid == s:jid
        let s:job_running = 0
    endif
endfunc

function! s:job_handler(channel, msg)
    let lists = utils#selector#split(a:msg)
    let s:cur_result += lists 
endfunction

function! s:result_handle(lists)
    if s:cur_pattern == ''
        return [[], [], {}]
    endif
    let result = reduce(a:lists, function('s:reducer', [s:cur_pattern]),
        \ { 'strs': [], 'cols': [], 'objs': [], 'dict':{} })
    let fuzzy_results = matchfuzzypos(result.objs, s:cur_pattern, {'key': 'centerd_str', 'limit': 10000})
    " echom [len(a:lists), len(fuzzy_results[0])]
    let strs = []
    let cols = []
    let idx = 0
    for r in fuzzy_results[0]
        let final_str = r.prefix . r.centerd_str
        call add(strs, final_str)
        call add(cols, reduce(fuzzy_results[1][idx], { a, v -> add(a, v + len(r.prefix) + 1) }, []))
        let idx += 1
    endfor
    return [strs, cols, result.dict]
endfunction

function! s:ag(pattern, ...)
    if a:pattern == ''
        return [[], []]
    endif
    let path = s:cwd
    if a:0 > 0
        let path = a:1
    endif
    let files = systemlist('ag --column --vimgrep --max-count 1000 "'.a:pattern.'" '.path)
    let s:cur_pattern = a:pattern
    return s:result_handle(files)
endfunction


" async version
function! s:input(wid, args, ...) abort
    let pattern = a:args.str
    let s:cur_pattern = pattern
    call s:ag_job_start(pattern)
endfunc

function! s:update_preview_hl()
    if !has_key(s:cur_dict, s:cur_menu_item)
        return
    endif
    let [path, linenr, colnr] = s:parse_agstr(s:cur_menu_item)
    call clearmatches(s:preview_wid)
    let hl_list = []
    for col in s:cur_dict[s:cur_menu_item]
        call add(hl_list, [linenr, col + 1])
    endfor
    call matchaddpos('matchag', hl_list, 10, -1,  {'window': s:preview_wid})
endfunction

function! s:preview(wid, opts)
    let result = a:opts.cursor_item
    let preview_wid = a:opts.win_opts.partids['preview']
    let last_item = a:opts.last_cursor_item
    let [path, linenr, colnr] = s:parse_agstr(result)
    let [last_path, last_linenr, _] = s:parse_agstr(last_item)
    let s:cur_menu_item = result

    if !filereadable(path)
        if path == v:null
            call popup_settext(preview_wid, '')
        else
            call popup_settext(preview_wid, path . ' not found')
        endif
        return 
    endif

    if path != last_path
        let preview_bufnr = winbufnr(preview_wid)
        let fileraw = readfile(path)
        let ext = fnamemodify(path, ':e')
        let ft = utils#selector#getft(ext)
        call popup_settext(preview_wid, fileraw)
        " set syntax won't invoke some error cause by filetype autocmd
        try
            call setbufvar(preview_bufnr, '&syntax', ft)
        catch
        endtry
    endif
    if path != last_path || linenr != last_linenr
        call win_execute(preview_wid, 'norm '.linenr.'G')
        call win_execute(preview_wid, 'norm! zz')
    endif
    call s:update_preview_hl()
endfunction

function! s:select(wid, result)
    let [path, linenr, _] = s:parse_agstr(a:result[0])
    if path == v:null | return | endif
    execute('edit ' . path)
    exe 'norm! '.linenr.'G'
    exe 'norm! zz'
endfunction

function! s:ag_update_menu(...)
    if s:job_running
        let time = float2nr(str2float(reltime()->reltimestr()[4 : ]) * 1000)
        let speed = 100
        let loadidx = (time % speed) / len(s:loading) 
        call popup_setoptions(s:menu_wid, {'title' : string(len(s:cur_result)) . s:loading[loadidx]})
    else
        call popup_setoptions(s:menu_wid, {'title' : string(len(s:cur_result))})
    endif
    let cur_result_len = len(s:cur_result)

    if s:last_pattern == s:cur_pattern
    \ && cur_result_len == s:last_result_len
        return
    endif

    if s:cur_pattern == ''
        call utils#popup#menu_settext(s:menu_wid, [])
        let s:last_pattern = s:cur_pattern
        let s:last_result_len = cur_result_len
        return
    endif

    if cur_result_len == 0
        " we should use last result to do fuzzy search
        let [strs, cols, s:cur_dict] = s:result_handle(s:last_result)
    else
        let s:last_result = s:cur_result
        let [strs, cols, s:cur_dict] = s:result_handle(s:cur_result)
    endif

    let idx = 1
    let hl_list = []
    for col in cols
        call add(hl_list, [idx, col])
        let idx += 1
    endfor
    call utils#popup#menu_settext(s:menu_wid, strs[:100])
    call utils#popup#menu_sethl('select', s:menu_wid, hl_list[:100])
    call s:update_preview_hl()
    let s:last_pattern = s:cur_pattern
    let s:last_result_len = cur_result_len
endfunction

func! s:close_cb(...)
    call timer_stop(s:ag_update_tid) 
    if type(s:jid) == v:t_job
        call job_stop(s:jid)
    endif
endfunc

function! fuzzy#ag#start()
    let s:cwd = getcwd()
    let s:cwdlen = len(s:cwd)
    let s:cur_pattern = ''
    let s:cur_result = []
    let s:menu_wid = -1
    let s:cur_menu_item = ''
    let s:job_running = 0

    let s:ag_update_tid = 0
    let s:last_pattern = ''
    let s:last_result_len = -1
    let s:last_result = []
    let s:cur_dict = {}
    let s:jid = -1

    let ret = utils#selector#start([],
    \ {
        \ 'select_cb'  :  function('s:select'),
        \ 'input_cb'   :  function('s:input'),
        \ 'preview_cb' :  function('s:preview'),
        \ 'preview'    :  1,
        \ 'scrollbar'  :  0,
        \ 'close_cb'   :  function('s:close_cb'),
    \ })
    hi! link matchag search
    let menu_wid = ret[0]
    let preview_wid = ret[2]
    let s:menu_wid = menu_wid
    let s:preview_wid = preview_wid
    call setwinvar(menu_wid, '&wrap', '0')
    call setwinvar(preview_wid, '&cursorline', '1')
    call setwinvar(preview_wid, '&cursorlineopt', 'line')
    let s:ag_update_tid = timer_start(200, function('s:ag_update_menu'), {'repeat': -1})
endfunc

function! fuzzy#ag#init()
    command! -nargs=0 FuzzyAg call fuzzy#ag#start()
    nnoremap <silent> <leader>fr :FuzzyAg<CR>
endfunction
