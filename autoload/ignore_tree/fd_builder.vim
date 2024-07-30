vim9script

import autoload 'ignore_tree/ignore_tree.vim'

def ParseDirList(dir_list: list<string>): string
    return reduce(dir_list,  (acc, dir) => acc .. "-E " .. dir .. " ", "")
enddef

def ParseFileList(file_list: list<string>): string
    return reduce(file_list, (acc, file) => acc .. "-E " .. file .. " ", "")
enddef

export def Build(ignore_tree_obj: dict<list<string>>): string
    var dir_ignore = ignore_tree.GetDirList(ignore_tree_obj)
    var dir_list_parsed = ParseDirList(dir_ignore)

    var file_ignore = ignore_tree.GetFileList(ignore_tree_obj)
    var file_list_parsed = ParseFileList(file_ignore)

    var result = "fd --type f -H -I " .. dir_list_parsed .. file_list_parsed

    return result
enddef

