vim9script
var popup_wins: dict<any>
var triger_userautocmd: number
var t_ve = &t_ve
var guicursor = &guicursor

# user can register callback for any key
var key_callbacks: dict<any>

var keymaps: dict<any> = {
    'menu_up': ["\<c-p>", "\<Up>"],
    'menu_down': ["\<c-n>", "\<Down>"],
    'menu_select': ["\<CR>"],
    'preview_up': ["\<c-u>"],
    'preview_down': ["\<c-d>"],
    'cursor_begining': ["\<c-a>"],
    'cursor_end': ["\<c-e>"],
    'delete_all': ["\<c-k>"],
    'delete_prefix': [],
    'exit': ["\<Esc>", "\<c-c>", "\<c-[>"],
}

keymaps = exists('g:fuzzyy_keymaps') && type(g:fuzzyy_keymaps) == v:t_dict ?
    extend(keymaps, g:fuzzyy_keymaps) : keymaps
var menu_matched_hl = exists('g:fuzzyy_menu_matched_hl') ?
    g:fuzzyy_menu_matched_hl : 'cursearch'

# popup_wins has those keys:
#  bufnr: bufnr of the popup buffer
#  related_win: list of related windows
#  close_funcs: list of functions to be called when popup is closed
#  highlights: list of highlight match in the popup buffer
def CloseRelatedWins(wid: number, ...li: list<any>)
    for w in popup_wins[wid].related_win
        if has_key(popup_wins, w)
            popup_wins[w].related_win = []
        endif
        popup_close(w)
    endfor
enddef

export def SetPopupWinProp(wid: number, key: string, val: any)
    if has_key(popup_wins, wid) && has_key(popup_wins[wid], key)
        popup_wins[wid][key] = val
    else
        echoerr 'SetPopupWinProp: key not exist'
    endif
enddef

# params:
#   - wid: window id of the popup window
#   - select: the selected item in the popup window eg. ['selected str']
def GeneralPopupCallback(wid: number, select: any)
    CloseRelatedWins(wid)
    # only press enter select will be a list
    var has_selection = v:false
    if type(select) == v:t_list
        has_selection = v:true
        for Func in popup_wins[wid].close_funcs
            if type(Func) == v:t_func
                Func(wid, select)
            endif
        endfor
    endif

    if has_key(popup_wins[wid], 'close_cb')
      && type(popup_wins[wid].close_cb) == v:t_func
        var opt = {}
        if has_selection
            opt.selected_item = select[0]
        endif
        opt.cursor_item = popup_wins[wid].cursor_item
        popup_wins[wid].close_cb(wid, opt)
    endif
    # restore cursor
    if &t_ve != t_ve
        &t_ve = t_ve
    endif
    if &guicursor != guicursor
        &guicursor = guicursor
    endif
    if triger_userautocmd
        triger_userautocmd = 0
        if exists('#User#PopupClosed')
            doautocmd User PopupClosed
        endif
    endif
    remove(popup_wins, wid)
enddef

def CreateBuf(): number
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

# params
#   - bufnr: buffer number of the popup buffer
# return:
#   if last result is changed
def MenuUpdateCursorItem(menu_wid: number): number
    var bufnr = popup_wins[menu_wid].bufnr
    var cursorlinepos = line('.', menu_wid)
    var linetext = getbufline(bufnr, cursorlinepos, cursorlinepos)[0]
    if popup_wins[menu_wid].cursor_item == linetext
        return 0
    endif

    if has_key(popup_wins[menu_wid], 'move_cb')
        if type(popup_wins[menu_wid].move_cb) == v:t_func
            call popup_wins[menu_wid].move_cb(menu_wid, {
                cursor_item: linetext,
                win_opts: popup_wins[menu_wid],
                last_cursor_item: popup_wins[menu_wid].cursor_item
                })
        endif
    endif
    popup_wins[menu_wid].cursor_item = linetext
    return 1
enddef

# set prompt content
# params
#   - content: string to be set as prompt
export def SetPrompt(wid: number, content: string)
    for c in content
        PromptFilter(wid, c)
    endfor
enddef

