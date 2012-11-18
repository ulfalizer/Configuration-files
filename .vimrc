" We put our own autocommands into the "user" group, which is cleared each time
" .vimrc/_vimrc is reloaded. This avoids defining autocommands multiple times.
if has("autocmd")
    augroup user
    au! user
    augroup end
endif

filetype plugin indent on
set nocompatible

" Generic settings {{{
" Editing {{{

set autoread
set backspace=indent,eol,start
" C++ access specifiers in first column
set cinoptions+=g0
" Line up expressions/declarations with parenthesis split across multiple lines
" nicely
set cinoptions+=(0
" Do not indent 'case' inside of switch statements
set cinoptions+=:0
set encoding=utf-8
set fileencodings=utf-8
set history=100
let mapleader=","
set mouse=a
" Avoid J and gq inserting two spaces after .
set nojoinspaces
if v:version > 702
    " Remember undo history when switching between files
    set undofile
endif
" No annoying beeps
set vb t_vb=

" Tab settings

set expandtab

func! s:Adjust_tablen(len)
    let &tabstop     = a:len
    " Make backspace behave as if real tabs were used
    let &softtabstop = a:len
    let &shiftwidth  = a:len
endfunc

com! -nargs=1 -bar Tab call s:Adjust_tablen(<f-args>)

" Default
au user BufNewFile,BufReadPre * Tab 4

" }}}
" Navigation {{{

set nostartofline
set scrolloff=5

" Searching

set hlsearch
set ignorecase
set incsearch
set smartcase
set wrapscan

" Folding

" Fold at blocks delimited by {{{ and }}}
set foldmethod=marker
" Start with all folds expanded
if has("autocmd")
    au user BufNewFile,BufReadPost * setl foldlevel=100
endif
" Use right mouse button to open/close folds in the GUI
nnoremap <special> <RightMouse> <LeftMouse>za
nnoremap <special> <2-RightMouse> za

" Quickfix

nnoremap <silent> <special> <s-left> :cp<CR>
nnoremap <silent> <special> <s-right> :cn<CR>

" Simple bookmarking system. Reads a dictionary of bookmarks 'bookmarks' from
" ~/.vimbookmarks . The key of each dictionary entry is the bookmark name. The
" corresponding value specifies a location for the bookmark and takes one of
" two forms:
"
" 1) A filename as a string. In this case the bookmark is for the beginning of
"    the file.
"
" 2) A list containing a filename and a search pattern as strings. In this
"    case the bookmark is for the first line in the file containing the search
"    pattern.
"
" The interface is the ':Go <bookmark>' command, which supports completion on
" bookmarks.

func! s:GoFn(where, has_exclamation)
    if !filereadable($HOME . "/.vimbookmarks")
        echoerr "Could not read ~/.vimbookmarks"
        return
    endif
    so ~/.vimbookmarks

    if !has_key(g:bookmarks, a:where)
        echoerr "The bookmark '" . a:where . "' is not defined"
        return
    endif
    let location = g:bookmarks[a:where]
    if type(location) == type("")
        let file = location
    else
        let [file, search_pattern] = location
    endif

    if a:has_exclamation == 1
        exec "edit! " . file
    else
        exec "edit " . file
    end
    call cursor(1, 1)
    if exists("search_pattern")
        call search(search_pattern, "c")
    endif
endfunc

func! s:Complete_bookmark(ArgLead, CmdLine, CursorPos)
    if !filereadable($HOME . "/.vimbookmarks")
        echoerr "Could not read ~/.vimbookmarks"
        return
    endif
    so ~/.vimbookmarks

    let entries = keys(g:bookmarks)
    call filter(entries, 'v:val =~ "^" . a:ArgLead')
    call sort(entries)
    return entries
endfunc

com! -nargs=1 -complete=customlist,s:Complete_bookmark -bang Go call s:GoFn(<f-args>, <bang>0)

" Tags

" Search upwards for a file called 'tags'
set tags=tags;

func! s:Rebuild_tags()
    if filereadable("maketags")
        !./maketags
    else
        !ctags --languages=C,C++,Make --langmap=C++:+.inl
             \ --extra=fq --c-kinds=+p --c++-kinds=+p -R .
    endif
endfunc

com! Ctags call s:Rebuild_tags()

nnoremap <special> <space> <C-]>
nnoremap <silent> <special> <2-LeftMouse> :tag <C-R>=expand("<cword>")<CR><CR>
nnoremap <silent> <special> <MiddleMouse> :pop<CR>

