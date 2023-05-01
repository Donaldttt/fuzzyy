vim9scrip

var fd = '2'

def Input(wid: number, args: dict<any>, ...li: list<any>)
    var val = args.str
    var hi_list = []
    var menu_wid = args.win_opts.partids.menu
    var ret: list<string>
    if val != ''
        [ret, hi_list] = utils#selector#fuzzysearch(s:fzf_list, val)
    endif

    if len(ret) > 7000
        timer_stop(s:input_timer2)
        g:MenuSetText(menu_wid, ret)
        s:input_timer2 = timer_start(100, function('g:MenuSetHl', ['select', menu_wid, hi_list]))
    else
        g:MenuSetText(menu_wid, ret)
        g:MenuSetHl('select', menu_wid, hi_list)
    endif
enddef
