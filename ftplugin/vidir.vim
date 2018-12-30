" what: ftplugin/vidir.vim
"  who: by Raimondi
" when: 2018-12-30

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another filetype plugin for this buffer
let b:did_ftplugin = 1

" Allow use of line continuation.
let s:save_cpo = &cpo
set cpo&vim

" Restore things when changing filetype.
let b:undo_ftplugin = "setl ofu< | augroup vidir_ls | exec 'au! CursorMoved,CursorMovedI <buffer>'|augroup END"

" do not allow the cursor to move back into the line numbers
function! s:on_cursor_moved()
  let fname_pos = match(getline('.'), '^ *\d\+ \zs\S') + 1
  let cur_pos = col('.')
  if fname_pos < 1 || cur_pos >= fname_pos
    " nothing to do
    return
  endif
  " move cursor back to a sensible place
  call cursor(line('.'), fname_pos)
endfunction

" do not allow non-numeric changes to the file index column
function! s:on_text_changed()
  let broken_lines = []
  silent vglobal/^ *\d\+ / call add(broken_lines, line('.'))
  if empty(broken_lines)
    " nothing to do
    return
  endif
  " let's try to fix a simple substitution of spaces, e.g.:
  " :%s/ /foobar/g
  let broken = 0
  let lines = getline(1, '$')
  " line numbers start at 1, let's make lines behave like it's 1 indexed
  call insert(lines, '')
  let patterns = {}
  for linenr in broken_lines
    let line = get(lines, linenr)
    let file_index = matchstr(line, '\d\+')
    let indent = matchstr(line, '^\D*')
    " how many spaces were substituted
    let modulus = 5 - len(file_index)
    let indent_len = len(indent)
    if indent_len % modulus
      " doesn't look like a simple substitution
      let broken = 1
      break
    endif
    if empty(indent)
      " use previous patterns
      let substr_pat = get(filter(keys(patterns),
            \ 'line =~# "\\m^\\d\\+".v:val'), -1, '')
      if empty(substr_pat)
        " no previous pattern matched
        let broken = 1
        break
      endif
      let path = matchstr(line, printf('\m^\d\+%s\zs.*', substr_pat))
    else
      let substr_len = indent_len / modulus
      let substr_pat = printf('\D\{%d}', substr_len)
      let pat = printf('\m^\(%s\)\{%d}\d\+\1', substr_pat, modulus)
      let matched = line =~# pat
      if !matched
        " it's not a simple substitution
        let broken = 1
        break
      endif
      let patterns[substr_pat] = 1
      let times = substr_len * (modulus + 1) + len(file_index)
      let path = matchstr(line, printf('\m^.\{%d}\zs.*', times))
    endif
    let lines[linenr] = printf('%5d %s', file_index, path)
  endfor
  if broken
    " we couldn't fix the change, let's roll it back!
    silent undo
    " user should know better, let's apply some scolding
    echohl WarningMsg
    echom 'Vidir: do not change the leading numbers or the whitespace around them'
    echohl Normal
    return
  endif
  " found the right magic!
  undojoin
  call setline(1, lines[1:])
endfunction

augroup vidir_ls
  autocmd!
  autocmd CursorMoved,CursorMovedI <buffer> call s:on_cursor_moved()
  autocmd TextChanged,TextChangedI <buffer> call s:on_text_changed()
augroup END

"reset &cpo back to users setting
let &cpo = s:save_cpo

" vim: set sw=2 sts=2 et fdm=marker:
