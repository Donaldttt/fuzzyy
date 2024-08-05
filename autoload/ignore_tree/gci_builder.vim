vim9script

import autoload 'ignore_tree/ignore_tree.vim'

# GCI doc isn't clear. Get-ChildItem -Recurse -Exclude only matches exclusion on the leaf, not the parent path.
#
# Link: https://stackoverflow.com/questions/15294836/how-can-i-exclude-multiple-folders-using-get-childitem-exclude#:~:text=The%20documentation%20isn%27t%20clear%20on%20this%2C%20but%20Get%2DChildItem%20%2DRecurse%20%2DExclude%20only%20matches%20exclusion%20on%20the%20leaf%20(Split%2DPath%20%24_.FullName%20%2DLeaf)%2C%20not%20the%20parent%20path%20(Split%2DPath%20%24_.FullName%20%2DParent).
#
# That's why module builds GCI cmd and piping it into Where-filter
def BuildDirFilter(dir_list: list<string>): string
    var TransformDir = (dir) => "'" .. dir .. "\\*" .. "'"
    var Append = (buf, char) => buf .. char

    return reduce(dir_list, (acc, dir) => acc .. "$_ -notlike " .. TransformDir(dir) .. " -and ", "")
            -> trim(" -and ", 2)
            -> Append(" ")
enddef

def BuildFileFilter(file_list: list<string>): string
    var TransformFile = (file) => "'" .. file .. "'"
    var Append = (buf, char) => buf .. char

    return reduce(file_list, (acc, file) => acc .. "$_ -notlike " .. TransformFile(file) .. " -and ", "")
            -> trim(" -and ", 2)
            -> Append(" ")
enddef

def BuildFilter(dir_ignore: list<string>, file_ignore: list<string>): string
    return "Where-Object { " .. BuildDirFilter(dir_ignore) .. "-and " .. BuildFileFilter(file_ignore) .. "} "
enddef

export def Build(ignore_tree_obj: dict<list<string>>): string
    var dir_ignore = ignore_tree.GetDirList(ignore_tree_obj)
    var file_ignore = ignore_tree.GetFileList(ignore_tree_obj)
    var cmd = "Get-ChildItem . -Name -File -Recurse | " .. BuildFilter(dir_ignore, file_ignore)
    return "powershell -command " .. '"' .. cmd .. '"'
enddef

