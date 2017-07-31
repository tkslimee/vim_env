" ___vital___
" NOTE: lines between '" ___vital___' is generated by :Vitalize.
" Do not mofidify the code nor insert new lines before '" ___vital___'
if v:version > 703 || v:version == 703 && has('patch1170')
  function! vital#_openbrowser#Vim#Buffer#import() abort
    return map({'parse_cmdarg': '', '_vital_depends': '', 'read_content': '', 'get_selected_text': '', 'is_cmdwin': '', 'edit_content': '', 'open': '', 'get_last_selected': '', '_vital_loaded': ''},  'function("s:" . v:key)')
  endfunction
else
  function! s:_SID() abort
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze__SID$')
  endfunction
  execute join(['function! vital#_openbrowser#Vim#Buffer#import() abort', printf("return map({'parse_cmdarg': '', '_vital_depends': '', 'read_content': '', 'get_selected_text': '', 'is_cmdwin': '', 'edit_content': '', 'open': '', 'get_last_selected': '', '_vital_loaded': ''}, \"function('<SNR>%s_' . v:key)\")", s:_SID()), 'endfunction'], "\n")
  delfunction s:_SID
endif
" ___vital___
let s:save_cpo = &cpo
set cpo&vim

let s:t_funcref = type(function('tr'))
let s:t_string = type('')
let s:t_number = type(0)

function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:Guard = s:V.import('Vim.Guard')
endfunction

function! s:_vital_depends() abort
  return ['Vim.Guard']
endfunction

if exists('*getcmdwintype')
  function! s:is_cmdwin() abort
    return getcmdwintype() !=# ''
  endfunction
else
  function! s:is_cmdwin() abort
    return bufname('%') ==# '[Command Line]'
  endfunction
endif

function! s:open(buffer, ...) abort
  if a:0 == 1 && (type(a:1) == s:t_string || type(a:1) == s:t_funcref)
    " For backward compatibility
    let options = {'opener': a:1}
  else
    let options = get(a:000, 0, {})
  endif
  let options = extend({
        \ 'mods': '',
        \ 'cmdarg': '',
        \ 'opener': empty(a:buffer) ? 'enew' : 'edit',
        \}, options
        \)

  let guard = s:Guard.store(['&wildignore'])
  try
    let &wildignore = ''
    if type(options.opener) == s:t_funcref
      let loaded = !bufloaded(a:buffer)
      call options.opener(a:buffer)
    elseif a:buffer is 0 || a:buffer is# ''
      let loaded = 1
      silent execute options.mods options.opener
      enew
    else
      let loaded = !bufloaded(a:buffer)
      if type(a:buffer) == s:t_string
        execute options.mods options.opener options.cmdarg '`=a:buffer`'
      elseif type(a:buffer) == s:t_number
        silent execute options.mods options.opener
        execute a:buffer 'buffer'
      else
        throw 'vital: Vim.Buffer: Unknown {buffer} type.'
      endif
    endif
  finally
    call guard.restore()
  endtry
  return loaded
endfunction

function! s:get_selected_text(...) abort
  echohl WarningMsg
  echom "vital: Vim.Buffer: Warning: s:get_selected_text() is deprecated. Use 's:get_last_selected()'."
  echohl None
  return call('s:get_last_selected', a:000)
endfunction

" Get the last selected text in visual mode
" without using |gv| to avoid |textlock|.
" NOTE:
" * This function uses |gv| only when using |CTRL-V|
"   because |gv| is the only way to get selected text
"   when using <C-v>$ .
"   Please see #192 for the details.
" * If you don't care about |textlock|,
"   you can use simple version of this function.
"   https://github.com/vim-jp/vital.vim/commit/39aae80f3839fdbeebd838ff14d87327a6b889a9
function! s:get_last_selected() abort
  if visualmode() ==# "\<C-v>"
    let save = getreg('"', 1)
    let save_type = getregtype('"')
    try
      normal! gv""y
      return @"
    finally
      call setreg('"', save, save_type)
    endtry
  else
    let [begin, end] = [getpos("'<"), getpos("'>")]
    let lastchar = matchstr(getline(end[1])[end[2]-1 :], '.')
    if begin[1] ==# end[1]
      let lines = [getline(begin[1])[begin[2]-1 : end[2]-2]]
    else
      let lines = [getline(begin[1])[begin[2]-1 :]]
      \         + (end[1] - begin[1] <# 2 ? [] : getline(begin[1]+1, end[1]-1))
      \         + [getline(end[1])[: end[2]-2]]
    endif
    return join(lines, "\n") . lastchar . (visualmode() ==# 'V' ? "\n" : '')
  endif
endfunction

function! s:read_content(content, ...) abort
  let options = extend({
        \ 'tempfile': '',
        \ 'fileformat': '',
        \ 'encoding': '',
        \ 'binary': 0,
        \ 'nobinary': 0,
        \ 'bad': '',
        \ 'edit': 0,
        \ 'line': '',
        \ 'lockmarks': 0,
        \}, get(a:000, 0, {}))
  let tempfile = empty(options.tempfile) ? tempname() : options.tempfile
  let optnames = [
        \ empty(options.fileformat) ? '' : '++ff=' . options.fileformat,
        \ empty(options.encoding) ? '' : '++enc=' . options.encoding,
        \ empty(options.binary) ? '' : '++bin',
        \ empty(options.nobinary) ? '' : '++nobin',
        \ empty(options.bad) ? '' : '++bad=' . options.bad,
        \ empty(options.edit) ? '' : '++edit',
        \]
  let optname = join(filter(optnames, '!empty(v:val)'))
  try
    call writefile(a:content, tempfile)
    execute printf('keepalt keepjumps %s%sread %s%s',
          \ options.lockmarks ? 'lockmarks ' : '',
          \ options.line,
          \ empty(optname) ? '' : optname . ' ',
          \ fnameescape(tempfile),
          \)
  finally
    call delete(tempfile)
    " To remove 'tempfile' from unlisted-buffer #439
    silent execute 'bwipeout!' fnameescape(tempfile)
  endtry
endfunction

function! s:edit_content(content, ...) abort
  let options = extend({
        \ 'edit': 1,
        \ 'lockmarks': 0,
        \}, get(a:000, 0, {}))
  let guard = s:Guard.store(['&l:modifiable'])
  let saved_view = winsaveview()
  try
    let &l:modifiable=1
    silent execute printf(
          \ 'keepjumps %s%%delete _',
          \ options.lockmarks ? 'lockmarks ' : '',
          \)
    silent call s:read_content(a:content, options)
    silent execute printf(
          \ 'keepjumps %s1delete _',
          \ options.lockmarks ? 'lockmarks ' : '',
          \)
  finally
    keepjumps call winrestview(saved_view)
    call guard.restore()
  endtry
  setlocal nomodified
endfunction

function! s:parse_cmdarg(...) abort
  let cmdarg = get(a:000, 0, v:cmdarg)
  let options = {}
  if cmdarg =~# '++enc='
    let options.encoding = matchstr(cmdarg, '++enc=\zs[^ ]\+\ze')
  endif
  if cmdarg =~# '++ff='
    let options.fileformat = matchstr(cmdarg, '++ff=\zs[^ ]\+\ze')
  endif
  if cmdarg =~# '++bad='
    let options.bad = matchstr(cmdarg, '++bad=\zs[^ ]\+\ze')
  endif
  if cmdarg =~# '++bin'
    let options.binary = 1
  endif
  if cmdarg =~# '++nobin'
    let options.nobinary = 1
  endif
  if cmdarg =~# '++edit'
    let options.edit = 1
  endif
  return options
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
