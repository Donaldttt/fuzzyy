vim9script

var file_ignore = ['*.beam', '*.so', '*.exe', '*.dll', '*.dump', '*.core',
    '*.swn', '*.swp']
var dir_ignore = ['.git', '.hg', '.svn', '.rebar', '.eunit']

if exists('g:fuzzyy_files_ignore_file')
        && type(g:fuzzyy_files_ignore_file) == v:t_list
    file_ignore = g:fuzzyy_files_ignore_file
endif

if exists('g:fuzzyy_files_ignore_dir')
        && type(g:fuzzyy_files_ignore_dir) == v:t_list
    dir_ignore = g:fuzzyy_files_ignore_dir
endif

var Append = (buf, char) => buf .. char

export def Build_fd(): string
    var dir_list_parsed = reduce(dir_ignore,
        (acc, dir) => acc .. "-E " .. dir .. " ", "")

    var file_list_parsed = reduce(file_ignore,
        (acc, file) => acc .. "-E " .. file .. " ", "")

    var result = "fd --type f -H -I " .. dir_list_parsed .. file_list_parsed

    return result
enddef

export def Build_find(): string
    var file_list_parsed = reduce(file_ignore,
        (acc, file) => acc .. "-not -name " .. file .. " ", "")

    var ParseDir = (dir): string => "*/" .. dir .. "/*"
    var dir_list_parsed = ""
    if len(dir_ignore) > 0
        dir_list_parsed = reduce(dir_ignore, (acc, dir) => acc .. "-not -path " .. ParseDir(dir) .. " ", " ")
    endif
    var result = "find . " .. dir_list_parsed
    if len(file_ignore) > 0
        result ..= reduce(file_ignore, (acc, file) => acc .. "-not -name " .. file .. " ", " ")
    endif
    result ..= "-type f -print "

    return result
enddef

# GCI doc isn't clear. Get-ChildItem -Recurse -Exclude only matches exclusion
# on the leaf, not the parent path.
#
# Link:
# https://stackoverflow.com/questions/15294836/how-can-i-exclude-multiple-folders-using-get-childitem-exclude#:~:text=The%20documentation%20isn%27t%20clear%20on%20this%2C%20but%20Get%2DChildItem%20%2DRecurse%20%2DExclude%20only%20matches%20exclusion%20on%20the%20leaf%20(Split%2DPath%20%24_.FullName%20%2DLeaf)%2C%20not%20the%20parent%20path%20(Split%2DPath%20%24_.FullName%20%2DParent).
#
# That's why module builds GCI cmd and piping it into Where-filter
export def Build_gci(): string
    var TransformDir = (dir) => "'" .. dir .. "\\*" .. "'"
    var build_dir_filter = reduce(dir_ignore, (acc, dir) => acc
        .. "$_ -notlike " .. TransformDir(dir) .. " -and ", "")
            -> trim(" -and ", 2)
            -> Append(" ")

    var TransformFile = (file) => "'" .. file .. "'"
    var build_file_filter = reduce(file_ignore, (acc, file) => acc
        .. "$_ -notlike " .. TransformFile(file) .. " -and ", "")
            -> trim(" -and ", 2)
            -> Append(" ")

    var build_filter = "Where-Object { " .. build_dir_filter .. "-and "
        .. build_file_filter .. "} "
    var cmd = "Get-ChildItem . -Name -File -Recurse | " .. build_filter

    return "powershell -command " .. '"' .. cmd .. '"'
enddef
