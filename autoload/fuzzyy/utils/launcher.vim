vim9script

import autoload './popup.vim'

export def Start(selector: string, opts: dict<any>)
    if !exists('g:__fuzzyy_launcher_cache')
        g:__fuzzyy_launcher_cache = []
    endif
    insert(g:__fuzzyy_launcher_cache, { selector: selector, opts: opts, prompt: '' })
    function('fuzzyy#' .. selector .. '#Start')(opts)
enddef

export def Resume()
    if !exists('g:__fuzzyy_launcher_cache')
        return
    endif
    for e in g:__fuzzyy_launcher_cache
        if !empty(e.prompt)
            function('fuzzyy#' .. e.selector .. '#Start')(e.opts)
            popup.SetPrompt(e.prompt)
            # truncate cache, only save latest with prompt
            g:__fuzzyy_launcher_cache = [e]
            return
        endif
    endfor
    # clear cache, no items in cache have saved prompt, so cannot be resumed
    g:__fuzzyy_launcher_cache = []
enddef

export def Save(wins: dict<any>)
    if !exists('g:__fuzzyy_launcher_cache') || type(wins) != v:t_dict
        return
    endif
    try
        # removes prefix and cursor (prefix is one unicode char plus one space)
        var prompt_str = getbufline(winbufnr(wins.prompt), 1)[0]->slice(2)->slice(0, -1)
        g:__fuzzyy_launcher_cache[0].prompt = prompt_str
    catch
        # FIXME: make pretty error output, with fuzzyy prefix and highlight
        echo v:exception .. v:throwpoint
    endtry
enddef
