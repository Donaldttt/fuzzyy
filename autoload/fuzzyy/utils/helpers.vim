vim9script

var root_patterns = exists('g:fuzzyy_root_patterns')
    && type(g:fuzzyy_root_patterns) == v:t_list ?
    g:fuzzyy_root_patterns : ['.git', '.hg', '.svn']
var reuse_windows = exists('g:fuzzyy_reuse_windows')
    && type(g:fuzzyy_reuse_windows) == v:t_list ?
    g:fuzzyy_reuse_windows : ['netrw']

var iswin = has('win32') || has('win64')
var fs = iswin ? '\' : '/'

export def IsWin(): bool
    return iswin
enddef

export def PathSep(): string
    return fs
enddef

export def Split(str: string): list<string>
    var sep: string
    if iswin && stridx(str, "\r\n") >= 0
        sep = '\r\n'
    else
        sep = '\n'
    endif
    return split(str, sep)
enddef

export def GetRootDir(): string
  var dir = getcwd()
  var cur: string
  while 1
    for pattern in root_patterns
      if !empty(globpath(dir, pattern, 1))
        return dir
      endif
    endfor
    [cur, dir] = [dir, fnamemodify(dir, ':h')]
    if cur == dir | break | endif
  endwhile
  return getcwd()
enddef

export def MoveToUsableWindow(buf: any = null)
    var c = 0
    var wincount = winnr('$')
    var buftype = !empty(buf) && !getbufvar(buf, '&buftype') ?
        getbufvar(buf, '&buftype') : null
    var filetype = !empty(buf) && !getbufvar(buf, '&filetype') ?
        getbufvar(buf, '&filetype') : null
    while ( !empty(&buftype) && index(reuse_windows + [buftype], &buftype) == -1 &&
            index(reuse_windows + [filetype], &filetype) == -1 && c < wincount )
        wincmd w
        c = c + 1
    endwhile
enddef
