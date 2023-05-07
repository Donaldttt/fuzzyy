" s:popup_wins has those keys:
"  bufnr: bufnr of the popup buffer
"  related_win: list of related windows
"  close_funcs: list of functions to be called when popup is closed
"  highlights: list of highlight match in the popup buffer
let s:popup_wins = {}
func! s:close_related_wins(wid, ...)
    for wid in s:popup_wins[a:wid].related_win
        if has_key(s:popup_wins, wid)
            let s:popup_wins[wid].related_win = []
        endif
        call popup_close(wid)
    endfor
endfunc

" params:
"   - wid: window id of the popup window
"   - select: the selected item in the popup window eg. ['selected str']
function! s:general_popup_callback(wid, select)
    let bufnr = s:popup_wins[a:wid].bufnr

    " only press enter a:select will be a list
    let has_selection = v:false 
    if type(a:select) == v:t_list
        let has_selection = v:true
        for Func in s:popup_wins[a:wid].close_funcs
            if type(Func) == v:t_func
                call Func(a:wid, a:select)
            endif
        endfor
    endif

    if has_key(s:popup_wins[a:wid], 'close_cb')
    \ && type(s:popup_wins[a:wid].close_cb) == v:t_func
        let opt = {}
        if has_selection
            let opt.selected_item = a:select
        endif
        call s:popup_wins[a:wid].close_cb(a:wid, opt)
    endif
    " restore cursor
    if &t_ve != s:t_ve
        let &t_ve = s:t_ve
    endif
    if s:triger_userautocmd
        let s:triger_userautocmd = 0
        if exists('#User#PopupClosed')
            doautocmd User PopupClosed
        endif
    endif
    call s:close_related_wins(a:wid)
    call remove(s:popup_wins, a:wid)
endfunction

function! s:create_buf() abort
    noa let bufnr = bufadd('')
    noa call bufload(bufnr)
    call setbufvar(bufnr, '&buflisted', 0)
    call setbufvar(bufnr, '&modeline', 0)
    call setbufvar(bufnr, '&buftype', 'nofile')
    call setbufvar(bufnr, '&swapfile', 0)
    " call setbufvar(bufnr, '&bufhidden', bufhidden)
    call setbufvar(bufnr, '&undolevels', -1)
    call setbufvar(bufnr, '&modifiable', 1)
    return bufnr
endfunction

" params
"   - bufnr: buffer number of the popup buffer
" return: 
"   if last result is changed
func! s:menu_update_cursor_item(menu_wid)
    let bufnr = s:popup_wins[a:menu_wid].bufnr
    let cursorlinepos = line('.', a:menu_wid)
    let linetext = getbufline(bufnr, cursorlinepos, cursorlinepos)[0]
    if s:popup_wins[a:menu_wid].cursor_item == linetext | return | end

    if has_key(s:popup_wins[a:menu_wid], 'move_cb')
        if type(s:popup_wins[a:menu_wid].move_cb) == v:t_func
            call s:popup_wins[a:menu_wid].move_cb(a:menu_wid,
                \ {'cursor_item': linetext,
                \ 'win_opts': s:popup_wins[a:menu_wid],
                \ 'last_cursor_item': s:popup_wins[a:menu_wid].cursor_item })
        endif
    endif
    let s:popup_wins[a:menu_wid].cursor_item = linetext
    return 1
endfunc

