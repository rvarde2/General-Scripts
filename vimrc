call plug#begin()

Plug 'preservim/NERDTree'
Plug 'rightson/vim-p4-syntax'
Plug 'psf/black', { 'branch': 'stable' }
Plug 'ervandew/supertab'
Plug 'itchyny/lightline.vim'
Plug 'chriskempson/base16-vim'
Plug 'honza/vim-snippets'
call plug#end()

map <F2> :NERDTreeRefreshRoot<CR>:NERDTreeToggle<CR>

set number
set hlsearch
set showtabline=2
set laststatus=2
set shortmess-=S
set t_Co=256
set backspace=indent,eol,start
set ignorecase
set smartcase

set tabstop=4       " number of visual spaces per TAB
set softtabstop=4   " number of spaces in tab when editing
set shiftwidth=4    " Insert 4 spaces on a tab
set expandtab       " tabs are spaces, mainly because of python

autocmd BufRead *.bess set filetype=python
filetype plugin on
filetype indent on
set autoindent
set smartindent


nnoremap \\ :noh<return>
