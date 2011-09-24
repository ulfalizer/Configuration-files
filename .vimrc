" Avoid problems when reloading .vimrc
au!

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
    colorscheme oceandeep
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

set showbreak=_\ 

set display=lastline

" }}}
" Tab settings {{{

set expandtab

function! Adjust_tablen(len)
    let &tabstop     = a:len
    " Make backspace behave as if real tabs were used
    let &softtabstop = a:len
    let &shiftwidth  = a:len
    retab
endfunction

command! -nargs=1 Tab call Adjust_tablen(<f-args>)

" Default
Tab 4

" }}}
" Navigation {{{

" Fold at blocks delimited by {{{ and }}}
set foldmethod=marker

set scrolloff=5

set nostartofline

" Quickfix

nnoremap <s-left> :cp<CR>
nnoremap <s-right> :cr<CR>

" Bookmarks

if filereadable($HOME . "/.vimbookmarks")
    source $HOME/.vimbookmarks

    for key in keys(bookmarks)
        unlet! location file search_pattern

        let location = bookmarks[key]
        if type(location) == type("")
            let file = location
        else
            let [file, search_pattern] = location
        endif

        let cmd = "command! " . key . " :e " . file . " | call cursor(1,1)"

        if exists("search_pattern")
            let cmd .= ' | call search("' . search_pattern . '", "c")'
        endif

        exec cmd
    endfor
endif

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

function! Rebuild_tags()
    if filereadable("maketags")
        !./maketags
    else
        !ctags --languages=C,C++,Make --langmap=C++:+.inl
             \ --extra=fq --c-kinds=+p --c++-kinds=+p -R .
    endif
endfunction

command! Ctags call Rebuild_tags()

" Jumping to tags

nnoremap <space> <C-]>
nnoremap <2-LeftMouse> :tag <C-R>=expand("<cword>")<CR><CR>
nnoremap <MiddleMouse> :pop<CR>

nnoremap <left> :silent tp<CR>
nnoremap <right> :silent tn<CR>

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

" Enable mouse support
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
noremap <leader>t :Tabularize /=<CR>

" Taglist

nnoremap <silent> <F2> :TlistToggle<CR>

" }}}
" Project-specific settings {{{

au BufNewFile,BufReadPost */core-2-gogi/* setlocal noexpandtab

" }}}
" .vimrc reloading {{{

command! Reload source $MYVIMRC

" Reload .vimrc automatically when saved
if has("autocmd")
    autocmd bufwritepost .vimrc,_vimrc source $MYVIMRC
endif

" }}}