func! s:prompt_filter(wid, key) abort
    " echo [a:key, strgetchar(a:key, 0), strcharlen(a:key), strtrans(a:key)]
    let bufnr = s:popup_wins[a:wid].bufnr
    let line = s:popup_wins[a:wid].prompt.line
    let cur_pos = s:popup_wins[a:wid].cursor_args.cur_pos
    let max_pos = s:popup_wins[a:wid].cursor_args.max_pos
    let last_displayed_line = s:popup_wins[a:wid].prompt.displayed_line
    if len(a:key) == 1
        let ascii_val = char2nr(a:key)
        if ascii_val >=32 && ascii_val <= 126
            if cur_pos == len(line)
                let line .= a:key
            else
                let line = line[:cur_pos - 1] . a:key . line[cur_pos:]
            endif
            let s:popup_wins[a:wid].cursor_args.cur_pos += 1
        else
            return 1
        endif
    elseif a:key == "\<bs>"
        if cur_pos == len(line)
            let line = line[:-2]
        else
            let line = line[:cur_pos - 2] . line[cur_pos:]
        endif
        let s:popup_wins[a:wid].cursor_args.cur_pos = max([
        \ 0,
        \ cur_pos - 1
        \ ])
    elseif a:key == "\<Left>" || a:key == "\<C-f>"
            let s:popup_wins[a:wid].cursor_args.cur_pos = max([
            \ 0,
            \ cur_pos - 1
            \ ])
    elseif a:key == "\<Right>" || a:key == "\<C-b>"
        let s:popup_wins[a:wid].cursor_args.cur_pos = min([
        \ max_pos,
        \ cur_pos + 1
        \ ])
    else
        return 1
    endif

    if has_key(s:popup_wins[a:wid].prompt, 'input_cb') && s:popup_wins[a:wid].prompt.line != line
        let prompt = s:popup_wins[a:wid].prompt.promptchar
        let displayed_line = prompt . line . " "
        call popup_settext(a:wid, displayed_line)
        let s:popup_wins[a:wid].prompt.displayed_line = displayed_line
        let s:popup_wins[a:wid].prompt.line = line
        " after a keystroke, we need to update the menu popup to display
        " appropriate content
        call s:popup_wins[a:wid].prompt.input_cb(a:wid,
            \ {'str' : line,
            \ 'win_opts' : s:popup_wins[a:wid]})
    endif

    let s:popup_wins[a:wid].cursor_args.max_pos = len(line)
    let promptchar_len = s:popup_wins[a:wid].cursor_args.promptchar_len

    " cursor hl
    let hl = s:popup_wins[a:wid].cursor_args.highlight
    let cur_pos = s:popup_wins[a:wid].cursor_args.cur_pos
    call matchdelete(s:popup_wins[a:wid].cursor_args.mid, a:wid)
    let mid = matchaddpos(hl , [[1, promptchar_len + 1 + cur_pos]], 10, -1,  {'window': a:wid})
    let s:popup_wins[a:wid].cursor_args.mid = mid
    return 1
endfunc

func! s:menu_filter(wid, key) abort
    let bufnr = s:popup_wins[a:wid].bufnr
    let cursorlinepos = line('.', a:wid)
    let moved = 0
    if a:key == "\<Down>" || a:key == "\<c-n>"
        call win_execute(a:wid, 'norm j')
        let moved = 1
    elseif a:key == "\<Up>" || a:key == "\<c-p>"
        let moved = 1
        if s:popup_wins[a:wid].reverse_menu
            let textrows = popup_getpos(a:wid).height - 2
            let validrow = s:popup_wins[a:wid].validrow
            let minline = textrows - validrow + 1
            if cursorlinepos > minline
                call win_execute(a:wid, 'norm k')
            endif
        else
            call win_execute(a:wid, 'norm k')
        endif
    elseif a:key == "\<CR>"
        " if not passing second argument, popup_close will call user callback
        " with func(window-id, 0)
        " if passing second argument (popup_close(2, result)), popup_close will
        " call user callback with func(window-id, [result])
        let linetext = getbufline(bufnr, cursorlinepos, cursorlinepos)[0]
        if linetext == ''
            call popup_close(a:wid)
        else
            call popup_close(a:wid, [linetext])
        endif
    elseif a:key == "\<Esc>" || a:key == "\<c-c>" || a:key == "\<c-[>"
        call popup_close(a:wid)
    else
        return 0
    endif

    if moved
        call s:menu_update_cursor_item(a:wid)
    endif
    return 1