nnoremap <silent> <special> <left> :silent tp<CR>
nnoremap <silent> <special> <right> :silent tn<CR>

" Always display the status line
set laststatus=2
set splitbelow
set splitright

" Quickly jump between windows

noremap <special> <c-j> <c-w><c-j>
noremap <special> <c-k> <c-w><c-k>
noremap <special> <c-h> <c-w><c-h>
noremap <special> <c-l> <c-w><c-l>

" }}}
" Presentation {{{

" Syntax highlighting

syntax enable

" Color scheme

if has("gui_running")
    silent! colorscheme oceandeep
elseif &t_Co >= 256
    silent! colorscheme molokai
endif

" Highlight space errors

let c_space_errors = 1
let python_space_error_highlight = 1

" Default to highlighting sh scripts as Bash
let g:is_bash = 1

" Line wrapping

set display=lastline
set linebreak
set showbreak=_
set wrap

" Remove menubar, toolbar, and scrollbars in GUI

set guioptions-=m
set guioptions-=T
set guioptions-=r
set guioptions-=R
set guioptions-=l
set guioptions-=L
set guioptions-=b
set guitablabel=%f

set fillchars=vert:\ ,fold:\ 
set shortmess+=I
set showcmd

" }}}
" }}}
" Development {{{

" Compiles a single-file C/C++ program, optionally running it if compilation
" succeeds (run), and optionally using Clang (use_clang). Opens the quickfix
" window and jumps to the first error or warning, if any.

func! Compile(run, use_clang)
    let f = expand("%")
    let f_esc = shellescape(f)
    let f_root_esc = shellescape(expand("%:r"))
    if empty(f)
        echoerr "No file bound to buffer"
        return
    endif
    " Determine compiler to use
    if &ft == "cpp"
        let compiler = a:use_clang ? "clang++" : "g++"
    elseif &ft == "c"
        let compiler = a:use_clang ? "clang" : "gcc"
    else
        echoerr "Unknown language for '".f."'"
        return
    endif
    " Always write before compiling
    w
    " Compile and create quickfix list of errors and warnings
    silent cexpr system(compiler." -o ".f_root_esc.
      \ " -ggdb3 -Wall -Wno-unused-variable -Wno-unused-but-set-variable ".
      \ f_esc)
    " Run the program if the compilation succeeded
    if a:run && v:shell_error == 0
        exec "!./".f_root_esc
    endif
    " Open the quickfix window if there are errors or warnings. Close it
    " otherwise.
    cw
    " If we are in the quickfix window, press enter to jump to the first error
    if &buftype == "quickfix"
        exec "normal \<CR>"
    endif
endfunc

" Compile using GCC and run
noremap <silent> <special> <F5> :call Compile(1, 0)<CR>
" Compile using Clang and run
noremap <silent> <special> <F6> :call Compile(1, 1)<CR>
" Compile using GCC
noremap <silent> <special> <F7> :call Compile(0, 0)<CR>
" Compile using Clang
noremap <silent> <special> <F8> :call Compile(0, 1)<CR>

" Allow the same mappings to be used in insert mode

imap <special> <F5> <ESC><F5>
imap <special> <F6> <ESC><F6>
imap <special> <F7> <ESC><F7>
imap <special> <F8> <ESC><F8>

" Format settings for system headers

" Disable highlighting for space errors in system headers, as they are very
" common. :/
au user BufReadPre /usr/include/*,/usr/local/include/*
  \ Tab 8 |
  \ hi! link cSpaceError NONE

" }}}
" Plugins {{{

runtime! ftplugin/man.vim

" Alternate

let g:alternateNoDefaultAlternate = 1

" Fugitive

" Include branch name in status line
set statusline=%<%f\ %h%m%r%{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P

" Taglist

nnoremap <silent> <special> <F2> :TlistToggle<CR>

" }}}

" Site-specific settings

if filereadable($HOME . "/conf/vimlocal")
    so ~/conf/vimlocal
endif

" .vimrc reloading

com! Reload so $MYVIMRC

" Reload .vimrc automatically when saved
if has("autocmd")
    au user BufWritePost .vimrc,_vimrc so $MYVIMRC
endif
