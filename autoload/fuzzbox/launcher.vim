vim9script

import autoload './utils/launcher.vim'

export def Start(selector: string, opts: dict<any> = {})
    launcher.Start(selector, opts)
enddef
