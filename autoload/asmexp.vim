" asmexp.vim - Compiler Assembler output Viewer
" Author:     Damjan Marion <dmarion@me.com>
" Website:    https://github.com/dmarion/vim-asmexp
" License:    MIT

let s:src_bufnr = ''
let s:asm_bufnr = ''
let s:exclude_sections = ['.debug_str', '.debug_info', '.debug_line',
                         \'.debug_abbrev', '".note.GNU-stack"',
                         \'.note.GNU-stack', '.note.gnu.property',
                         \'.debug_aranges']
let s:data_types = ['.byte', '.ascii', '.octa', '.long', '.float']
let s:asm_line_by_src_line = []
let s:enabled = 0

function! s:compiler_close_cb(...)
    let src_line = 0
    let section = ""
    let label_lines = []
    let globals = []
    for line in s:compiler_output
        let l = split(line.text)

        if len(l) < 1
            continue
        endif

        if l[0] == ".section"
            let section = split(l[1], ",")[0]
        endif

        if l[0] == ".globl"
            call add(globals, l[1])
        endif

        if l[0] == ".loc"
            let src_line = 0
            if l[1] == 1
                let src_line = l[2]
            endif
        endif

        let line.src_line = src_line
        let line.section = section
    endfor

    let line_nr = len(s:compiler_output)
    while line_nr > 0
        let line_nr = line_nr - 1
        let line = s:compiler_output[line_nr]
        if index(s:exclude_sections, line.section) >= 0
            call remove(s:compiler_output, line_nr)
            continue
        endif

        let l = split(line.text)

        if l[0][-1:] == ':'
            " label
            let line.src_line = 0
            continue
        endif

        if index(s:data_types, l[0]) >= 0
            " data type
            let line.src_line = 0
            continue
        endif

        if l[0][0] == '.'
            " other directives
            if g:asmexp_show_directives != 1
                call remove(s:compiler_output, line_nr)
            else
                let line.src_line = 0
            endif
            continue
        endif
    endwhile

    " remove unreferenced labels
    let line_nr = len(s:compiler_output)
    while line_nr > 0
        let line_nr = line_nr - 1
        let line = s:compiler_output[line_nr]
        let l = split(line.text)

        if len(l) < 1 || l[0][-1:] != ':'
            continue
        endif

        let label = l[0][0:-2]
        if index(globals, label) >= 0
            continue
        endif

        let cnt = 0
        for line in s:compiler_output
            if stridx(line.text, label) >= 0
                let cnt = cnt + 1
            endif
        endfor
        if cnt < 2
            call remove(s:compiler_output, line_nr)
        endif
    endwhile

    let line_nr = 0
    call win_gotoid(bufwinid(s:asm_bufnr))
    setlocal noreadonly modifiable
    call win_gotoid(bufwinid(s:src_bufnr))
    while line_nr < len(s:compiler_output)
        let line = s:compiler_output[line_nr]
        let line_nr = line_nr + 1
        call setbufline(s:asm_bufnr, line_nr, line.text)

        while len(s:asm_line_by_src_line) <= line.src_line
            call add(s:asm_line_by_src_line, [])
        endwhile
        call add(s:asm_line_by_src_line[line.src_line], line_nr)
    endwhile
    call deletebufline(s:asm_bufnr, line_nr+1, "$")
    call win_gotoid(bufwinid(s:asm_bufnr))
    setlocal readonly nomodifiable
    call win_gotoid(bufwinid(s:src_bufnr))
endfunction

function! s:compiler_out_cb(ch, msg)
    call add(s:compiler_output, {'text': a:msg})
endfunction

func s:compile()
    if exists('s:job')
        call job_stop(s:job)
    endif
    let s:compiler_output = []
    let s:asm_line_by_src_line = []
    let s:skip_section = 0
    let s:loc_line = 0
    let opt = {}
    let opt.in_io = 'buffer'
    let opt.in_buf = s:src_bufnr
    let opt.out_io = 'pipe'
    let opt.out_buf = s:asm_bufnr
    let opt.close_cb = function('s:compiler_close_cb')
    let opt.out_cb = function('s:compiler_out_cb')
    let cmdline = g:asmexp_cc . " " . g:asmexp_cflags
    let cmdline = cmdline . " -masm=intel -g1 -S -xc -c -o - -"
    let s:job = job_start(cmdline, opt)
endfunc

func s:cursor_moved()
    let line = line(".")
    let prop = {}
    let prop.length = 999
    let prop.bufnr = s:asm_bufnr
    let prop.type = 'AsmExplorerHighlight'
    call prop_remove(prop)
    if line >= len(s:asm_line_by_src_line)
        return
    endif
    for l in s:asm_line_by_src_line[line]
        call prop_add(l, 1, prop)
    endfor

    if len(s:asm_line_by_src_line[line]) < 1
        return
    endif
    call win_gotoid(bufwinid(s:asm_bufnr))
    call setpos(".", [s:asm_bufnr, s:asm_line_by_src_line[line][0], 1])
    call win_gotoid(bufwinid(s:src_bufnr))
endfunc

func asmexp#enable_view()
    let s:src_bufnr = bufnr('%')
    let oldwin = bufwinid(s:src_bufnr)
    vertical rightb split [FooView]
    setlocal nowrap syn=asm ft=asm readonly nomodifiable
    setlocal buftype=nofile noswapfile bufhidden=delete
    let s:asm_bufnr = bufnr('%')
    call assert_false(oldwin == bufwinid(s:asm_bufnr))
    call win_gotoid(oldwin)
    call prop_type_add('AsmExplorerHighlight', { 'highlight': 'CursorLineNr' })
    call s:compile()
    au TextChanged,TextChangedI <buffer> call s:compile()
    au BufDelete,QuitPre <buffer> call asmexp#disable_view()
    au CursorMoved,CursorMovedI <buffer> call s:cursor_moved()
    let s:enabled = 1
endfunc

func asmexp#disable_view()
    exe s:asm_bufnr . "bdelete"
    let s:asm_bufnr = ''
    au! TextChanged,TextChangedI <buffer> call s:compile()
    au! BufDelete,QuitPre <buffer> call asmexp#disable_view()
    au! CursorMoved,CursorMovedI <buffer> call s:cursor_moved()
    call prop_type_delete('AsmExplorerHighlight')
    let s:enabled = 0
endfunc

func asmexp#toggle_view()
    if s:enabled
        call asmexp#disable_view()
    else
        call asmexp#enable_view()
    endif
endfunc

func asmexp#toggle_directives()
    let g:asmexp_show_directives = !g:asmexp_show_directives
    if s:enabled
        call s:compile()
    endif
endfunc