endfunc

function! utils#popup#create_popup(bufnr, opts) abort
    let opts = {
      \ 'line'            :  a:opts.line,
      \ 'col'             :  a:opts.col,
      \ 'minwidth'        :  a:opts.width,
      \ 'maxwidth'        :  a:opts.width,
      \ 'minheight'       :  a:opts.height,
      \ 'maxheight'       :  a:opts.height,
      \ 'scrollbar'       :  v:false,
      \ 'padding'         :  [0, 0, 0, 0],
      \ 'zindex'          :  1000,
      \ 'wrap'            :  0,
      \ 'callback'        :  function('s:general_popup_callback'),
      \ 'border'          :  [1],
      \ 'borderchars'     :  ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
      \ 'borderhighlight' :  ['Normal'],
      \ 'highlight'       :  'Normal',
      \ }

    if has_key(a:opts, 'enable_border') && !a:opts.enable_border
        call remove(opts, 'border')
    endif

    " we will put user callback in close_funcs, and call it in general_popup_callback
    for key in ['filter', 'border', 'borderhighlight', 'highlight', 'borderchars',
        \ 'scrollbar', 'padding', 'cursorline', 'wrap', 'zindex', 'title']
        if has_key(a:opts, key)
            let opts[key] = a:opts[key]
        endif
    endfor
    let noscrollbar_width = opts.minwidth
    if opts.scrollbar
        let opts.minwidth -= 1
        let opts.maxwidth -= 1
    endif

    if has_key(opts, 'filter')
        let opts.mapping = v:false
    endif
    let wid = popup_create(a:bufnr, opts)
    let s:popup_wins[wid] = {
        \ 'close_funcs'        :  [],
        \ 'highlights'         :  {},
        \ 'noscrollbar_width'  :  noscrollbar_width,
        \ 'validrow'           :  0,
        \ 'move_cb'            :  v:null,
        \ 'line'               :  a:opts.line,
        \ 'col'                :  a:opts.col,
        \ 'width'              :  a:opts.width,
        \ 'height'             :  a:opts.height,
        \ 'reverse_menu'       :  0,
        \ 'cursor_item'        :  v:null,
        \ 'wid'                :  wid,
        \ 'update_delay_timer' :  -1,
        \ 'prompt_delay_timer' :  -1,
        \ }

    for key in ['reverse_menu', 'move_cb', 'close_cb']
        if has_key(a:opts, key)
            let s:popup_wins[wid][key] = a:opts[key]
        endif
    endfor
    if has_key(a:opts, 'callback')
        call add(s:popup_wins[wid].close_funcs, a:opts.callback)
    endif
    return wid
endfunction

function! utils#popup#new(opts) abort
    let width   = get(a:opts, 'width', 0.4)
    let height  = get(a:opts, 'height', 0.4)
    let xoffset = get(a:opts, 'xoffset', 0.3)
    let yoffset = get(a:opts, 'yoffset', 0.3)

    " Use current window size for positioning relatively positioned popups
    let columns = &columns
    let lines = &lines

    " Size and position
    let final_width = min([max([1, width >= 1 ? width : float2nr(columns * width)]), columns])
    let final_height = min([max([1, height >= 1 ? height : float2nr(lines * height)]), lines])

    let line = yoffset >= 1 ? yoffset : float2nr(yoffset * lines)
    let col = xoffset >=  1 ? xoffset : float2nr(xoffset * columns)

    " Managing the differences
    let line = min([max([0, line]), lines - final_height])
    let col = min([max([0, col]), columns - final_width])

    let opts = extend(a:opts, {
    \ 'line'   :  line,
    \ 'col'    :  col,
    \ 'width'  :  final_width,
    \ 'height' :  final_height
    \ })

    let bufnr = s:create_buf()
    let wid = utils#popup#create_popup(bufnr, opts)

    let s:popup_wins[wid].bufnr = bufnr

    return [wid, bufnr]
