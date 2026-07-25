" if exists('g:compile#loaded')
"   finish
" endif

let g:compile#loaded = 1

if !exists('g:compile#splitDir')
  let g:compile#splitDir = 'top'
endif

if !exists('g:compile#autoQuickfix')
  let g:compile#autoQuickfix = 1
endif

" Equivalent to emacs' compilation-error-regexp-alist: each entry holds a
" pattern plus the submatch indices for the file, line and column a compiler
" reported. A 'col' of 0 means the pattern doesn't capture one.
if !exists('g:compile#errorFormats')
  let g:compile#errorFormats = [
        \ {'pat': '\v^\s*(\f+):(\d+):(\d+)',        'file': 1, 'lnum': 2, 'col': 3},
        \ {'pat': '\v^\s*(\f+)\((\d+),\s*(\d+)\)',  'file': 1, 'lnum': 2, 'col': 3},
        \ {'pat': '\v^\s*File "(\f+)", line (\d+)', 'file': 1, 'lnum': 2, 'col': 0},
        \ {'pat': '\v^\s*(\f+):(\d+)',              'file': 1, 'lnum': 2, 'col': 0},
        \ ]
endif

let g:compile#commands = {'compile': {}, 'test': {'vim':'ls'}}

" Buffer holding the output of the last spawned command
let s:termBuf = 0

function! g:compile#splitModifier()
  if g:compile#splitDir ==# 'left'
    return 'vertical topleft'
  elseif g:compile#splitDir ==# 'right'
    return 'vertical botright'
  elseif g:compile#splitDir ==# 'bottom'
    return 'botright'
  else
    return 'topleft'
  endif
endfunction

function! g:compile#spawnTerminal(cmd)
  let l:mod = compile#splitModifier()
  let l:vertical = g:compile#splitDir ==# 'left' || g:compile#splitDir ==# 'right'

  if has('nvim')
    exec l:mod . ' split'
    if l:vertical
      vertical resize 80
    else
      resize 20
    endif
    exec 'terminal ' . a:cmd
    let s:termBuf = bufnr('%')
    call compile#setupOutputBuffer()
    normal i
  else
    " echoerr 'This feature is unstable in Vim'
    exec l:mod . ' terminal ' . a:cmd
    let s:termBuf = bufnr('%')
    call compile#setupOutputBuffer()
    echo 'Press Enter to jump to an error, q to exit terminal'
  endif
endfunction

function! g:compile#setupOutputBuffer()
  nnoremap <buffer> <silent> <CR> :call compile#jumpToError()<CR>
  nnoremap <buffer> <silent> q :bdelete!<CR>
endfunction

" Match a single line of compiler output against g:compile#errorFormats,
" returning a quickfix entry, or an empty dict when nothing usable was found.
function! g:compile#parseLine(text)
  for l:fmt in g:compile#errorFormats
    let l:m = matchlist(a:text, l:fmt.pat)
    if empty(l:m)
      continue
    endif

    " Guards against timestamps and the like being read as 'file:line:col'
    let l:file = l:m[l:fmt.file]
    if !filereadable(l:file)
      continue
    endif

    return {
          \ 'filename': l:file,
          \ 'lnum': str2nr(l:m[l:fmt.lnum]),
          \ 'col': l:fmt.col > 0 ? str2nr(l:m[l:fmt.col]) : 1,
          \ }
  endfor

  return {}
endfunction

" Scan the output buffer and fill the quickfix list, returning how many
" positions were found.
function! g:compile#populateQuickfix()
  if s:termBuf <= 0 || !bufexists(s:termBuf)
    return 0
  endif

  let l:items = []
  for l:text in getbufline(s:termBuf, 1, '$')
    let l:entry = compile#parseLine(l:text)
    if empty(l:entry)
      continue
    endif
    let l:entry.text = trim(l:text)
    call add(l:items, l:entry)
  endfor

  call setqflist([], ' ', {'title': 'compile', 'items': l:items})
  return len(l:items)
endfunction

function! g:compile#openQuickfix()
  let l:found = compile#populateQuickfix()
  if l:found == 0
    cclose
    echo 'No error positions found in the compiler output'
    return
  endif
  copen
endfunction

" First window in the tab showing a regular file, so errors don't take over
" the output buffer or the quickfix window.
function! s:sourceWindow()
  for l:win in range(1, winnr('$'))
    if l:win != winnr() && getbufvar(winbufnr(l:win), '&buftype') ==# ''
      return l:win
    endif
  endfor
  return 0
endfunction

function! g:compile#jumpToError()
  let l:entry = compile#parseLine(getline('.'))
  if empty(l:entry)
    echo 'No error position on this line'
    return
  endif

  let l:win = s:sourceWindow()
  if l:win > 0
    exec l:win . 'wincmd w'
  else
    new
  endif

  exec 'edit ' . fnameescape(l:entry.filename)
  call cursor(l:entry.lnum, l:entry.col)
  normal! zz
endfunction

function! g:compile#requestCommand(kind, ft = '')
  if a:ft ==# ''
    let l:ft = &filetype
  else
    let l:ft = a:ft
  endif

  if l:ft ==# ''
    echoerr 'Cannot bind command to empty filetype'
	  return v:false
  endif

  if a:kind ==# 'compile'
    let l:prompt = 'Compile with command: '
  elseif a:kind ==# 'test'
    let l:prompt = 'Test with command: '
  else
    echoerr 'Invalid command type: ' . a:kind
    return v:false
  endif

  let l:userCmd = input(l:prompt, '', 'history')

  let g:compile#commands[a:kind][l:ft] = l:userCmd

  return l:userCmd
endfunction

function! g:compile#runCommand(kind, reset = v:false)
  let l:ft = &filetype

  let l:dict = g:compile#commands[a:kind]

  if has_key(l:dict, ft) && !a:reset
    call compile#spawnTerminal(l:dict[l:ft])
  else
    let l:userCmd = compile#requestCommand(a:kind, l:ft)
    if l:userCmd == v:false
      return
    endif
    call compile#spawnTerminal(l:dict[l:ft])
  endif
endfunction

command! Compile call compile#runCommand('compile')
command! CompileTest call compile#runCommand('test')
command! -nargs=? CompileSetCommands call compile#requestCommand('compile', <args>) | call compile#requestCommand('test', <args>)
command! CompileErrors call compile#openQuickfix()

" Vim has no autocmd for a :terminal job finishing, so there the quickfix list
" is only filled on demand, through :CompileErrors
if has('nvim')
  augroup compile#quickfix
    autocmd!
    autocmd TermClose * if g:compile#autoQuickfix && str2nr(expand('<abuf>')) == s:termBuf
          \ | call compile#populateQuickfix() | endif
  augroup END
endif

function! g:compile#defaultMappings()
  nnoremap <C-c><C-c> :Compile<CR>
  nnoremap <C-c><C-t> :CompileTest<CR>
  nnoremap <C-c><C-b> :CompileSetCommands<CR>
  nnoremap <C-c><C-e> :CompileErrors<CR>
endfunction

