vim9scrip

var fd = '2'

def FilesJobStart(path: string)
    if type(s:jid) == v:t_job
        job_stop(s:jid)
    endif
    s:cur_result = []
    if path == ''
        return
    endif
    var cmdstr: string
    if has('win32')
        cmdstr = 'powershell -command "gci . -r -n -File"'
    else
        cmdstr = 'find . -type f -not -path "*/.git/*"'
    endif
    let s:jid = job_start(cmdstr, {
     out_cb: function('s:job_handler'),
     out_mode: 'raw',
     exit_cb: function('s:exit_cb'),
     err_cb: function('s:exit_cb'),
     cwd : path
     })
enddef
