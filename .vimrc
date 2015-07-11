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

" Make text formatting (e.g. gq) use the indent of the first line
set autoindent
set autoread
set backspace=indent,eol,start
" Do not indent case labels and C++ access specifiers
set cinoptions+=:0
set cinoptions+=g0
" Use a constant indent for continuation lines by default. (Gives nice diffs.)
set cinoptions+=+0.5s " Continuation line
set cinoptions+=(0.5s " Continuation line in parentheses
set cinoptions+=u0 " Do not let additional parentheses influence the indent
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
" Time out quickly on key codes. This makes e.g. <esc>O work more reliably.
set ttimeoutlen=100
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
set nowrap

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

" Compiles a program. Uses 'make' if 'Makefile' exists in the current
" directory. Otherwise, the program is assumed to consist of a single
" translation unit and the language (C or C++) is inferred from the file
" extension. In this case, clang/clang++ is used if 'use_clang' is 1 and
" gcc/g++ otherwise.
"
" Returns a [succeeded, out_file] tuple, where 'succeeded' is 1 if compilation
" was successful (an executable was produced) and 0 otherwise, and where
" 'out_file' is the name of the produced executable. When building with
" 'make', the executable name is looked up in a dictionary 'proj_exes' that
" links project directories to executable names.
func! <SID>Compile(use_clang)
    if filereadable("Makefile")
        " If the current directory contains a Makefile, compile using 'make'

        " If a file is bound to the current buffer, write it first
        if expand("%") != "" | w | endif

        let messages = system("make")
        let succeeded = (v:shell_error == 0)

        " Look up the current directory to see if an executable has been
        " registered for it
        if !exists("g:proj_exes")
            echoerr "g:proj_exes does not exist"
            return [0, ""]
        endif

        let proj_dir = expand("%:p:h:t")
        let out_file = get(g:proj_exes, proj_dir, "")

        if !strlen(out_file)
            echoerr "No executable set for directory '".proj_dir."'"
            return [0, ""]
        endif

    else
        " If the current directory contains no Makefile, compile just the file
        " bound to the current buffer

        let f = expand("%")
        if empty(f)
            echoerr "No file bound to buffer"
            return [0, ""]
        endif

        " Write before compiling
        w

        " Determine compiler to use
        if &ft == "cpp"
            let compiler = a:use_clang ? "clang++" : "g++"
        elseif &ft == "c"
            let compiler = a:use_clang ? "clang" : "gcc"
        else
            echoerr "Unknown language for '".f."'"
            return [0, ""]
        endif

        if !executable(compiler)
            echoerr "No executable '".compiler."' exists"
            return [0, ""]
        endif

        let out_file = expand("%:r")
        let messages = system(compiler." -o ".shellescape(out_file).
          \ " -ggdb3 -Wall -Wno-unused-variable ".shellescape(f))
        let succeeded = (v:shell_error == 0)
    endif

    " Create quickfix list
    silent cexpr messages
    " Display the quickfix window if there are warnings or errors or if the
    " compilation failed; hide it otherwise.
    if succeeded
        cwindow
    else
        copen
    endif
    " If we are in the quickfix window, press enter to jump to the first error
    if &buftype == "quickfix"
        exec "normal \<CR>"
    endif

    if succeeded && !filereadable(out_file)
        echoerr "The executable '".out_file."' does not exist even though"
          \ "compilation was successful"
        return [0, ""]
    endif

    return [succeeded, out_file]
endfunc

" Compiles the current file/project and runs it if compilation succeeds
func! <SID>Compile_and_run(use_clang)
    let [succeeded, out_file] = <SID>Compile(a:use_clang)

    if succeeded && strlen(out_file)
        exec "!./".shellescape(out_file)
    endif
endfunc

" Compiles a single-file C/C++ program, optionally running it if compilation
" succeeds (run), and optionally using Clang (use_clang). Opens the quickfix
" window and jumps to the first error or warning, if any. Returns 1 if the
" compilation succeeded; otherwise returns 0.

" Compile using GCC and run
noremap <silent> <special> <F5> :call <SID>Compile_and_run(0)<CR>
" Compile using Clang and run
noremap <silent> <special> <F6> :call <SID>Compile_and_run(1)<CR>
" Compile using GCC
noremap <silent> <special> <F7> :call <SID>Compile(0)<CR>
" Compile using Clang
noremap <silent> <special> <F8> :call <SID>Compile(1)<CR>

" Allow the same mappings to be used in insert mode

imap <special> <F5> <ESC><F5>
imap <special> <F6> <ESC><F6>
imap <special> <F7> <ESC><F7>
imap <special> <F8> <ESC><F8>

" Project-specific formatting

" Disable highlighting for space errors in system headers, as they are very
" common. :/
au user BufReadPost /usr/include/*,/usr/local/include/*
  \ Tab 8 |
  \ hi! link cSpaceError NONE |
  \ if expand("%") =~ '\w+' | set ft=cpp | endif

" Linux kernel
au user BufNewFile,BufReadPost */linux*/* Tab 8 | setl noexpandtab

" }}}
" Plugins {{{

runtime! ftplugin/man.vim

" Alternate

let g:alternateNoDefaultAlternate = 1

" Fugitive

" Include branch name in status line
set statusline=%<%f\ %h%m%r%{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P

" Pyclewn

let g:pyclewn_args = "--args=-q --gdb=async --terminal=gnome-terminal,-x --window=bottom"
" Uncomment for debugging:
"let g:pyclewn_args .= " --file=pyclewnlog"
"let g:pyclewn_args .= " -ldebug"

" Starts debugging the current file with pyclewn. If compilation fails, acts
" like Compile(). Debugging files with special characters seems to be broken,
" but it's probably pyclewn's fault.

func! s:DebugFn(enable)
    " Always close a previous session
    nbclose
    silent! unmap b
    silent! unmap B
    silent! unmap c
    silent! unmap f
    silent! unmap G
    silent! unmap m
    silent! unmap r
    silent! unmap s
    silent! unmap S
    silent! unmap <special> <up>
    silent! unmap <special> <down>
    if !a:enable
        return
    endif

    " Compile (using GCC if there's no Makefile)
    let [succeeded, out_file] = <SID>Compile(0)
    " Do not start pyclewn if compilation failed or we got no executable name
    if !succeeded || !strlen(out_file)
        return
    endif

    " Start pyclewn, load debug symbols, and set up mappings
    Pyclewn
    exe "Cfile ".fnameescape(out_file)

    noremap <silent> <special> b :exe "Cbreak ".fnameescape(expand("%:p")).":".line(".")<CR>
    noremap <silent> <special> B :exe "Cclear ".fnameescape(expand("%:p")).":".line(".")<CR>
    noremap <silent> <special> c :Ccontinue<CR>
    noremap <silent> <special> f :Cfinish<CR>
    " Mnemonic: goto
    noremap <silent> <special> G :exe "Cuntil ".fnameescape(expand("%:p")).":".line(".")<CR>
    " Mnemonic: main
    noremap <silent> <special> m :Cstart<CR>
    noremap <silent> <special> r :Crun<CR>
    noremap <silent> <special> s :Cnext<CR>
    noremap <silent> <special> S :Cstep<CR>
    noremap <silent> <special> <up> :Cup<CR>
    noremap <silent> <special> <down> :Cdown<CR>
    " We could do a 'start' here to be a bit more convenient, but for some
    " reason it will sometimes execute before the 'file'. Sleeping for a while
    " seems to fix it but is annoying.
endfunc

com! Debug call s:DebugFn(1)
com! Nodebug call s:DebugFn(0)
noremap <silent> <special> <F9> :Debug<CR>
noremap <silent> <special> <F10> :Nodebug<CR>

" Taglist

nnoremap <silent> <special> <F2> :TlistToggle<CR>

" }}}

" Site-specific settings

if filereadable($HOME . "/conf/vimlocal")
    so ~/conf/vimlocal
endif

au user BufReadPost ~/conf/bashlocal set ft=sh
au user BufReadPost ~/conf/gdblocal set ft=gdb
au user BufReadPost ~/conf/vimlocal set ft=vim

" .vimrc reloading

com! Reload so $MYVIMRC

" Reload .vimrc automatically when saved
if has("autocmd")
    au user BufWritePost .vimrc,_vimrc so $MYVIMRC
endif
