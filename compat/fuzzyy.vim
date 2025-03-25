vim9script

# Compatibility hacks, loaded from VimEnter autocmd in plugin/fuzzyy.vim
if exists("g:loaded_fuzzyy_compat")
  finish
endif
g:loaded_fuzzyy_compat = 1

if exists('g:loaded_nerd_tree') && findfile('after/syntax/nerdtree.vim', &rtp) =~ 'nerdtree-syntax-highlight'
    import '../autoload/fuzzyy/utils/colors.vim'
    runtime! after/syntax/nerdtree.vim
    map(colors.devicons_color_table, (key, val) => {
        var ext = fnamemodify(key, ':e')
        if !empty(ext) && hlexists('nerdtreeFileExtensionIcon_' .. tolower(ext))
            return hlget('nerdtreeFileExtensionIcon_' .. tolower(ext))[0]['guifg']
        elseif hlexists('nerdtreeExactMatchIcon_' .. tolower(key))
            return hlget('nerdtreeExactMatchIcon_' .. tolower(key))[0]['guifg']
        else
            return val
        endif
    })->filter((key, val) => key != '__default__')
endif
