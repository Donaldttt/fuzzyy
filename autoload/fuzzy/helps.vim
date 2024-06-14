vim9script

import autoload '../utils/selector.vim'

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
    if len(result) == 0
        return
    endif
    exe ':belowright help ' .. result
enddef

def AsyncCb(result: list<any>)
    var strs = []
    var hl_list = []
    var idx = 1
    for item in result
        add(strs, item[0])
        hl_list += reduce(item[1], (acc, val) => {
            add(acc, [idx] + val)
            return acc
        }, [])
        idx += 1
    endfor
    selector.UpdateMenu(strs, hl_list)
enddef

def Input(wid: number, args: dict<any>, ...li: list<any>)
    var pattern = args.str
    cur_pattern = pattern
    selector.FuzzySearchAsync(keys(tag_table), pattern, 200, function('AsyncCb'))
enddef

var last_parttern: string
def HelpsUpdateMenu(...args: list<any>)
    const STEP = 1000 
    if len(tag_files) == 0
        timer_stop(update_tid)
        return
    endif
    reduce(file_lines[: STEP], (acc, val) => {
        var li = split(val)
        acc[li[0]] = [li[1], li[2]]
        return acc
    }, tag_table)
    file_lines = file_lines[STEP + 1 :]

    if cur_pattern != last_parttern
        var [ret, hl_list] = selector.FuzzySearch(keys(tag_table), cur_pattern, 1000)
        selector.UpdateMenu(ret, hl_list)
        last_parttern = cur_pattern
    endif
    # popup_setoptions(menu_wid, {'title': string(len(tag_table))})
enddef

def CloseCb(wid: number, args: dict<any>)
    if has_key(args, 'selected_item')
        var tag = args.selected_item
        exe ':belowright help ' .. tag
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

export def Start()
    tag_files = []
    file_lines = []
    cur_pattern = ''
    tag_table = Tags()
    last_parttern = ''
    var wids = selector.Start(keys(tag_table), {
        preview_cb: function('Preview'),
        close_cb:   function('CloseCb'),
        input_cb:   function('Input'),
        preview:  0,
        yoffset: 2,
        height: 0.4,
        scrollbar: 0,
        width: 0.5,
        dropdown: 1,
    })
    menu_wid = wids.menu
    # popup_setoptions(menu_wid, {'title': string(len(tag_table))})
    update_tid = timer_start(20, function('HelpsUpdateMenu'), {'repeat': -1})
enddef

