import autoload 'utils/selector.vim'

function! s:get_colors()
   return uniq(sort(map(
   \  globpath(&runtimepath, "colors/*.vim", 0, 1),  
   \  'fnamemodify(v:val, ":t:r")'
   \)))
endfunction

function! s:preview(wid, result)
    let color = a:result.cursor_item
    let &bg = s:old_bg
    execute 'colorscheme ' . color
endfunction

function! s:select(wid, result)
    if !has_key(a:result, 'selected_item')
        let &bg = s:old_bg
        execute 'colorscheme ' . s:old_color
    else
        let color = a:result.selected_item[0]
        if color =~# 'light$'
            let bg = 'light'
        else
            let bg = &bg
        endif
        call theme#setColor(bg, color)
    endif
endfunction

function! fuzzy#colors#start()
    let s:old_color = execute('colo')[1:]
    let s:old_bg = &bg
    let colors = s:get_colors()
    let winds = s:selector.Start(colors,
    \ {
    \ 'preview': 0,
    \ 'preview_cb': function('s:preview'),
    \ 'close_cb' : function('s:select'),
    \ 'reverse_menu' : 1,
    \ 'width' : 0.25,
    \ 'xoffset' : 0.7,
    \ 'scrollbar' : 0,
    \ 'preview_ratio' : 0.7
    \ })
    let s:menu_wid = winds[0]
    " let s:preview_wid = winds[2]
endfunc

function! fuzzy#colors#init()
    command! -nargs=0 FuzzyColors call fuzzy#colors#start()
    nnoremap <silent> <leader>fc :FuzzyColors<CR>
endfunction