endfunction

function! utils#popup#menu_settext(wid, text, ...) abort
    if type(a:text) != v:t_list
        echoerr 'text must be a list'
    endif
    if !has_key(s:popup_wins, a:wid) | return | endif
    let text = a:text
    let old_cursor_pos = line('$', a:wid) - line('.', a:wid)

    let s:popup_wins[a:wid].validrow = len(a:text)
    let textrows = popup_getpos(a:wid).height - 2
    if s:popup_wins[a:wid].reverse_menu
        let text = reverse(a:text)
        if len(text) < textrows
            let text = repeat([''], textrows - len(text)) + text
        endif
    endif

    if popup_getoptions(a:wid).scrollbar
        let curwidth = popup_getpos(a:wid).width
        let noscrollbar_width = s:popup_wins[a:wid].noscrollbar_width
        if len(text) > textrows && curwidth != noscrollbar_width - 1
            let width = noscrollbar_width - 1
           call popup_move(a:wid, {'minwidth': width, 'maxwidth': width})
        elseif len(text) <= textrows && curwidth != noscrollbar_width
            let width = noscrollbar_width
            call popup_move(a:wid, {'minwidth': width, 'maxwidth': width})
        endif
    endif

    call popup_settext(a:wid, text)
    if s:popup_wins[a:wid].reverse_menu
        let new_line_length = line('$', a:wid)
        let cursor_pos = new_line_length - old_cursor_pos
        call win_execute(a:wid, 'normal! '.new_line_length.'zb')
        call win_execute(a:wid, 'normal! '.cursor_pos.'G')
        " echom [old_cursor_pos, cursor_pos, line('$')]
    endif

    call s:menu_update_cursor_item(a:wid)
endfunction

" params:
"   - wid: popup window id
"   - hi_list: list of position to highlight eg. [[1, [1,2,3]]]
function! utils#popup#menu_sethl(name, wid, hi_list, ...)
    let hl = 'Error'
    if !has_key(s:popup_wins, a:wid) | return | endif
    let hi_list = a:hi_list[:70]

    let textrows = popup_getpos(a:wid).height - 2
    if len(hi_list) == 0
        if has_key(s:popup_wins[a:wid]['highlights'], a:name)
            call matchdelete(s:popup_wins[a:wid]['highlights'][a:name], a:wid)
            call remove(s:popup_wins[a:wid]['highlights'], a:name)
        endif
        return
    endif
    let height = max([hi_list[-1][0], textrows])
    if s:popup_wins[a:wid].reverse_menu
        let hi_list = reduce(a:hi_list, {acc, v -> add(acc, [height - v[0] + 1, v[1]])}, [])
    endif

    let his = []
    for hlpos in hi_list
        let line = hlpos[0]
        let col_list = hlpos[1]
        if type(col_list) == v:t_list
            for col in col_list
                call add(his, [line, col])
            endfor
        elseif type(col_list) == v:t_number
            if col_list > 0
                call add(his, [line, col_list])
            endif
        endif
    endfor
    if has_key(s:popup_wins[a:wid]['highlights'], a:name) &&
        \ s:popup_wins[a:wid]['highlights'][a:name] != -1
        call matchdelete(s:popup_wins[a:wid]['highlights'][a:name], a:wid)
        call remove(s:popup_wins[a:wid]['highlights'], a:name)
    endif
    " pass empty list to matchaddpos will cause error
    if len(his) == 0 | return | endif
    let mid = matchaddpos(hl, his, 10, -1,  {'window': a:wid})
    let s:popup_wins[a:wid]['highlights'][a:name] = mid
    return mid
endfunction

