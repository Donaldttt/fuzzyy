vim9script

def IsBinary(path: string): bool
    # NUL byte check for binary files, used to avoid showing preview
    # Assumes a file encoding that does not allow NUL bytes, so will
    # generate false positives for UTF-16 and UTF-32, but the preview
    # window doesn't work for these encodings anyway, even with a BOM
    if !has('patch-9.0.0810')
        # Workaround for earlier versions of Vim with limited readblob()
        # Option to read only part of file finalised in patch 9.0.0810
        return match(readfile(path, '', 10), '\%x00') != -1
    endif
    return IsBinaryBlob(path)
enddef

# Note: use of legacy function a workaround for compilation failing when
# readblob() would be called with invalid args on earlier Vim versions
function IsBinaryBlob(path)
    for byte in readblob(a:path, 0, 128)
        if byte == 0 | return v:true | endif
    endfor
    return v:false
endfunction

# Get filetype from modelines, used when not detected via filetypedetect autocmd
def FTDetectModelines(content: list<string>): string
    if ( !&modeline || &modelines == 0 ) && !exists('g:loaded_securemodelines')
        return ''
    endif
    if empty(content)
        return ''
    endif
    try
        var modelines = len(content) >= &modelines ? &modelines : len(content)
        var pattern = '\M\C\s\?\(Vim\|vim\|vi\|ex\):\.\*\(ft\|filetype\)=\w\+'
        var matched = content[0 : modelines - 1]->matchstr(pattern)
        if empty(matched)
            matched = content[len(content) - modelines : -1]->matchstr(pattern)
        endif
        if !empty(matched)
            return matched->trim()->split('\M\(\s\+\|:\)')->filter((_, val) => {
                    return val =~# '^\M\C\(ft\|filetype\)=\w\+$'
                })[-1]->split('=')[-1]
        endif
    catch
        echohl ErrorMsg
        echom 'fuzzyy:' v:exception .. ' ' .. v:throwpoint
        echohl None
    endtry
    return ''
enddef

export def PreviewText(wid: number, text: string)
    win_execute(wid, 'syntax clear')
    popup_settext(wid, text)
enddef

export def PreviewFile(wid: number, path: string, opts: dict<any> = {})
    win_execute(wid, 'syntax clear')
    if !filereadable(path)
        popup_settext(wid, 'File not found: ' .. path)
        return
    endif
    if IsBinary(path)
        popup_settext(wid, 'Cannot preview binary file')
        return
    endif
    var content: list<any>
    if has_key(opts, 'max') && type(opts.max) == v:t_number
        content = readfile(path, '', opts.max)
    else
        content = readfile(path)
    endif
    popup_settext(wid, content)
    setwinvar(wid, '&filetype', '')
    win_execute(wid, 'silent! doautocmd filetypedetect BufNewFile ' .. path)
    win_execute(wid, 'silent! setlocal nospell nolist')
    if empty(getwinvar(wid, '&filetype')) || getwinvar(wid, '&filetype') == 'conf'
        var modelineft = FTDetectModelines(content)
        if !empty(modelineft)
            win_execute(wid, 'set filetype=' .. modelineft)
        endif
    endif
enddef
