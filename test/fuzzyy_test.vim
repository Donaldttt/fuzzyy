vim9script

import autoload 'ignore_tree/ignore_tree.vim'
import autoload 'ignore_tree/find_builder.vim'
import autoload 'ignore_tree/fd_builder.vim'
import autoload 'ignore_tree/gci_builder.vim'

def Setup1(): dict<string>
    var FileTMP = tempname()
    var DirTMP = substitute(FileTMP, "/[^/]*$", "/", "")
    var DirIgnored = ".git/"
    var File = "good.txt"
    var FileIgnored = "bad.beam"

    mkdir(DirTMP, 'p')
    var CWDOld = getcwd()
    chdir(DirTMP)

    mkdir(DirIgnored, 'p')
    writefile(["foo"], DirIgnored .. "/" .. File, "")
    writefile(["foo"], DirIgnored .. "/" .. FileIgnored, "")
    writefile(["foo"], DirTMP .. "/" .. File, "")
    writefile(["foo"], DirTMP .. "/" .. FileIgnored, "")

    var Conf = {
        dir_tmp: DirTMP,
        dir_ignored: DirIgnored,
        file: File,
        file_ignored: FileIgnored,
        cwd_old: CWDOld
    }

    return Conf
enddef

def Cleanup1(conf: dict<string>): void
    chdir(conf.cwd_old)
    delete(conf.dir_tmp, "rf")
enddef

def Case1(conf: dict<string>): void
    if has("win32") || has("win64")
        echo "skipped, wrong OS:windows"
        return
    endif

    # INIT
    var CMD = find_builder.Build(ignore_tree.MakeIgnoreTree())

    # ACT
    var FileList = systemlist(CMD)

    # ASSERT
    if index(FileList, "./" .. conf.file) == -1
        throw "file " .. conf.file .. " not found"
    endif

    if index(FileList, "./" .. conf.file_ignored) != -1
        throw "file " .. conf.file_ignored .. " found"
    endif

    if index(FileList, conf.dir_ignored .. conf.file) != -1
        throw "file " .. conf.file_ignored .. " found"
    endif

    if index(FileList, conf.dir_ignored .. conf.file_ignored) != -1
        throw "file " .. conf.file_ignored .. " found"
    endif

    # TERMINATE

enddef

def Case2(conf: dict<string>): void
    if has("win32") || has("win64")
        echo "skipped, wrong OS:windows"
        return
    endif

    # INIT
    var CMD = fd_builder.Build(ignore_tree.MakeIgnoreTree())

    # ACT
    var FileList = systemlist(CMD)

    # ASSERT
    if index(FileList, conf.file) == -1
        throw "file " .. conf.file .. " not found"
    endif

    if index(FileList, conf.file_ignored) != -1
        throw "file " .. conf.file_ignored .. " found"
    endif

    if index(FileList, conf.dir_ignored .. conf.file) != -1
        throw "file " .. conf.file_ignored .. " found"
    endif

    if index(FileList, conf.dir_ignored .. conf.file_ignored) != -1
        throw "file " .. conf.file_ignored .. " found"
    endif

    # TERMINATE

enddef

def Case3(conf: dict<string>): void
    if !has("win32") && !has("win64")
        echo "skipped, not windows"
        return
    endif

    # INIT
    var CMD = gci_builder.Build(ignore_tree.MakeIgnoreTree())

    # ACT
    var FileList = system(CMD)->split('\n')

    # ASSERT
    if index(FileList, conf.file) == -1
        throw "file " .. conf.file .. " not found"
    endif

    if index(FileList, conf.file_ignored) != -1
        throw "file " .. conf.file_ignored .. " found"
    endif

    if index(FileList, conf.dir_ignored .. conf.file) != -1
        throw "file " .. conf.file_ignored .. " found"
    endif

    if index(FileList, conf.dir_ignored .. conf.file_ignored) != -1
        throw "file " .. conf.file_ignored .. " found"
    endif

    # TERMINATE

enddef

def RunCaseFun(SetupFun: func(): any, CleanupFun: func(any): void, CaseName: string, CaseFun: func(any): void): void
    var Conf = SetupFun()
    try
        CaseFun(Conf)
    catch
        echom "Catched exception: " .. v:exception .. " in case: " .. CaseName
    endtry
    CleanupFun(Conf)
enddef

def Suite1(): void
    RunCaseFun(Setup1, Cleanup1, "Case1", Case1)
    RunCaseFun(Setup1, Cleanup1, "Case2", Case2)
    RunCaseFun(Setup1, Cleanup1, "Case3", Case3)
enddef

export def Start(): void
    Suite1()
enddef

Start()