function! utils#popup#prompt(opts)
    let opts = {
    \ 'width'  :  0.4,
    \ 'height' :  1,
    \ 'filter' :  function('s:prompt_filter')
    \ }
    let opts            =  extend(opts, a:opts)
    let [wid, bufnr]    =  utils#popup#new(opts)
    let prompt_char     =  '> '
    let prompt_char_len =  strcharlen(prompt_char)
    let prompt_opt      =  {
    \ 'line'           :  '',
    \ 'promptchar'     :  prompt_char,
    \ 'displayed_line' :  prompt_char . " ",
    \ }

    let cursor_args = {
    \ 'min_pos'        :  0,
    \ 'max_pos'        :  0,
    \ 'promptchar_len' :  prompt_char_len,
    \ 'cur_pos'        :  0,
    \ 'highlight'      :  'Search',
    \ 'mid'            :  -1,
    \ }

    let s:popup_wins[wid].cursor_args = cursor_args
    let s:popup_wins[wid].prompt = prompt_opt
    if has_key(a:opts, 'input_cb') && type(a:opts.input_cb) == v:t_func
        let s:popup_wins[wid].prompt.input_cb = a:opts.input_cb
    endif
    call popup_settext(wid, prompt_opt.displayed_line)

    " set cursor
    let mid = matchaddpos(cursor_args.highlight , [[1, prompt_char_len + 1 + cursor_args.cur_pos]], 10, -1,  {'window': wid})
    let s:popup_wins[wid].cursor_args.mid = mid
    return wid
endfunction

function! utils#popup#menu(opts) abort
    let opts = {
    \ 'width'      : 0.4,
    \ 'height'     : 17,
    \ 'yoffset'    : 0.3,
    \ 'cursorline' : 1,
    \ 'filter'     : function('s:menu_filter'),
    \ 'wrap'       : 0,
    \ }

    let opts = extend(opts, a:opts)
    let [wid, bufnr] = utils#popup#new(opts)

    " don't set this, popup has its own cursorline option
    "call setwinvar(wid, '&cursorline', '1')
    "call setwinvar(wid, '&cursorlineopt', 'line')
    return wid
endfunc

function! utils#popup#preview(opts) abort
    let opts = {
    \ 'width'      : 0.4,
    \ 'height'     : 19,
    \ 'yoffset'    : 0.3,
    \ 'cursorline' : 0,
    \ 'wrap'       : 0,
    \ }

    let opts = extend(opts, a:opts)
    let [wid, bufnr] = utils#popup#new(opts)

    call setwinvar(wid, '&number', '1')
    call setwinvar(wid, '&wrap', '1')
    return wid
endfunc

" sometimes a layout contains multiple windows, we need to close them all
" To do that we need to connect them
func! s:connect_win(wins)
    let allwins = values(a:wins)
    for [k, wid] in items(a:wins)
        let newlist = reduce(allwins, {acc, v -> v != wid ? add(acc, v) : acc }, [])
        let s:popup_wins[wid].related_win = newlist
        let s:popup_wins[wid].partids = a:wins
    endfor
endfunc

