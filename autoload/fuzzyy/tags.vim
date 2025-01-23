vim9script

import autoload './utils/selector.vim'

var tag_list: list<string>

def ParseResult(result: string): list<any>
    # Tags file format, see https://docs.ctags.io/en/latest/man/tags.5.html
    # {tagname}<Tab>{tagfile}<Tab>{tagaddress}[;"<Tab>{tagfield}..]
    var parts = result->split("\t")
    var [tagname, tagfile] = parts[0 : 1]
    var rest = parts[2 : -1]->join("\t")
    var tagaddress = rest->split(';"\t')[0]
    return [tagname, tagfile, tagaddress]
enddef

def EscQuotes(str: string): string
    return substitute(str, "'", "''", 'g')
enddef

def Select(wid: number, result: list<any>)
    var [tagname, tagfile, tagaddress] = ParseResult(result[0])
    if filereadable(tagfile)
        selector.MoveToUsableWindow()
        exe 'edit ' .. tagfile
        feedkeys(':' .. tagaddress .. "\<CR>:norm! zz\<CR>", 'n')
    endif
enddef

def CloseTab(wid: number, result: dict<any>)
    if has_key(result, 'cursor_item')
        var [tagname, tagfile, tagaddress] = ParseResult(result.cursor_item)
        if filereadable(tagfile)
            exe 'tabnew ' .. tagfile
            feedkeys(':' .. tagaddress .. "\<CR>:norm! zz\<CR>", 'n')
        endif
    endif
enddef

def CloseVSplit(wid: number, result: dict<any>)
    if has_key(result, 'cursor_item')
        var [tagname, tagfile, tagaddress] = ParseResult(result.cursor_item)
        if filereadable(tagfile)
            exe 'vsplit ' .. tagfile
            feedkeys(':' .. tagaddress .. "\<CR>:norm! zz\<CR>", 'n')
        endif
    endif
enddef

def CloseSplit(wid: number, result: dict<any>)
    if has_key(result, 'cursor_item')
        var [tagname, tagfile, tagaddress] = ParseResult(result.cursor_item)
        if filereadable(tagfile)
            exe 'split ' .. tagfile
            feedkeys(':' .. tagaddress .. "\<CR>:norm! zz\<CR>", 'n')
        endif
    endif
enddef

def SetVSplitClose()
    selector.ReplaceCloseCb(function('CloseVSplit'))
    selector.Close()
enddef

def SetSplitClose()
    selector.ReplaceCloseCb(function('CloseSplit'))
    selector.Close()
enddef

def SetTabClose()
    selector.ReplaceCloseCb(function('CloseTab'))
    selector.Close()
enddef

var split_edit_callbacks = {
    "\<c-v>": function('SetVSplitClose'),
    "\<c-s>": function('SetSplitClose'),
    "\<c-t>": function('SetTabClose'),
}

def Preview(wid: number, opts: dict<any>)
    var result = opts.cursor_item
    if !has_key(opts.win_opts.partids, 'preview')
        return
    endif
    var preview_wid = opts.win_opts.partids['preview']
    if result == ''
        popup_settext(preview_wid, '')
        return
    endif
    win_execute(preview_wid, 'syntax clear')
    var [tagname, tagfile, tagaddress] = ParseResult(result)
    if !filereadable(tagfile)
        if result == ''
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, tagfile .. ' not found')
        endif
        return
    endif
    var preview_bufnr = winbufnr(preview_wid)
    noautocmd call popup_settext(preview_wid, readfile(tagfile))
    win_execute(preview_wid, 'silent! doautocmd filetypedetect BufNewFile ' .. tagfile)
    noautocmd win_execute(preview_wid, 'silent! setlocal nospell nolist')
    for excmd in tagaddress->split(";")
        if trim(excmd) =~ '^\d\+$'
            win_execute(preview_wid, "silent! cursor(" .. excmd .. ", 1)")
        else
            var pattern = excmd->substitute('^\/', '', '')->substitute('\M\/;\?"\?$', '', '')
            win_execute(preview_wid, "silent! search('\\M" .. EscQuotes(pattern) .. "', 'cw')")
            clearmatches(preview_wid)
            win_execute(preview_wid, "silent! matchadd('fuzzyyPreviewMatch', '\\M" .. EscQuotes(pattern) .. "')")
        endif
    endfor
    win_execute(preview_wid, 'norm! zz')
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
    selector.FuzzySearchAsync(tag_list, pattern, 200, function('AsyncCb'))
enddef

export def Start(opts: dict<any> = {})
    if empty(tagfiles())
        # copied from fzf.vim, thanks @junegunn
        inputsave()
        echohl WarningMsg
        var gen = input('No tags file found. Generate? (y/N) ')
        echohl None
        inputrestore()
        redraw
        if gen =~? '^y'
            var is_win = has('win32') || has('win64')
            system('ctags -R' .. (is_win ? ' --output-format=e-ctags' : ''))
            if empty(tagfiles())
                echoerr 'Failed to create tags file'
            else
                echo 'Created tags file'
            endif
        endif
    endif

    tag_list = []
    # Possible TODO: use readtags program here, would remove additional info
    # and could also be used to format the lines nicely (fzf.vim does this)
    for path in tagfiles()
        var lines = readfile(path)
        tag_list += lines[match(lines, '^[^!]') : -1]
    endfor

    var wids = selector.Start(tag_list, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        input_cb: function('Input'),
        key_callbacks: split_edit_callbacks,
    }))
enddef