def PromptFilter(wid: number, key: string): number
    var bufnr = popup_wins[wid].bufnr
    var line = copy(popup_wins[wid].prompt.line)
    var cur_pos = popup_wins[wid].cursor_args.cur_pos # index by number of char not byte
    var max_pos = popup_wins[wid].cursor_args.max_pos
    var last_displayed_line = popup_wins[wid].prompt.displayed_line
    var ascii_val = char2nr(key)
    if (len(key) == 1 && ascii_val >= 32 && ascii_val <= 126)
        || (ascii_val >= 19968 && ascii_val <= 205743) # chinese or more character support
        if cur_pos == len(line)
            line->add(key)
        else
            var pre = cur_pos - 1 >= 0 ? line[: cur_pos - 1] : []
            line = pre + [key] + line[cur_pos :]
        endif
        cur_pos += 1
    elseif key == "\<bs>"
        if cur_pos == len(line)
            line = line[: -2]
        else
            var before = cur_pos - 2 >= 0 ? line[: cur_pos - 2] : []
            line = before + line[cur_pos :]
        endif
        cur_pos = max([ 0, cur_pos - 1 ])
    elseif key == "\<Left>" || key == "\<c-b>"
        cur_pos = max([ 0, cur_pos - 1 ])
    elseif key == "\<Right>" || key == "\<c-f>"
        cur_pos = min([ max_pos, cur_pos + 1 ])
    elseif index(keymaps['cursor_begining'], key) >= 0
        cur_pos = 0
    elseif index(keymaps['cursor_end'], key) >= 0
        cur_pos = max_pos
    elseif index(keymaps['delete_all'], key) >= 0
        line = []
        cur_pos = 0
    elseif index(keymaps['delete_prefix'], key) >= 0
        line = line[cur_pos :]
        cur_pos = 0
    else
        # catch all unhandled keys
        return 1
    endif
    popup_wins[wid].cursor_args.cur_pos = cur_pos

    var line_str = join(line, '')
    if has_key(popup_wins[wid].prompt, 'input_cb') && popup_wins[wid].prompt.line != line
        var prompt = popup_wins[wid].prompt.promptchar
        var displayed_line = prompt .. line_str .. " "
        popup_settext(wid, displayed_line)
        popup_wins[wid].prompt.displayed_line = displayed_line
        popup_wins[wid].prompt.line = line
        # after a keystroke, we need to update the menu popup to display
        # appropriate content
        popup_wins[wid].prompt.input_cb(wid, {
                str: line_str,
                win_opts: popup_wins[wid]})
    endif

    popup_wins[wid].cursor_args.max_pos = len(line)
    var promptchar_len = popup_wins[wid].cursor_args.promptchar_len

    # cursor hl
    var hl = popup_wins[wid].cursor_args.highlight
    matchdelete(popup_wins[wid].cursor_args.mid, wid)
    var hi_end_pos = promptchar_len + 1
    if cur_pos > 0
        hi_end_pos += len(join(line[: cur_pos - 1], ''))
    endif
    var mid = matchaddpos(hl, [[1, hi_end_pos]], 10, -1, {window: wid})
    popup_wins[wid].cursor_args.mid = mid
    return 1
enddef

def MenuFilter(wid: number, key: string): number
    var bufnr = popup_wins[wid].bufnr
    var cursorlinepos = line('.', wid)
    var moved = 0
    if index(keymaps['menu_down'], key) >= 0
        win_execute(wid, 'norm j')
        moved = 1
    elseif index(keymaps['menu_up'], key) >= 0
        moved = 1
        if popup_wins[wid].reverse_menu
            var textrows = popup_getpos(wid).height - 2
            var validrow = popup_wins[wid].validrow
            var minline = textrows - validrow + 1
            if cursorlinepos > minline
                win_execute(wid, 'norm k')
            endif
        else
            win_execute(wid, 'norm k')
        endif
    elseif index(keymaps['menu_select'], key) >= 0
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
    elseif index(keymaps['exit'], key) >= 0
        popup_close(wid)
    elseif has_key(key_callbacks, key)
        key_callbacks[key]()
    else
        return 0
    endif

    if moved
        MenuUpdateCursorItem(wid)
    endif
    return 1
