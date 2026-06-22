syntax enable
filetype plugin indent on

set autoread
set number relativenumber
set expandtab shiftwidth=2 tabstop=2
set hlsearch incsearch ignorecase smartcase
set nowrap
set confirm
set wildmenu
set wildmode=longest:full,full
set wildoptions=pum,fuzzy
set path+=**
set wildignore+=*.o,*.obj,*.pyc,*.class,*.swp,.DS_Store,*/.DS_Store
set wildignore+=.git/**,node_modules/**,dist/**,build/**,target/**
set grepprg=grep\ -rn\ $*\ .

function! s:FindFiles(dir, prefix) abort
  let l:files = []
  for l:name in readdir(a:dir)
    let l:path = a:dir . '/' . l:name
    let l:relative = empty(a:prefix) ? l:name : a:prefix . '/' . l:name

    if isdirectory(l:path)
      if index(['.git', 'node_modules', 'dist', 'build', 'target'], l:name) >= 0
        continue
      endif
      if getftype(l:path) !=# 'link'
        call extend(l:files, s:FindFiles(l:path, l:relative))
      endif
    elseif filereadable(l:path)
      call add(l:files, l:relative)
    endif
  endfor

  return l:files
endfunction

function! s:WildIgnored(file) abort
  for l:pattern in split(&wildignore, ',')
    if !empty(l:pattern) && a:file =~# glob2regpat(l:pattern)
      return 1
    endif
  endfor

  return 0
endfunction

function! s:FindComplete(arglead, cmdline, cursorpos) abort
  let l:files = filter(s:FindFiles('.', ''), '!s:WildIgnored(v:val)')
  let l:files = sort(uniq(l:files))
  return empty(a:arglead) ? l:files : matchfuzzy(l:files, a:arglead)
endfunction

function! s:FindFile(query, command) abort
  let l:matches = s:FindComplete(a:query, '', 0)
  if empty(l:matches)
    echoerr 'No file matching: ' . a:query
    return
  endif

  execute a:command . ' ' . fnameescape(l:matches[0])
endfunction

command! -nargs=1 -complete=customlist,s:FindComplete Find call s:FindFile(<q-args>, 'edit')
command! -nargs=1 -complete=customlist,s:FindComplete F call s:FindFile(<q-args>, 'split')
cnoreabbrev <expr> f getcmdtype() ==# ':' && getcmdline() ==# 'f' ? 'Find' : 'f'

nnoremap <silent> <Esc> :nohlsearch<CR>

autocmd FileType markdown setlocal wrap
