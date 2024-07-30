vim9script

export def MakeIgnoreTree(): dict<list<string>>
    var fuzzyy_custom_ignore = {
        'dir': ['.git', '.hg', '.svn', '.rebar', '.eunit'],
        'file': ['*.beam', '*.so', '*.exe', '*.dll', '*.dump', '*.core', '*.swn', '*.swp']
    }
    return fuzzyy_custom_ignore
enddef

export def GetDirList(ignore_tree: dict<list<string>>): list<string>
    return ignore_tree.dir
enddef

export def GetFileList(ignore_tree: dict<list<string>>): list<string>
    return ignore_tree.file
enddef

