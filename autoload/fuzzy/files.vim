function! s:reducer(acc, val)
    if isdirectory(a:val) | return a:acc | endif
    call add(a:acc, a:val[s:cwdlen + 1:])
    " call add(a:acc, fnamemodify(a:val, ':s?'.getcwd().'?.?'))
    return a:acc
endfunction

function! s:files(...)
    let path = s:cwd
    if a:0 > 0
        let path = a:1
    endif
    if g:os == 'Windows'
        let files = glob(path . '/**', 1, 1, 1)
    else
        let files = systemlist('find '.path.' -type f -not -path "*/.git/*"')
    endif
    let files = reduce(files, function('s:reducer'), [])
    return files
endfunction

function! s:open(path)
    execute('edit ' . a:path)
endfunction

function! s:select(wid, result)
    call s:open(a:result[0])
endfunction

let s:input_timer = -1
func! s:input_update(...)
    let [file_sorted_list, hl_list] = utils#selector#fuzzysearch(s:cur_result, s:cur_pattern, 10000)
    call utils#popup#menu_settext(s:menu_wid, file_sorted_list[:100])
    call utils#popup#menu_sethl('select', s:menu_wid, hl_list[:100])
    call popup_setoptions(s:menu_wid, {'title' : len(s:cur_result)})
endfunc

let s:input_timer2 = 0
function! s:input(wid, val, ...) abort
    let pattern = a:val.str
    let s:cur_pattern = pattern

    " when in loading state, s:files_update_menu will handle the input
    if s:in_loading
        return
    endif

    let file_list = s:cur_result
    let hl_list = []
    let menu_wid = s:menu_wid

    if pattern != ''
        if len(file_list) > 10000
            call timer_stop(s:input_timer)
            let s:input_timer = timer_start(100, function('s:input_update'))
        else
            call s:input_update()
        endif
    else
        call utils#popup#menu_settext(menu_wid, s:cur_result[:100])
        call utils#popup#menu_sethl('select', menu_wid, [])
        call popup_setoptions(menu_wid, {'title' : len(s:cur_result)})
    endif

endfunc

function! s:preview(wid, opts)
    let result = a:opts.cursor_item
    let preview_wid = a:opts.win_opts.partids['preview']
    if !filereadable(result)
        if result == ''
            call popup_settext(preview_wid, '')
        else
            call popup_settext(preview_wid, result . ' not found')
        endif
        return
    endif
    let preview_bufnr = winbufnr(preview_wid)
    let fileraw = readfile(result)
    let ext = fnamemodify(result, ':e')
    let ft = utils#selector#getft(ext)
    call popup_settext(preview_wid, fileraw)
    " set syntax won't invoke some error cause by filetype autocmd
    try
        call setbufvar(preview_bufnr, '&syntax', ft)
    catch
    endtry
endfunction

func! fuzzy#files#profile()
    profile start ./vim.log
    profile func *fuzzy#files#start*

endfunc

let s:cur_result = []
let s:jid = -1
function! s:files_job_start(path)
    if type(s:jid) == v:t_job
        call job_stop(s:jid)
    endif
    let s:cur_result = []
    if a:path == ''
        return
    endif
    if has('win32')
        let cmdstr = 'powershell -command "gci . -r -n -File"'
    else
        let cmdstr = 'find . -type f -not -path "*/.git/*"'
    endif
    let s:jid = job_start(cmdstr, {
    \ 'out_cb': function('s:job_handler'),
    \ 'out_mode': 'raw',
    \ 'exit_cb': function('s:exit_cb'),
    \ 'err_cb': function('s:exit_cb'),
    \ 'cwd' : a:path
    \ })
endfunction

func! s:err_cb(...)
    echom['err']
endfunc

func! s:exit_cb(...)
    let s:in_loading = 0
	if s:last_result_len <= 0
		call utils#popup#menu_settext(s:menu_wid, s:cur_result[:100])
	endif
    call timer_stop(s:files_update_tid)
    call popup_setoptions(s:menu_wid, {'title' : len(s:cur_result)})
endfunc

function! s:job_handler(channel, msg)
    let lists = utils#selector#split(a:msg)
    " let lists = reduce(lists, function('s:reducer'), [])
    let s:cur_result += lists
endfunction

function! s:files_update_menu(...) abort
    let cur_result_len = len(s:cur_result)
    call popup_setoptions(s:menu_wid, {'title' : string(len(s:cur_result))})
    if cur_result_len == s:last_result_len
        return
    endif
    let s:last_result_len = cur_result_len

    try
    let [file_sorted_list, hl_list] = utils#selector#fuzzysearch(s:cur_result, s:cur_pattern, 10000)
    call utils#popup#menu_settext(s:menu_wid, file_sorted_list[:100])
    call utils#popup#menu_sethl('select', s:menu_wid, hl_list[:100])
    catch
        " echom ['error in files_update_menu']
    endtry
endfunction

function! fuzzy#files#start()
	let s:last_result_len = -1
	let s:cur_pattern = ''
	let s:in_loading = 1
    let s:cwd = getcwd()
    let s:cwdlen = len(s:cwd)
    call s:files_job_start(s:cwd)
    let winds = utils#selector#start([], {
	\ 'select_cb'  :  function('s:select'),
    \ 'preview_cb' :  function('s:preview'),
    \ 'input_cb'   :  function('s:input'),
    \ 'preview'    :  1,
    \ 'infowin'    :  0,
    \ })
    let s:menu_wid = winds[0]
    call timer_start(50, function('s:files_update_menu'))
    let s:files_update_tid = timer_start(400, function('s:files_update_menu'), {'repeat': -1})
    autocmd User PopupClosed ++once try | call job_stop(s:jid) | call timer_stop(s:files_update_tid) | catch | endtry
endfunc

function! fuzzy#files#init()
    command! -nargs=0 FuzzyFiles call fuzzy#files#start()
    nnoremap <silent> <leader>ff :FuzzyFiles<CR>
endfunction