" params:
"   - opts: options: dictonary contains following keys:
"       - select_cb: callback function when a value is selected(press enter)
"       - move_cb: callback function when cursor moves to a new value
"       - input_cb: callback function when user input something
" return: 
"   [menu_wid, prompt_wid, preview_wid]
function! utils#popup#selection(opts) abort
    let user_opts = a:opts 

    let s:triger_userautocmd = 1
    let has_preview = has_key(user_opts, 'preview') && user_opts.preview

    let width   = 0.8
    let height  = 0.8
    let width   = has_key(user_opts, 'width') ? user_opts.width : width
    let height  = has_key(user_opts, 'height') ? user_opts.height : height
    let xoffset = width < 1 ? (1 - width) / 2 : (&columns  - width) / 2
    let yoffset = height < 1 ? (1 - height) / 2 : (&lines - height) / 2

    let preview_ratio = 0.5
    let preview_ratio = has_key(user_opts, 'preview_ratio') ? user_opts.preview_ratio : preview_ratio

    " user's input always override the default
    let xoffset =  has_key(user_opts, 'xoffset') ? user_opts.xoffset : xoffset
    let yoffset =  has_key(user_opts, 'yoffset') ? user_opts.yoffset : yoffset

    " convert all pos to number
    let yoffset       =  yoffset < 1 ? float2nr(yoffset * &lines) : float2nr(yoffset)
    let xoffset       =  xoffset < 1 ? float2nr(xoffset * &columns) : float2nr(xoffset)
    let height        =  height < 1 ? float2nr(height * &lines) : float2nr(height)
    let width         =  width < 1 ? float2nr(width * &columns) : float2nr(width)

    if has_preview
        let preview_width = float2nr(width * preview_ratio)
        let menu_width    = width - preview_width
    else
        let menu_width    = width
    endif

    let prompt_height =  3
    let menu_height   =  height - prompt_height

    let menu_opts = {
    \ 'callback'     :  has_key(user_opts, 'select_cb') ? user_opts.select_cb : v:null,
    \ 'close_cb'     :  has_key(user_opts, 'close_cb') ? user_opts.close_cb : v:null,
    \ 'scrollbar'    :  has_key(user_opts, 'scrollbar') ? user_opts.scrollbar : 1,
    \ 'reverse_menu' :  has_key(user_opts, 'reverse_menu') ? user_opts.reverse_menu : 1,
    \ 'yoffset'      :  yoffset,
    \ 'xoffset'      :  xoffset,
    \ 'width'        :  menu_width,
    \ 'height'       :  menu_height,
    \ 'zindex'       :  1200,
    \ }

    for key in ['title', 'move_cb']
        if has_key(user_opts, key)
            let menu_opts[key] = user_opts[key]
        endif
    endfor

    let menu_wid = utils#popup#menu(menu_opts)

    let prompt_yoffset = s:popup_wins[menu_wid].line + s:popup_wins[menu_wid].height
    let prompt_opts = {
    \ 'yoffset'  :  prompt_yoffset + 2,
    \ 'xoffset'  :  xoffset,
    \ 'width'    :  menu_width,
    \ 'input_cb' :  has_key(user_opts, 'input_cb') ? user_opts.input_cb : v:null,
    \ }
    let prompt_wid = utils#popup#prompt(prompt_opts)
    let s:popup_wins[prompt_wid].partids = {'menu': menu_wid}

    let connect_wins = {
    \ 'menu'   :  menu_wid,
    \ 'prompt' :  prompt_wid,
    \ }

    if has_key(user_opts, 'infowin') && user_opts.infowin
        let [info_wid, info_bufnr] = utils#popup#new({
        \ 'width'         :  menu_width - 2,
        \ 'height'        :  1,
        \ 'yoffset'       :  yoffset + 1,
        \ 'xoffset'       :  xoffset + 1,
        \ 'padding'       :  [0, 0, 0, 1],
        \ 'zindex'        :  2000,
        \ 'enable_border' :  0,
        \ })
        let connect_wins.info = info_wid
    endif

    let ret = [menu_wid, prompt_wid]
    if has_preview
        let preview_xoffset =  s:popup_wins[menu_wid].col + s:popup_wins[menu_wid].width
        let menu_row        =  s:popup_wins[menu_wid].line
        let prompt_row      =  s:popup_wins[prompt_wid].line
        let prompt_height   =  s:popup_wins[prompt_wid].height
        let preview_height  =  prompt_row - menu_row + prompt_height
        let preview_opts    =  {
        \ 'width'   :  preview_width,
        \ 'height'  :  preview_height,
        \ 'yoffset' :  yoffset,
        \ 'xoffset' :  preview_xoffset + 2,
        \ }
        let preview_wid          =  utils#popup#preview(preview_opts)
        let connect_wins.preview =  preview_wid
        call add(ret, preview_wid)
    endif
    let s:t_ve = &t_ve
    setlocal t_ve=
    call s:connect_win(connect_wins)
    return ret
endfunc