enddef

def PreviewFilter(wid: number, key: string): number
    if index(keymaps['preview_up'], key) >= 0
        win_execute(wid, 'norm k')
    elseif index(keymaps['preview_down'], key) >= 0
        win_execute(wid, 'norm j')
    else
        return 0
    endif
    return 1
enddef

def CreatePopup(bufnr: number, args: dict<any>): number
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
       cursorline: 0,
       callback:  function('GeneralPopupCallback'),
       border:  [1],
       borderchars:  ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
       borderhighlight:  ['Normal'],
       highlight:  'Normal', }

    if has_key(args, 'enable_border') && !args.enable_border
        remove(opts, 'border')
    endif

    # we will put user callback in close_funcs, and call it in GeneralPopupCallback
    for key in ['filter', 'border', 'borderhighlight', 'highlight', 'borderchars',
          'scrollbar', 'padding', 'wrap', 'zindex', 'title']
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
    if has_key(args, 'cursorline') && args.cursorline
        # we don't use popup option 'cursorline' because it is buggy (some
        # colorscheme will make cursorline highlight disappear)
        opts.has_cursorline = 1
       setwinvar(wid, '&cursorline', 1)
       setwinvar(wid, '&cursorlineopt', 'line')
    endif
    popup_wins[wid] = {
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
            popup_wins[wid][key] = args[key]
        endif
    endfor
    if has_key(args, 'callback')
        add(popup_wins[wid].close_funcs, args.callback)
    endif
    return wid
enddef

def NewPopup(args: dict<any>): list<number>
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

    var bufnr = CreateBuf()
    var wid = CreatePopup(bufnr, opts)

    popup_wins[wid].bufnr = bufnr

    return [wid, bufnr]
enddef

export def MenuSetText(wid: number, text_list: list<string>)
    if type(text_list) != v:t_list
        echoerr 'text must be a list'
    endif
    if !has_key(popup_wins, wid)
        return
    endif
    var text = text_list
    var old_cursor_pos = line('$', wid) - line('.', wid)

    popup_wins[wid].validrow = len(text_list)
    var textrows = popup_getpos(wid).height - 2
    if popup_wins[wid].reverse_menu
        text = reverse(text_list)
        if len(text) < textrows
            text = repeat([''], textrows - len(text)) + text
        endif
    endif

    if popup_getoptions(wid).scrollbar
        var curwidth = popup_getpos(wid).width
        var noscrollbar_width = popup_wins[wid].noscrollbar_width
        if len(text) > textrows && curwidth != noscrollbar_width - 1
            var width = noscrollbar_width - 1
           popup_move(wid, {'minwidth': width, 'maxwidth': width})
        elseif len(text) <= textrows && curwidth != noscrollbar_width
            var width = noscrollbar_width
            popup_move(wid, {'minwidth': width, 'maxwidth': width})
        endif
    endif

    popup_settext(wid, text)
    if popup_wins[wid].reverse_menu
        var new_line_length = line('$', wid)
        var cursor_pos = new_line_length - old_cursor_pos
        win_execute(wid, 'normal! ' .. new_line_length .. 'zb')
        win_execute(wid, 'normal! ' .. cursor_pos .. 'G')
        # echom [old_cursor_pos, cursor_pos, line('$')]
    endif

    MenuUpdateCursorItem(wid)
enddef

# params:
#   - wid: popup window id
#   - hi_list: list of position to highlight eg. [[1,2,3], [1,5]]
export def MenuSetHl(name: string, wid: number, hl_list_raw: list<any>)
    if !has_key(popup_wins, wid)
        return
    endif
    clearmatches(wid)
    # pass empty list to matchaddpos will cause error
    if len(hl_list_raw) == 0
        return
    endif
    var hl_list = hl_list_raw

    # in case of reverse menu, we need to reverse the hl_list
    var textrows = popup_getpos(wid).height - 2
    var height = max([hl_list_raw[-1][0], textrows])
    if popup_wins[wid].reverse_menu
        hl_list = reduce(hl_list_raw, (acc, v) => add(acc, [height - v[0] + 1] + v[1 :]), [])
    endif

    # in MS-Windows, matchaddpos() has maximum limit of 8 position groups
    var idx = 0
    while idx < len(hl_list)
        matchaddpos(menu_matched_hl, hl_list[idx : idx + 7 ], 99, -1,  {'window': wid})
        idx += 8
    endwhile
enddef

def PopupPrompt(args: dict<any>): number
    var opts = {
     width:  0.4,
     height:  1,
     filter:  function('PromptFilter')
     }
    opts            =  extend(opts, args)
    var [wid, bufnr]    =  NewPopup(opts)
    var prompt_char     =  has_key(args, 'prompt') ? args.prompt : '> '
    var prompt_char_len =  strcharlen(prompt_char)
    var prompt_opt      =  {
     line:  [],
     promptchar:  prompt_char,
     displayed_line:  prompt_char .. " ",
     }

    var cursor_args = {
     min_pos:  0,
     max_pos:  0,
     promptchar_len:  prompt_char_len,
     cur_pos:  0,
     highlight:  'Search',
     mid:  -1,
     }

    popup_wins[wid].cursor_args = cursor_args
    popup_wins[wid].prompt = prompt_opt
    if has_key(args, 'input_cb') && type(args.input_cb) == v:t_func
        popup_wins[wid].prompt.input_cb = args.input_cb
    endif
    popup_settext(wid, prompt_opt.displayed_line)

    # set cursor
    var mid = matchaddpos(cursor_args.highlight,
    [[1, prompt_char_len + 1 + cursor_args.cur_pos]], 10, -1,  {'window': wid})
    popup_wins[wid].cursor_args.mid = mid
    return wid
enddef

def PopupMenu(args: dict<any>): number
    var opts = {
     width: 0.4,
     height: 17,
     yoffset: 0.3,
     cursorline: 1,
     filter: function('MenuFilter'),
     wrap: 0,
     }

    opts = extend(opts, args)
    var [wid, bufnr] = NewPopup(opts)

    return wid
enddef

def PopupPreview(args: dict<any>): number
    var opts = {
     width: 0.4,
     height: 19,
     yoffset: 0.3,
     cursorline: 1,
     filter: function('PreviewFilter'),
     wrap: 0,
     }

    opts = extend(opts, args)
    var [wid, bufnr] = NewPopup(opts)

    setwinvar(wid, '&number', 1)
    setwinvar(wid, '&wrap', 1)
    return wid
enddef

# sometimes a layout contains multiple windows, we need to close them all
# To do that we need to connect them
def ConnectWin(wins: dict<any>)
    var allwins = values(wins)
    for [k, wid] in items(wins)
        var newlist = reduce(allwins, (acc, v) => v != wid ? add(acc, v) : acc, [])
        popup_wins[wid].related_win = newlist
        popup_wins[wid].partids = wins
    endfor
enddef

# params:
#   - opts: options: dictonary contains following keys:
#       - select_cb: callback function when a value is selected(press enter)
#       - move_cb: callback function when cursor moves to a new value
#       - input_cb: callback function when user input something
# return:
#   [menu_wid, prompt_wid, preview_wid]
export def PopupSelection(user_opts: dict<any>): dict<any>
    triger_userautocmd = 1
    key_callbacks = has_key(user_opts, 'key_callbacks') ? user_opts.key_callbacks : {}
    var has_preview = has_key(user_opts, 'preview') && user_opts.preview

    var width: any   = 0.8
    var height: any  = 0.8
    width   = has_key(user_opts, 'width') ? user_opts.width : width
    height  = has_key(user_opts, 'height') ? user_opts.height : height
    var xoffset = width < 1 ? (1 - width) / 2 : (&columns  - width) / 2
    var yoffset = height < 1 ? (1 - height) / 2 : (&lines - height) / 2

    var preview_ratio = 0.5
    preview_ratio = has_key(user_opts, 'preview_ratio') ? user_opts.preview_ratio : preview_ratio

    # user's input always override the default
    xoffset =  has_key(user_opts, 'xoffset') ? user_opts.xoffset : xoffset
    yoffset =  has_key(user_opts, 'yoffset') ? user_opts.yoffset : yoffset

    # convert all pos to number
    yoffset       =  yoffset < 1 ? float2nr(yoffset * &lines) : float2nr(yoffset)
    xoffset       =  xoffset < 1 ? float2nr(xoffset * &columns) : float2nr(xoffset)
    height        =  height < 1 ? float2nr(height * &lines) : float2nr(height)
    width         =  width < 1 ? float2nr(width * &columns) : float2nr(width)

    var preview_width = 0
    var menu_width    = 0
    if has_preview
        preview_width = float2nr(width * preview_ratio)
        menu_width    = width - preview_width
    else
        menu_width    = width
    endif

    var dropdown = has_key(user_opts, 'dropdown') && user_opts.dropdown

    var prompt_height =  3
    var menu_height   =  height - prompt_height

    var prompt_yoffset: number
    var menu_yoffset: number
    var reverse_menu: number

    if dropdown
        prompt_yoffset = yoffset
        menu_yoffset = yoffset + prompt_height
        reverse_menu = 0
    else
        menu_yoffset = yoffset
        prompt_yoffset = yoffset + menu_height + 2
        reverse_menu = 1
    endif
    reverse_menu = has_key(user_opts, 'reverse_menu') ? user_opts.reverse_menu : reverse_menu

    var menu_opts = {
        callback:  has_key(user_opts, 'select_cb') ? user_opts.select_cb : v:null,
        close_cb:  has_key(user_opts, 'close_cb') ? user_opts.close_cb : v:null,
        scrollbar:  has_key(user_opts, 'scrollbar') ? user_opts.scrollbar : 1,
        reverse_menu: reverse_menu,
        yoffset:  menu_yoffset,
        xoffset:  xoffset,
        width:  menu_width,
        height:  menu_height,
        zindex:  1200,
    }

    for key in ['title', 'move_cb']
        if has_key(user_opts, key)
            menu_opts[key] = user_opts[key]
        endif
    endfor

    var menu_wid = PopupMenu(menu_opts)

    # var prompt_yoffset = popup_wins[menu_wid].line + popup_wins[menu_wid].height
    var prompt_opts = {
        yoffset:  prompt_yoffset,
        xoffset:  xoffset,
        width:  menu_width,
        input_cb:  has_key(user_opts, 'input_cb') ? user_opts.input_cb : v:null,
        prompt: has_key(user_opts, 'prompt') ? user_opts.prompt : '> ',
        zindex:  1010,
    }
    var prompt_wid = PopupPrompt(prompt_opts)
    popup_wins[prompt_wid].partids = {'menu': menu_wid}

    var connect_wins = {
        menu:  menu_wid,
        prompt:  prompt_wid,
    }

    var ret = {
        menu: menu_wid,
        prompt: prompt_wid,
        preview: -1,
        info: -1,
    }
    if has_preview
        var preview_xoffset =  popup_wins[menu_wid].col + popup_wins[menu_wid].width
        var menu_row        =  popup_wins[menu_wid].line
        var prompt_row      =  popup_wins[prompt_wid].line
        prompt_height   =  popup_wins[prompt_wid].height
        # var preview_height  =  prompt_row - menu_row + prompt_height
        var preview_height  =   menu_height + prompt_height + 2
        var preview_opts    =  {
            width:  preview_width,
            height:  preview_height,
            yoffset:  yoffset,
            xoffset:  preview_xoffset + 2,
            zindex:  1100,
        }
        var preview_wid      =  PopupPreview(preview_opts)
        connect_wins.preview =  preview_wid
        ret.preview = preview_wid
    endif

    if has_key(user_opts, 'infowin') && user_opts.infowin
        var [info_wid, info_bufnr] = NewPopup({
            width:  menu_width - 1,
            height:  1,
            yoffset:  yoffset + 1,
            xoffset:  xoffset + 1,
            padding:  [0, 0, 0, 1],
            zindex:  2000,
            enable_border:  0,
        })
        connect_wins.info = info_wid
        ret.info = info_wid
    endif

    t_ve = &t_ve
    guicursor = &guicursor
    setlocal t_ve=
    # hide cursor in macvim or other guivim
    set guicursor=a:xxx
    ConnectWin(connect_wins)
    return ret
enddef
