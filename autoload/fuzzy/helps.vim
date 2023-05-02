vim9script

import autoload 'utils/selector.vim'

var update_tid: number
var tag_table: dict<any>
var tag_files: list<string>
var menu_wid: number
var file_lines: list<string>
var cur_pattern: string

def Tags(): dict<any>
    var sorted = sort(split(globpath(&runtimepath, 'doc/tags', 1), '\n'))
    tag_files = uniq(sorted)
    var result: dict<any> = {}
    for file in tag_files
        file_lines += readfile(file)
    endfor
    reduce(file_lines[: 1000], (acc, val) => {
        var li = split(val)
        acc[li[0]] = [li[1], li[2]]
        return acc
    }, result)
    file_lines = file_lines[1001 :]

    return result
enddef

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    exe ':help ' .. result

    # checkout taglist()
    # if not using :help method
    # if !filereadable(path)
    #     popup_settext(preview_wid, '')
    #     return
    # endif
    # var pattern = tag_table[result][1]
    # var preview_bufnr = winbufnr(preview_wid)
    # var fileraw = readfile(path)
    # var linenr = match(fileraw, pattern)
    # popup_settext(preview_wid, fileraw)
    # setbufvar(preview_bufnr, '&syntax', 'help')
    # win_execute(preview_wid, 'norm! ' .. linenr .. 'G')
    # win_execute(preview_wid, 'norm! zz')
enddef

def Input(wid: number, args: dict<any>, ...li: list<any>)
    var val = args.str
    cur_pattern = val
    var [ret, hi_list] = selector.FuzzySearch(keys(tag_table), val, 1000)
    g:MenuSetText(menu_wid, ret)
    g:MenuSetHl('select', menu_wid, hi_list)
enddef

def HelpsUpdateMenu(...args: list<any>)
    if len(tag_files) == 0
        timer_stop(update_tid)
        return
    endif
    reduce(file_lines[: 1000], (acc, val) => {
        var li = split(val)
        acc[li[0]] = [li[1], li[2]]
        return acc
    }, tag_table)
    file_lines = file_lines[1001 :]

    popup_setoptions(menu_wid, {'title': string(len(tag_table))})
    try
        # var [file_sorted_list, hl_list] = selector.FuzzySearch(keys(tag_table), cur_pattern)
        # g:MenuSetText(menu_wid, file_sorted_list)
        # g:MenuSetHl('select', menu_wid, hl_list)
    catch
        # echom ['error in files_update_menu']
    endtry
enddef

def CloseCb(wid: number, args: dict<any>)
    if has_key(args, 'selected_item')
        var tag = args.selected_item
        exe ':help ' .. tag
    else
        var tabnr = tabpagenr()
        var wins = gettabinfo(tabnr)[0].windows
        for win in wins
            var bufnr = winbufnr(win)
            if getbufvar(bufnr, '&buftype') == 'help'
                win_execute(win, ':q')
                break
            endif
        endfor
    endif
    timer_stop(update_tid)
enddef

export def HelpsStart()
    tag_files = []
    file_lines = []
    cur_pattern = ''
    tag_table = Tags()
        # close_cb:   function('CloseCb'),
    var winds = selector.Start(keys(tag_table), {
        preview_cb: function('Preview'),
        close_cb:   function('CloseCb'),
        input_cb:   function('Input'),
        preview:  0,
        yoffset: 2,
        height: 0.4,
        scrollbar: 0,
        width: 0.5,
    })
    menu_wid = winds[0]
    popup_setoptions(menu_wid, {'title': string(len(tag_table))})
    update_tid = timer_start(100, function('HelpsUpdateMenu'), {'repeat': -1})
enddef
