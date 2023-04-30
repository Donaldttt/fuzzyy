" s:popup_wins has those keys:
"  bufnr: bufnr of the popup buffer
"  related_win: list of related windows
"  close_funcs: list of functions to be called when popup is closed
"  highlights: list of highlight match in the popup buffer
def s:CloseRelatedWins(wid: number, ...li: list<any>)
    for w in s:popup_wins[wid].related_win
        if has_key(s:popup_wins, w)
            s:popup_wins[w].related_win = []
        endif
        popup_close(w)
    endfor
enddef

" params:
"   - wid: window id of the popup window
"   - select: the selected item in the popup window eg. ['selected str']
def s:GeneralPopupCallback(wid: number, select: any)
    var bufnr = s:popup_wins[wid].bufnr

    # only press enter select will be a list
    var has_selection = v:false 
    if type(select) == v:t_list
        has_selection = v:true
        for Func in s:popup_wins[wid].close_funcs
            if type(Func) == v:t_func
                Func(wid, select)
            endif
        endfor
    endif

    if has_key(s:popup_wins[wid], 'close_cb')
      && type(s:popup_wins[wid].close_cb) == v:t_func
        var opt = {}
        if has_selection
            opt.selected_item = select
        endif
        s:popup_wins[wid].close_cb(wid, opt)
    endif
    # restore cursor
    if &t_ve != s:t_ve
        &t_ve = s:t_ve
    endif
    if s:triger_userautocmd
        s:triger_userautocmd = 0
        if exists('#User#PopupClosed')
            doautocmd User PopupClosed
        endif
    endif
    s:CloseRelatedWins(wid)
    remove(s:popup_wins, wid)
enddef

def s:CreateBuf(): number
    noa var bufnr = bufadd('')
    noa bufload(bufnr)
    setbufvar(bufnr, '&buflisted', 0)
    setbufvar(bufnr, '&modeline', 0)
    setbufvar(bufnr, '&buftype', 'nofile')
    setbufvar(bufnr, '&swapfile', 0)
    setbufvar(bufnr, '&undolevels', -1)
    setbufvar(bufnr, '&modifiable', 1)
    return bufnr
enddef

" params
"   - bufnr: buffer number of the popup buffer
" return: 
"   if last result is changed
def s:MenuUpdateCursorItem(menu_wid: number): number
    var bufnr = s:popup_wins[menu_wid].bufnr
    var cursorlinepos = line('.', menu_wid)
    var linetext = getbufline(bufnr, cursorlinepos, cursorlinepos)[0]
    if s:popup_wins[menu_wid].cursor_item == linetext 
        return 0
    endif

    if has_key(s:popup_wins[menu_wid], 'move_cb')
        if type(s:popup_wins[menu_wid].move_cb) == v:t_func
            call s:popup_wins[menu_wid].move_cb(menu_wid, {
                cursor_item: linetext,
                win_opts: s:popup_wins[menu_wid],
                last_cursor_item: s:popup_wins[menu_wid].cursor_item 
                })
        endif
    endif
    s:popup_wins[menu_wid].cursor_item = linetext
    return 1
enddef

def PromptFilter(wid: number, key: string): number
    # echo [key, strgetchar(key, 0), strcharlen(key), strtrans(key)]
    var bufnr = s:popup_wins[wid].bufnr
    var line = s:popup_wins[wid].prompt.line
    var cur_pos = s:popup_wins[wid].cursor_args.cur_pos
    var max_pos = s:popup_wins[wid].cursor_args.max_pos
    var last_displayed_line = s:popup_wins[wid].prompt.displayed_line
    if len(key) == 1
        var ascii_val = char2nr(key)
        if ascii_val >= 32 && ascii_val <= 126
            if cur_pos == len(line)
                line ..= key
            else
                line = line[: cur_pos - 1] .. key .. line[cur_pos :]
            endif
            s:popup_wins[wid].cursor_args.cur_pos += 1
        else
            return 1
        endif
    elseif key == "\<bs>"
        if cur_pos == len(line)
            line = line[: -2]
        else
            line = line[: cur_pos - 2] .. line[cur_pos :]
        endif
        s:popup_wins[wid].cursor_args.cur_pos = max([
          0,
          cur_pos - 1
          ])
    elseif key == "\<Left>" || key == "\<C-f>"
            s:popup_wins[wid].cursor_args.cur_pos = max([
              0,
              cur_pos - 1
              ])
    elseif key == "\<Right>" || key == "\<C-b>"
        s:popup_wins[wid].cursor_args.cur_pos = min([
          max_pos,
          cur_pos + 1
          ])
    else
        return 1
    endif

    if has_key(s:popup_wins[wid].prompt, 'input_cb') && s:popup_wins[wid].prompt.line != line
        var prompt = s:popup_wins[wid].prompt.promptchar
        var displayed_line = prompt .. line .. " "
        popup_settext(wid, displayed_line)
        s:popup_wins[wid].prompt.displayed_line = displayed_line
        s:popup_wins[wid].prompt.line = line
        # after a keystroke, we need to update the menu popup to display
        # appropriate content
        s:popup_wins[wid].prompt.input_cb(wid, {
                str: line,
                win_opts: s:popup_wins[wid]})
    endif

    s:popup_wins[wid].cursor_args.max_pos = len(line)
    var promptchar_len = s:popup_wins[wid].cursor_args.promptchar_len

    # cursor hl
    var hl = s:popup_wins[wid].cursor_args.highlight
    cur_pos = s:popup_wins[wid].cursor_args.cur_pos
    matchdelete(s:popup_wins[wid].cursor_args.mid, wid)
    var mid = matchaddpos(hl, [[1, promptchar_len + 1 + cur_pos]], 10, -1,  {window: wid})
    s:popup_wins[wid].cursor_args.mid = mid
    return 1
