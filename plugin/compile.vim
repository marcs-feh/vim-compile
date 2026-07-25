" if exists('g:compile#loaded')
"   finish
" endif

let g:compile#loaded = 1

if !exists('g:compile#splitDir')
  let g:compile#splitDir = 'top'
endif

let g:compile#commands = {'compile': {}, 'test': {'vim':'ls'}}

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
    normal i
  else
    " echoerr 'This feature is unstable in Vim'
    exec l:mod . ' terminal ' . a:cmd
    nnoremap <buffer> <silent> <CR> :bdelete <CR>
    echo 'Press Enter to Exit terminal'
  endif
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

function! g:compile#defaultMappings()
  nnoremap <C-c><C-c> :Compile<CR>
  nnoremap <C-c><C-t> :CompileTest<CR>
  nnoremap <C-c><C-b> :CompileSetCommands<CR>
endfunction

