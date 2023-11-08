vim9script

var async_list: list<string>
var async_limit: number
var async_pattern: string
var async_results: list<any>
var async_tid: number
var AsyncCb: func

# if pattern is empty, return [li, []]
# params:
#  - li: list of string to be searched
#  - pattern: string to be searched
#  - args: dict of options
#      - limit: max number of results
# return:
# - a list [str_list, hl_list]
#   - str_list: list of string to be displayed
#   - hl_list: list of highlight positions
#       - [[line1, col1], [line1, col2], [line2, col1], ...]
export def FuzzySearch(li: list<string>, pattern: string, ...args: list<any>): list<any>
    if pattern == ''
        return [copy(li), []]
    endif
    var opts = {}
    if len(args) > 0 && args[0] > 0
        opts['limit'] = args[0]
    endif
    var results: list<any> = matchfuzzypos(li, pattern, opts)
    var strs = results[0]
    var poss = results[1]
    var scores = results[2]

    var str_list = []
    var hl_list = []
    for idx in range(0, len(strs) - 1)
        add(str_list, strs[idx])
        var poss_result = MergeContinusNumber(poss[idx])
        hl_list += reduce(poss_result, (acc, val) => add(acc, [idx + 1] + val), [])
    endfor
    return [str_list, hl_list]
enddef

# merge continus numbers and convert than from string index to vim column
# eg. [1,2,3,4,5,7,9] -> [[1,5], [7], [9]]
def MergeContinusNumber(li: list<number>): list<any>
    var last_pos = li[0]
    var start_pos = li[0]
    var pos_len = 1
    var poss_result = []
    for idx in range(1, len(li) - 1)
        var pos = li[idx]
        if pos == last_pos + 1
            pos_len += 1
        else
            # add 1 because vim column starts from 1 and string index starts from 0
            if pos_len > 1
                add(poss_result, [start_pos + 1, pos_len])
            else
                add(poss_result, [start_pos + 1])
            endif
            start_pos = pos
            last_pos = pos
            pos_len = 1
        endif
        last_pos = pos
    endfor
    if pos_len > 1
        add(poss_result, [start_pos + 1, pos_len])
    else
        add(poss_result, [start_pos + 1])
    endif
    return poss_result
enddef

def Worker(tid: number)
    const ASYNC_STEP = 1000
    var li = async_list[: ASYNC_STEP]
    var results: list<any> = matchfuzzypos(li, async_pattern)
    var processed_results = []

    var strs = results[0]
    var poss = results[1]
    var scores = results[2]
    for idx in range(len(strs))
        # merge continus number
        var poss_result = MergeContinusNumber(poss[idx])
        add(processed_results, [strs[idx], poss_result, scores[idx]])
    endfor
    async_results += processed_results
    sort(async_results, (a, b) => {
        if a[2] < b[2]
            return 1
        elseif a[2] > b[2]
            return -1
        else
            return a[0] > b[0] ? 1 : -1
        endif
    })

    if len(async_results) >= async_limit
        async_results = async_results[: async_limit]
    endif
    AsyncCb(async_results)

    async_list = async_list[ASYNC_STEP + 1 :]
    if len(async_results) >= async_limit || len(async_list) == 0
        timer_stop(tid)
        return
    endif
enddef

# Using timer to mimic async search. This is a workaround for the lack of async
# support in vim. It uses timer to do the search in the background, and calls
# the callback function when part of the results are ready.
# This function only allows one outstanding call at a time. If a new call is
# made before the previous one finishes, the previous one will be canceled.
# params:
#  - li: list of string to be searched
#  - pattern: string to be searched
#  - limit: max number of results
#  - Cb: callback function
# return:
#  timer id
export def FuzzySearchAsync(li: list<string>, pattern: string, limit: number, Cb: func): number
    # only one outstanding call at a time
    timer_stop(async_tid)
    if pattern == ''
        return -1
    endif
    async_list = li
    async_limit = limit
    async_pattern = pattern
    async_results = []
    AsyncCb = Cb
    async_tid = timer_start(50, function('Worker'), {'repeat': -1})
    Worker(async_tid)
    return async_tid
enddef

export def Cleanup()
    timer_stop(async_tid)
enddef