enddef

def MenuFilter(wid: number, key: string): number
    var bufnr = s:popup_wins[wid].bufnr
    var cursorlinepos = line('.', wid)
    var moved = 0
    if key == "\<Down>" || key == "\<c-n>"
        win_execute(wid, 'norm j')
        moved = 1
    elseif key == "\<Up>" || key == "\<c-p>"
        moved = 1
        if s:popup_wins[wid].reverse_menu
            var textrows = popup_getpos(wid).height - 2
            var validrow = s:popup_wins[wid].validrow
            var minline = textrows - validrow + 1
            if cursorlinepos > minline
                win_execute(wid, 'norm k')
            endif
        else
            win_execute(wid, 'norm k')
        endif
    elseif key == "\<CR>"
        # if not passing second argument, popup_close will call user callback
        # with func(window-id, 0)
        # if passing second argument (popup_close(2, result)), popup_close will
        # call user callback with func(window-id, [result])
        var linetext = getbufline(bufnr, cursorlinepos, cursorlinepos)[0]
        if linetext == ''
            popup_close(wid)
        else
            popup_close(wid, [linetext])
        endif
    elseif key == "\<Esc>" || key == "\<c-c>" || key == "\<c-[>"
        popup_close(wid)
    else
        return 0
    endif

    if moved
        s:MenuUpdateCursorItem(wid)
    endif
    return 1
enddef

def s:CreatePopup(bufnr: number, args: dict<any>): number
    var opts = {
       line:  args.line,
       col:  args.col,
       minwidth:  args.width,
       maxwidth:  args.width,
       minheight:  args.height,
       maxheight:  args.height,
       scrollbar:  v:false,
       padding:  [0, 0, 0, 0],
       zindex:  1000,
       wrap:  0,
       callback:  function('s:GeneralPopupCallback'),
       border:  [1],
       borderchars:  ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
       borderhighlight:  ['Normal'],
       highlight:  'Normal', }

    if has_key(args, 'enable_border') && !args.enable_border
        remove(opts, 'border')
    endif

    # we will put user callback in close_funcs, and call it in GeneralPopupCallback
    for key in ['filter', 'border', 'borderhighlight', 'highlight', 'borderchars',
          'scrollbar', 'padding', 'cursorline', 'wrap', 'zindex', 'title']
        if has_key(args, key)
            opts[key] = args[key]
        endif
    endfor
    var noscrollbar_width = opts.minwidth
    if opts.scrollbar
        opts.minwidth -= 1
        opts.maxwidth -= 1
    endif

    if has_key(opts, 'filter')
        opts.mapping = v:false
    endif
    var wid = popup_create(bufnr, opts)
    s:popup_wins[wid] = {
         close_funcs:  [],
         highlights:  {},
         noscrollbar_width:  noscrollbar_width,
         validrow:  0,
         move_cb:  v:null,
         line:  args.line,
         col:  args.col,
         width:  args.width,
         height:  args.height,
         reverse_menu:  0,
         cursor_item:  v:null,
         wid:  wid,
         update_delay_timer:  -1,
         prompt_delay_timer:  -1,
         }

    for key in ['reverse_menu', 'move_cb', 'close_cb']
        if has_key(args, key)
            s:popup_wins[wid][key] = args[key]
        endif
    endfor
    if has_key(args, 'callback')
        add(s:popup_wins[wid].close_funcs, args.callback)
    endif
    return wid
enddef

def s:NewPopup(args: dict<any>): list<number>
    var width   = get(args, 'width', 0.4)
    var height  = get(args, 'height', 0.4)
    var xoffset = get(args, 'xoffset', 0.3)
    var yoffset = get(args, 'yoffset', 0.3)

    # Use current window size for positioning relatively positioned popups
    var columns = &columns
    var lines = &lines

    # Size and position
    var final_width = min([max([1, width >= 1 ? width : float2nr(columns * width)]), columns])
    var final_height = min([max([1, height >= 1 ? height : float2nr(lines * height)]), lines])

    var line = yoffset >= 1 ? yoffset : float2nr(yoffset * lines)
    var col = xoffset >=  1 ? xoffset : float2nr(xoffset * columns)

    # Managing the differences
    line = min([max([0, line]), lines - final_height])
    col = min([max([0, col]), columns - final_width])

    var opts = extend(args, {
     line:  line,
     col:  col,
     width:  final_width,
     height:  final_height
     })

    var bufnr = s:CreateBuf()
    var wid = s:CreatePopup(bufnr, opts)

    s:popup_wins[wid].bufnr = bufnr

    return [wid, bufnr]
