vim9script

var file_ignore = ['*.beam', '*.so', '*.exe', '*.dll', '*.dump', '*.core',
    '*.swn', '*.swp']
var dir_ignore = ['.git', '.hg', '.svn', '.rebar', '.eunit']

var respect_gitignore = 0
var only_git_files = 0
if exists('g:files_respect_gitignore')
    respect_gitignore = g:files_respect_gitignore
endif
if exists('g:files_only_git_files')
    only_git_files = g:files_only_git_files
endif

if exists('g:fuzzyy_files_ignore_file')
        && type(g:fuzzyy_files_ignore_file) == v:t_list
    file_ignore = g:fuzzyy_files_ignore_file
endif

if exists('g:fuzzyy_files_ignore_dir')
        && type(g:fuzzyy_files_ignore_dir) == v:t_list
    dir_ignore = g:fuzzyy_files_ignore_dir
endif

var Append = (buf, char) => buf .. char

var has_git = executable('git') ? v:true : v:false

def InsideGitRepo(): bool
    if has_git
        return stridx(system('git rev-parse --is-inside-work-tree'), 'true') == 0
    else
        echom 'fuzzyy: git is not installed'
        return v:false
    endif
enddef

export def Build_fd(): string
    if respect_gitignore
        return 'fd --type f -H -E .git'
    endif
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
    var build_dir_filter = reduce(dir_ignore, (acc, dir) => acc .. "$_ -notlike '*\\"
        .. dir ..  "\\*' -and $_ -notlike '" .. dir .. "\\*'"
        .. " -and ", "")
            -> trim(" -and ", 2)
            -> Append(" ")

    var build_file_filter = reduce(file_ignore, (acc, file) => acc
        .. "$_ -notlike '" .. file .. "' -and ", "")
            -> trim(" -and ", 2)
            -> Append(" ")

    var build_filter = "| Where-Object { "
    if len(dir_ignore) > 0
        build_filter ..= build_dir_filter
    endif
    if len(dir_ignore) > 0 && len(file_ignore) > 0
        build_filter ..= " -and "
    endif
    if len(file_ignore) > 0
        build_filter ..= build_file_filter
    endif
    build_filter ..= "} "

    var cmd = "Get-ChildItem . -Name -Force -File -Recurse "
    if len(dir_ignore) > 0 || len(file_ignore) > 0
        cmd ..= build_filter
    endif

    return "powershell -command " .. '"' .. cmd .. '"'
enddef

export def Build_git_ls_files(): string
enddef

def RespectGitignore(): string
    var cmdstr = ''
    if executable('fd')
        cmdstr = Build_fd()
    elseif has_git && InsideGitRepo()
        cmdstr = 'git ls-files --cached --other --exclude-standard --full-name .'
    endif
    return cmdstr
enddef

def OnlyGitFile(): string
    var cmdstr = ''
    if has_git && InsideGitRepo()
        cmdstr = 'git ls-files'
    endif
    return cmdstr
enddef

export def Build(): string
    var cmdstr = ''
    if only_git_files
        cmdstr = OnlyGitFile()
        if cmdstr != ''
            return cmdstr
        endif
    endif
    if respect_gitignore
        cmdstr = RespectGitignore()
        if cmdstr != ''
            return cmdstr
        endif
    endif
    if executable('fd') #fd is cross-platform
            cmdstr = Build_fd()
    else
        if has('win32')
            cmdstr = Build_gci()
        else
            cmdstr = Build_find()
        endif
    endif
    return cmdstr
enddef
