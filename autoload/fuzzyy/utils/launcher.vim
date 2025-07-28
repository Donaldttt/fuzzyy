vim9script

import autoload './popup.vim'

export def Start(selector: string, opts: dict<any>)
    if !exists('g:__fuzzyy_launcher_cache')
        g:__fuzzyy_launcher_cache = []
    endif
    insert(g:__fuzzyy_launcher_cache, { selector: selector, opts: opts, prompt: '' })
    function('fuzzyy#builtin#' .. selector .. '#Start')(opts)

    if exists('g:__fuzzyy_warnings_found') && g:__fuzzyy_warnings_found
        echohl WarningMsg
        echo 'Fuzzyy started with warnings, use :FuzzyShowWarnings command to see details'
        echohl None
    endif
enddef

export def Resume()
    if !exists('g:__fuzzyy_launcher_cache') || empty(g:__fuzzyy_launcher_cache)
        Warn( 'fuzzyy: no previous launch to resume')
        return
    endif
    for e in g:__fuzzyy_launcher_cache
        if !empty(e.prompt)
            function('fuzzyy#builtin#' .. e.selector .. '#Start')(e.opts)
            if popup.GetPrompt() != e.prompt
                popup.SetPrompt(slice(e.prompt, 0, -1))
                feedkeys(e.prompt[strcharlen(e.prompt) - 1])
            endif
            # trim cache, only save latest with prompt
            g:__fuzzyy_launcher_cache = [e]
            return
        endif
    endfor
    # clear cache, no items in cache have saved prompt, so cannot be resumed
    g:__fuzzyy_launcher_cache = []
    Warn('fuzzyy: no previous search to resume')
enddef

export def Save(wins: dict<any>)
    if !exists('g:__fuzzyy_launcher_cache') || empty(g:__fuzzyy_launcher_cache)
        return
    endif
    try
        var prompt_str = popup.GetPrompt()
        if !empty(prompt_str)
            g:__fuzzyy_launcher_cache[0].prompt = prompt_str
        elseif empty(g:__fuzzyy_launcher_cache[0].prompt)
            # remove from cache when no prompt to save, cannot be resumed
            remove(g:__fuzzyy_launcher_cache, 0)
        endif
    catch
        Warn('fuzzyy: ' .. v:exception .. ' at ' .. v:throwpoint)
    endtry
enddef

def Warn(msg: string)
    if has('patch-9.0.0321')
        echow msg
    else
        timer_start(100, (_) => {
            echohl WarningMsg | echo msg | echohl None
        }, { repeat: 0 })
    endif
enddef
