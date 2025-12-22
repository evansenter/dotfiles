" ==============================================================================
" General
" ==============================================================================

set nocompatible              " Use Vim defaults, not Vi
set encoding=utf-8            " UTF-8 encoding
set history=1000              " Command history
set backspace=indent,eol,start " Backspace over everything

" ==============================================================================
" UI
" ==============================================================================

syntax on                     " Syntax highlighting
colorscheme catppuccin_mocha  " Catppuccin theme
set number                    " Line numbers
set ruler                     " Show cursor position
set showcmd                   " Show incomplete commands
set showmode                  " Show current mode
set laststatus=2              " Always show status line
set wildmenu                  " Command-line completion
set wildmode=longest:list,full
set scrolloff=3               " Keep lines above/below cursor
set visualbell                " No beeping

" ==============================================================================
" Search
" ==============================================================================

set incsearch                 " Search as you type
set hlsearch                  " Highlight matches
set ignorecase                " Case-insensitive search
set smartcase                 " Unless uppercase used

" ==============================================================================
" Indentation
" ==============================================================================

filetype plugin indent on     " File-type detection and indentation
set autoindent                " Copy indent from current line
set expandtab                 " Spaces instead of tabs
set tabstop=2                 " Tab = 2 spaces
set shiftwidth=2              " Indent = 2 spaces
set softtabstop=2             " Backspace through spaces

" ==============================================================================
" Files
" ==============================================================================

set autoread                  " Reload files changed outside vim
set noswapfile                " No swap files
set nobackup                  " No backup files
set nowritebackup             " No backup before overwriting

" ==============================================================================
" Key Mappings
" ==============================================================================

" Clear search highlight with Escape
nnoremap <Esc> :nohlsearch<CR><Esc>

" Quick save
nnoremap <leader>w :w<CR>
