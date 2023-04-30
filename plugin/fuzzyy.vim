if exists("g:loaded_fuzzyy")
  finish
endif
let g:loaded_fuzzyy = 1

if !has('nvim')
    call fuzzy#ag#init()
    call fuzzy#files#init()
    call fuzzy#infile#init()
    call fuzzy#colors#init()
endif
