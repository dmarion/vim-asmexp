" asmexp.vim - Assembler Explorer
" Author:     Damjan Marion <dmarion@me.com>
" Website:    https://github.com/dmarion/vim-asmexp
" License:    MIT

if exists('g:loaded_asmexp')
  finish
endif

let g:loaded_asmexp = 1

let g:asmexp_show_directives = get(g:, 'asmexp_show_directives', 0)
let g:asmexp_cc = get(g:, 'asmexp_cc', 'cc')
let g:asmexp_cflags = get(g:, 'asmexp_cflags', '-march=native -O3')

command! AsmExplorerEnableView :call asmexp#enable_view()
command! AsmExplorerDisableView :call asmexp#disable_view()
command! AsmExplorerToggleView :call asmexp#toggle_view()
command! AsmExplorerToggleDirectives :call asmexp#toggle_directives()
