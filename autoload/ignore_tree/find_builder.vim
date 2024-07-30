vim9script

import autoload 'ignore_tree/ignore_tree.vim'

def ParseFileList(file_list: list<string>): string
    return reduce(file_list, (acc, file) => acc .. "-not -name " .. file .. " ", "")
enddef

def ParseDirList(dir_list: list<string>): string
    var ParseDir = (dir): string => "*/" .. dir .. "/*"
    var Append = (buf, char) => buf .. char

    var dir_list_parsed = reduce(dir_list, (acc, dir) => acc .. "-path " .. ParseDir(dir) .. " -prune -o ", "")
                            ->trim("-o ", 2)
                            ->Append(" ")

    return "\\( " .. dir_list_parsed .. "\\) "
enddef

export def Build(ignore_tree_obj: dict<list<string>>): string
    var file_ignore = ignore_tree.GetFileList(ignore_tree_obj)
    var file_list_parsed = ParseFileList(file_ignore)

    var dir_ignore = ignore_tree.GetDirList(ignore_tree_obj)
    var dir_list_parsed = ParseDirList(dir_ignore)

    var result = "find " .. dir_list_parsed .. "-o " .. file_list_parsed .. "-type f -print "

    return result
enddef