enddef

def MenuSettext(wid: number, text_list: list<string>)
    if type(text_list) != v:t_list
        echoerr 'text must be a list'
    endif
    if !has_key(s:popup_wins, wid) | return | endif
    var text = text_list
    var old_cursor_pos = line('$', wid) - line('.', wid)

    s:popup_wins[wid].validrow = len(text_list)
    var textrows = popup_getpos(wid).height - 2
    if s:popup_wins[wid].reverse_menu
        text = reverse(text_list)
        if len(text) < textrows
            text = repeat([''], textrows - len(text)) + text
        endif
    endif

    if popup_getoptions(wid).scrollbar
        var curwidth = popup_getpos(wid).width
        var noscrollbar_width = s:popup_wins[wid].noscrollbar_width
        if len(text) > textrows && curwidth != noscrollbar_width - 1
            var width = noscrollbar_width - 1
           popup_move(wid, {'minwidth': width, 'maxwidth': width})
        elseif len(text) <= textrows && curwidth != noscrollbar_width
            var width = noscrollbar_width
            popup_move(wid, {'minwidth': width, 'maxwidth': width})
        endif
    endif

    popup_settext(wid, text)
    if s:popup_wins[wid].reverse_menu
        var new_line_length = line('$', wid)
        var cursor_pos = new_line_length - old_cursor_pos
        win_execute(wid, 'normal! ' .. new_line_length .. 'zb')
        win_execute(wid, 'normal! ' .. cursor_pos .. 'G')
        # echom [old_cursor_pos, cursor_pos, line('$')]
    endif

    s:MenuUpdateCursorItem(wid)
enddef
function! utils#popup#menu_settext(wid, text, ...) abort
    call MenuSettext(a:wid, a:text)
endfunction

" params:
"   - wid: popup window id
"   - hi_list: list of position to highlight eg. [[1, [1,2,3]]]
def MenuSethl(name: string, wid: number, hl_list_raw: list<any>): number
    const hl = 'Error'
    if !has_key(s:popup_wins, wid)
        return -1
    endif
    var hl_list = hl_list_raw[: 70]

    var textrows = popup_getpos(wid).height - 2
    var height = max([len(hl_list_raw), textrows])
    if s:popup_wins[wid].reverse_menu
        hl_list = reduce(hl_list_raw, (acc, v) => add(acc, [height - v[0] + 1, v[1]]), [])
    endif

    var his = []
    for hlpos in hl_list
        var line = hlpos[0]
        var col_list = hlpos[1]
        if type(col_list) == v:t_list
            for col in col_list
                add(his, [line, col])
            endfor
        elseif type(col_list) == v:t_number
            if col_list > 0
                add(his, [line, col_list])
            endif
        endif
    endfor
    if has_key(s:popup_wins[wid]['highlights'], name) &&
        s:popup_wins[wid]['highlights'][name] != -1
        matchdelete(s:popup_wins[wid]['highlights'][name], wid)
        remove(s:popup_wins[wid]['highlights'], name)
    endif
    # pass empty list to matchaddpos will cause error
    if len(his) == 0
        return -1
    endif
    var mid = matchaddpos(hl, his, 10, -1,  {'window': wid})
    s:popup_wins[wid]['highlights'][name] = mid
    return mid
enddef
function! utils#popup#menu_sethl(name, wid, hi_list, ...)
    call MenuSethl(a:name, a:wid, a:hi_list)
endfunction

function! utils#popup#prompt(opts)
    let opts = {
    \ 'width'  :  0.4,
    \ 'height' :  1,
    \ 'filter' :  function('PromptFilter')
    \ }
    let opts            =  extend(opts, a:opts)
    let [wid, bufnr]    =  s:NewPopup(opts)
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
    \ 'filter'     : function('MenuFilter'),
    \ 'wrap'       : 0,
    \ }

    let opts = extend(opts, a:opts)
    let [wid, bufnr] = s:NewPopup(opts)

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
    let [wid, bufnr] = s:NewPopup(opts)

    call setwinvar(wid, '&number', '1')
    call setwinvar(wid, '&wrap', '1')
    return wid
endfunc

" sometimes a layout contains multiple windows, we need to close them all
" To do that we need to connect them
def ConnectWin(wins: dict<any>)
    var allwins = values(wins)
    for [k, wid] in items(wins)
        var newlist = reduce(allwins, (acc, v) => v != wid ? add(acc, v) : acc, [])
        s:popup_wins[wid].related_win = newlist
        s:popup_wins[wid].partids = wins
    endfor
enddef

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
    let s:popup_wins = {}
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
        let [info_wid, info_bufnr] = s:NewPopup({
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
    call ConnectWin(connect_wins)
    return ret
endfunc

