" We put our own autocommands into the "user" group, which is cleared each time
" .vimrc/_vimrc is reloaded. This avoids defining autocommands multiple times.
if has("autocmd")
    augroup user
    au! user
    augroup end
endif

set nocompatible

let mapleader=","

" Syntax highlighting and file type plugins {{{

syntax enable
filetype plugin indent on

" Highlight space errors

let c_space_errors = 1
let python_space_error_highlight = 1

" Default to highlighting sh scripts as Bash
let g:is_bash = 1

" Color scheme

if has("gui_running")
    silent! colorscheme oceandeep
elseif &t_Co >= 256
    silent! colorscheme molokai
endif

" }}}
" Indentation {{{

" C++ access specifiers in first column
set cinoptions+=g0

" Line up expressions/declarations with parenthesis split across multiple lines
" nicely
set cinoptions+=(0

" Do not indent 'case' inside of switch statements
set cinoptions+=:0

" }}}
" Editing {{{

set backspace=indent,eol,start

" Remember undo history when switching between files
if v:version > 702
    set undofile
endif

" No annoying beeps
set vb t_vb=

set completeopt-=menu

set autoread

" }}}
" Searching {{{

set wrapscan

set incsearch

set hlsearch

set ignorecase
set smartcase

" }}}
" Encoding and file formats {{{

set encoding=utf-8
set fileencodings=utf-8

" }}}
" Line length, wrapping, etc. {{{

set wrap
set textwidth=0
set linebreak

" Avoid J and gq inserting two spaces after .
set nojoinspaces

set showbreak=_

set display=lastline

" }}}
" Tab settings {{{

set expandtab

func! s:Adjust_tablen(len)
    let &tabstop     = a:len
    " Make backspace behave as if real tabs were used
    let &softtabstop = a:len
    let &shiftwidth  = a:len
    retab
endfunc

com! -nargs=1 Tab call s:Adjust_tablen(<f-args>)

" Default
Tab 4

" }}}
" Navigation {{{

" Fold at blocks delimited by {{{ and }}}
set foldmethod=marker
" Start with all folds expanded
if has("autocmd")
    au user BufNewFile,BufReadPost * setl foldlevel=100
endif
" Use right mouse button to open/close folds in the GUI
nnoremap <RightMouse> <LeftMouse>za
nnoremap <2-RightMouse> za

set scrolloff=5

set nostartofline

" Quickfix

nnoremap <silent> <s-left> :cp<CR>
nnoremap <silent> <s-right> :cn<CR>

" Bookmarks

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

" }}}
" Compiling and running C/C++ programs {{{

" Compiles a single-file C/++ program, optionally running it if no errors are
" produced (run), and optionally using Clang (use_clang)

func! Compile(run, use_clang)
    let f = expand("%")
    if empty(f)
        echoerr "No file bound to buffer"
        return
    endif
    if &ft == "cpp"
        let compiler = a:use_clang ? "clang++" : "g++"
    elseif &ft == "c"
        let compiler = a:use_clang ? "clang" : "gcc"
    else
        echoerr "Unknown language for '" . f . "'"
        return
    endif
    let old_makeprg = &makeprg
    let &makeprg = compiler . ' -o "%:r" -ggdb3 -Wall -Wno-unused-variable -Wno-unused-but-set-variable "%"'
    make
    let &makeprg = old_makeprg
    if a:run && empty(getqflist())
        !./"%:r"
    endif
    return
endfunc

" Compile using GCC and run
nnoremap <F5> :call Compile(1, 0)<CR>
" Compile using GCC
nnoremap <F6> :call Compile(0, 0)<CR>
" Compile using Clang
nnoremap <F7> :call Compile(0, 1)<CR>

" }}}
" Windows and tab pages {{{

set splitbelow
set splitright

" Quickly jump between windows

nnoremap <c-j> <c-w><c-j>
nnoremap <c-k> <c-w><c-k>
nnoremap <c-h> <c-w><c-h>
nnoremap <c-l> <c-w><c-l>

" Always display the status line
set laststatus=2

" }}}
" Tags {{{

" Search upwards for a file called 'tags'
set tags=tags;

" Rebuilding tags

func! s:Rebuild_tags()
    if filereadable("maketags")
        !./maketags
    else
        !ctags --languages=C,C++,Make --langmap=C++:+.inl
             \ --extra=fq --c-kinds=+p --c++-kinds=+p -R .
    endif
endfunc

com! Ctags call s:Rebuild_tags()

" Jumping to tags

nnoremap <space> <C-]>
nnoremap <silent> <2-LeftMouse> :tag <C-R>=expand("<cword>")<CR><CR>
nnoremap <silent> <MiddleMouse> :pop<CR>

nnoremap <silent> <left> :silent tp<CR>
nnoremap <silent> <right> :silent tn<CR>

" }}}
" GUI settings {{{

" Remove menubar, toolbar, and scrollbars

set guioptions-=m
set guioptions-=T

set guioptions-=r
set guioptions-=R
set guioptions-=l
set guioptions-=L
set guioptions-=b

set guitablabel=%f

" }}}
" Misc settings {{{

set mouse=a

set showcmd

set fillchars=vert:\ ,fold:\ 

set history=100

set shortmess+=I

" }}}
" Man pages {{{

runtime! ftplugin/man.vim

" }}}
" Plugins {{{

" Alternate

let g:alternateNoDefaultAlternate = 1

" Fugitive

" Include branch name in status line
set statusline=%<%f\ %h%m%r%{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P

" NERD commenter

" Supertab

let g:SuperTabDefaultCompletionType = "context"

" Tabular

" Aligning assignments
noremap <silent> <leader>t :Tabularize /=<CR>

" Taglist

nnoremap <silent> <F2> :TlistToggle<CR>

" }}}
" Site-specific settings {{{

if filereadable($HOME . "/conf/vimlocal")
    so ~/conf/vimlocal
endif

" }}}
" .vimrc reloading {{{

com! Reload so $MYVIMRC

" Reload .vimrc automatically when saved
if has("autocmd")
    au user bufwritepost .vimrc,_vimrc so $MYVIMRC
endif

" }}}
