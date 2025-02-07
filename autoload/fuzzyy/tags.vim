vim9script

import autoload './utils/selector.vim'

var tag_list: list<string>
var tag_files = []
var tag_dirs = []
var cwd: string
var fs = has('win32') || has('win64') ? '\' : '/'

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

# Find the first readable path relative to tagfiles locations. Can potentially
# expand to the wrong path if there is more than one match, but should be rare.
def ExpandPath(path: string): string
    for tag_dir in tag_dirs
        if filereadable(tag_dir .. fs .. path)
            return tag_dir .. fs .. path
        endif
    endfor
    return path
enddef

def JumpToAddress(tagaddress: string)
    for excmd in tagaddress->split(";")
        if trim(excmd) =~ '^\d\+$'
            execute("silent! cursor(" .. excmd .. ", 1)")
        else
            var pattern = excmd->substitute('^\/', '', '')->substitute('\M\/;\?"\?$', '', '')
            execute("silent! search('\\M" .. EscQuotes(pattern) .. "', 'cw')")
        endif
    endfor
    execute('norm! zz')
enddef

def Select(wid: number, result: list<any>)
    var [tagname, tagfile, tagaddress] = ParseResult(result[0])
    var path = ExpandPath(tagfile)
    if filereadable(path)
        selector.MoveToUsableWindow()
        exe 'edit ' .. path
        JumpToAddress(tagaddress)
    endif
enddef

def CloseTab(wid: number, result: dict<any>)
    if !empty(get(result, 'cursor_item', ''))
        var [tagname, tagfile, tagaddress] = ParseResult(result.cursor_item)
        var path = ExpandPath(tagfile)
        if filereadable(path)
            exe 'tabnew ' .. path
            JumpToAddress(tagaddress)
        endif
    endif
enddef

def CloseVSplit(wid: number, result: dict<any>)
    if !empty(get(result, 'cursor_item', ''))
        var [tagname, tagfile, tagaddress] = ParseResult(result.cursor_item)
        var path = ExpandPath(tagfile)
        if filereadable(path)
            exe 'vsplit ' .. path
            JumpToAddress(tagaddress)
        endif
    endif
enddef

def CloseSplit(wid: number, result: dict<any>)
    if !empty(get(result, 'cursor_item', ''))
        var [tagname, tagfile, tagaddress] = ParseResult(result.cursor_item)
        var path = ExpandPath(tagfile)
        if filereadable(path)
            exe 'split ' .. path
            JumpToAddress(tagaddress)
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
    var path = ExpandPath(tagfile)
    if !filereadable(path)
        if result == ''
            popup_settext(preview_wid, '')
        else
            popup_settext(preview_wid, path .. ' not found')
        endif
        return
    endif
    var preview_bufnr = winbufnr(preview_wid)
    var content = readfile(path)
    noautocmd popup_settext(preview_wid, content)
    setwinvar(preview_wid, '&filetype', '')
    win_execute(preview_wid, 'silent! doautocmd filetypedetect BufNewFile ' .. path)
    noautocmd win_execute(preview_wid, 'silent! setlocal nospell nolist')
    if empty(getwinvar(preview_wid, '&filetype')) || getwinvar(preview_wid, '&filetype') == 'conf'
        var modelineft = selector.FTDetectModelines(content)
        if !empty(modelineft)
            win_execute(preview_wid, 'set filetype=' .. modelineft)
        endif
    endif
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
    cwd = len(get(opts, 'cwd', '')) > 0 ? opts.cwd : getcwd()
    var original_cwd = getcwd()
    exe 'silent lcd ' .. cwd
    try
        tag_files = tagfiles()
        if empty(tag_files)
            # copied from fzf.vim, thanks @junegunn
            inputsave()
            echohl WarningMsg
            var gen = input('No tags file in ' .. fnamemodify(cwd, ':~') .. ', generate? (y/N) ')
            echohl None
            inputrestore()
            redraw
            if gen =~? '^y'
                if ! executable('ctags')
                    throw "Missing executable ctags, please install Universal Ctags"
                else
                    var ver = system('ctags --version')
                    if ver !~? "Universal"
                        throw "Incompatible ctags version, please install Universal Ctags"
                    endif
                endif
                var out = system('ctags -R')
                tag_files = tagfiles()
                if empty(tag_files)
                    throw 'Failed to create tags file: ' .. out
                else
                    echo 'Created tags file'
                endif
            endif
        endif

        tag_list = []
        # Possible TODO: use readtags program here, would remove additional info
        # and could also be used to format the lines nicely (fzf.vim does this)
        for path in tag_files
            var lines = readfile(path)
            tag_list += lines[match(lines, '^[^!]') : -1]
        endfor

        tag_dirs = tag_files->map((_, val) => {
            return fnamemodify(stridx(val, fs) == 0 ? val : cwd .. fs .. val, ':h')
        })
    catch
        echoerr v:exception
    finally
        exe 'silent lcd ' .. original_cwd
    endtry

    if empty(tag_list)
        echo "No tags found"
        return
    endif

    var wids = selector.Start(tag_list, extend(opts, {
        select_cb: function('Select'),
        preview_cb: function('Preview'),
        input_cb: function('Input'),
        key_callbacks: split_edit_callbacks,
    }))
enddef
