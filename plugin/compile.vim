let g:compile#commands = {'compile': {}, 'test': {}}

function! g:compile#spawnTerminal(cmd)
  if has('nvim')
    topleft split
    resize 20
    exec 'terminal ' . a:cmd
    normal i
  else
    echoerr 'This feature is unstable in Vim'
    exec 'topleft terminal ' . a:cmd
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
    throw l:ft
  endif

  if a:kind ==# 'compile'
    let l:prompt = 'Compile with command: '
  elseif a:kind ==# 'test'
    let l:prompt = 'Test with command: '
  else
    echoerr 'Invalid command type: ' . a:kind
    throw a:kind
  endif

  let l:userCmd = input(l:prompt, '')

  let g:compile#commands[a:kind][l:ft] = l:userCmd

  return l:userCmd
endfunction

function! g:compile#runCommand(kind, reset = v:false)
  let l:ft = &filetype

  let l:dict = g:compile#commands[a:kind]

  if has_key(l:dict, ft) && !a:reset
    call compile#spawnTerminal(l:dict[l:ft])
  else
    call compile#requestCommand(a:kind, l:ft)
    call compile#spawnTerminal(l:dict[l:ft])
  endif
endfunction

command! Compile call compile#runCommand('compile')
command! CompileTest call compile#runCommand('test')
command! -nargs=? CompileSetCommands call compile#requestCommand('compile', <args>) | call compile#requestCommand('test', <args>)

