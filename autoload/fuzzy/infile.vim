
import autoload 'utils/selector.vim'

function! s:select(wid, result)
    let linenr = str2nr(split(a:result[0], ':')[0])
    exe 'norm! ' . linenr . 'G'
    norm! zz
endfunction

function! fuzzy#infile#start()
    let raw_lines = getline(1, '$')
    let max_line_len = len(string(len(raw_lines)))
    let lines = reduce(raw_lines,
      \ {a, v -> add(a, printf('%'.max_line_len.'d:%s', len(a) + 1,  v))}, [])

    let winds = s:selector.Start(lines,
    \ {
    \ 'select_cb'    :  function('s:select'),
    \ 'preview'      :  0,
    \ 'reverse_menu' :  0,
    \ 'width'        :  0.7
    \ })
    let s:menu_wid = winds[0]
    let file = expand('%:p')
    let ext = fnamemodify(file, ':e')
    let ft = s:selector.GetFt(ext)
    let menu_bufnr = winbufnr(s:menu_wid)
endfunc

function! fuzzy#infile#init()
    command! -nargs=0 FuzzyInfiles call fuzzy#infile#start()
    nnoremap <silent> <leader>fb :FuzzyInfiles<CR>
endfunction

