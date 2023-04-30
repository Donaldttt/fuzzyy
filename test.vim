
let s:popup_wins = {}
let s:popup_wins[1] = {}
let s:popup_wins[2] = {}

def s:MenuFilter()
enddef
def s:PromptFilter()
enddef
def s:NewPopup(opts: dict<any>): any
    return [1, 1]
enddef

def s:PopupSelection(user_opts: dict<any>): list<number>
    s:triger_userautocmd = 1
    s:popup_wins = {}
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

    var prompt_height =  3
    var menu_height   =  height - prompt_height

    var menu_opts = {
     callback:  has_key(user_opts, 'select_cb') ? user_opts.select_cb : v:null,
     close_cb:  has_key(user_opts, 'close_cb') ? user_opts.close_cb : v:null,
     scrollbar:  has_key(user_opts, 'scrollbar') ? user_opts.scrollbar : 1,
     reverse_menu:  has_key(user_opts, 'reverse_menu') ? user_opts.reverse_menu : 1,
     yoffset:  yoffset,
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

    var menu_wid = s:PopupMenu(menu_opts)

    var prompt_yoffset = s:popup_wins[menu_wid].line + s:popup_wins[menu_wid].height
    var prompt_opts = {
     yoffset:  prompt_yoffset + 2,
     xoffset:  xoffset,
     width:  menu_width,
     input_cb:  has_key(user_opts, 'input_cb') ? user_opts.input_cb : v:null,
     }
    var prompt_wid = s:PopupPrompt(prompt_opts)
    s:popup_wins[prompt_wid].partids = {'menu': menu_wid}

    var connect_wins = {
     menu:  menu_wid,
     prompt:  prompt_wid,
     }

    if has_key(user_opts, 'infowin') && user_opts.infowin
        var [info_wid, info_bufnr] = s:NewPopup({
         width:  menu_width - 2,
         height:  1,
         yoffset:  yoffset + 1,
         xoffset:  xoffset + 1,
         padding:  [0, 0, 0, 1],
         zindex:  2000,
         enable_border:  0,
         }) connect_wins.info = info_wid
    endif

    var ret = [menu_wid, prompt_wid]
    if has_preview
        var preview_xoffset =  s:popup_wins[menu_wid].col + s:popup_wins[menu_wid].width
        var menu_row        =  s:popup_wins[menu_wid].line
        var prompt_row      =  s:popup_wins[prompt_wid].line
        prompt_height   =  s:popup_wins[prompt_wid].height
        var preview_height  =  prompt_row - menu_row + prompt_height
        var preview_opts    =  {
         width:  preview_width,
         height:  preview_height,
         yoffset:  yoffset,
         xoffset:  preview_xoffset + 2,
         }
        var preview_wid          =  s:PopupPreview(preview_opts)
        connect_wins.preview =  preview_wid
        add(ret, preview_wid)
    endif
    s:t_ve = &t_ve
    setlocal t_ve=
    s:ConnectWin(connect_wins)
    return ret
enddef

call g:fuzzy#ag#start()

