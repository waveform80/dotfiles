"dein Scripts-----------------------------
set nocompatible               " Be iMproved
set runtimepath+=~/.vim/bundle/dein.vim/repos/github.com/Shougo/dein.vim

call dein#begin($HOME . '/.vim/bundle/dein.vim')
call dein#add('Shougo/dein.vim')

" Add or remove your plugins here:
call dein#add('ctrlpvim/ctrlp.vim')
call dein#add('tpope/vim-fugitive')
call dein#add('tpope/vim-rhubarb')
call dein#add('vim-airline/vim-airline')
call dein#add('vim-airline/vim-airline-themes')
call dein#add('dhruvasagar/vim-table-mode')
call dein#add('jtratner/vim-flavored-markdown')
call dein#add('terryma/vim-multiple-cursors')
call dein#add('tmhedberg/SimpylFold')

call dein#end()
"End dein Scripts-------------------------


" General options
set backspace=indent,eol,start " make backspace delete lots of things
set autoindent          " use auto-indent
set ruler               " display a ruler
set rnu                 " display relative line numbers
set nowrap              " do not wrap long lines in display
set textwidth=0         " turn off wordwrap while editing
set showcmd             " show partial commands in the status line
set showmatch           " highlight matching parens
set hlsearch            " highlight prior search matches
set incsearch           " incrementally search during / command
set lazyredraw          " speed up macros
set noerrorbells        " switch off annoying error beeps
set novisualbell        " disable the visual bell too
set expandtab           " expand tab characters
set tabstop=4           " tab characters are 4 spaces wide
set softtabstop=4       " soft-tab stops are 4 spaces wide
set shiftwidth=4        " shift commands shift 4 chars left / right
set scrolloff=3         " show three lines of context when scrolling
set sidescrolloff=4     " show four columns of context when scrolling
"set whichwrap+=<,>,[,]  " allow left/right cursor to move across lines
set hidden              " allow edit buffers to be hidden
set virtualedit=block   " enable virtual editing (partial tabs) in vblock
set modelines=10        " read 10 lines for modes
set cc=80               " display a bar at 80 columns
let mapleader=","       " leader key is a comma

" Permit a huge viminfo and command history
set viminfo='1000,f1,<100,h
set history=500

" Use the tab completion menu and ignore certain files
if has("wildmenu")
	set wildmenu
	set wildignore+=*~,*.pyc,*.pyd,*.pyo,*.P
endif

" Set up a fancy status line
if has("statusline")
	set laststatus=2
	let g:airline_powerline_fonts = 1
	let g:airline_theme = "powerlineish"
	let g:airline#extensions#branch#use_vcscommand = 1
	let g:airline#extensions#tabline#enabled = 1
endif

" Set up filetype syntax highlighting, indenting and folding
if has("syntax")
	syntax on             " activate syntax highlighting
	syntax sync fromstart " use slow-but-accurate syntax syncing
	highlight SpecialKey ctermfg=gray guifg=lightgray
endif
if has("eval")
	filetype on
	filetype plugin on    " activate file type matching & plugins
	filetype indent on    " activate file type specific indenting
endif

" Persistent undo
if has("persistent_undo")
	if glob($HOME . "/.vim/undo") == ""
		if exists("*mkdir")
			call mkdir($HOME . "/.vim/undo", "p", 0700)
		endif
	endif
	if glob($HOME . "/.vim/undo") != ""
		set undodir=$HOME/.vim/undo
		set undofile
		set undolevels=1000
		set undoreload=10000
	endif
endif

" Tweak file encoding priorities
set fileencodings=ucs-bom,utf-8,latin1
if v:lang =~ "utf8$" || v:lang =~ "UTF-8$"
	set fileencodings=utf-8,ucs-bom,latin1
endif

" GUI/Terminal specific configuration
if has("gui_running")
	set background=dark
	"set guifont=DejaVu\ Sans\ Mono\ for\ Powerline\ 10
	set guifont=Inconsolata\ for\ Powerline\ Medium\ 12
	set cursorline                                " use cursor row highlighting
	set list listchars=tab:»\ ,trail:·,extends:…  " visible whitespace
	"highlight Normal guifg=white guibg=black
	highlight SpecialKey guibg=bg
elseif &term =~ "xterm" || &term =~ "screen"
	set background=dark
	if !empty($DISPLAY)
		set t_Co=256         " yes, the terminal can handle 256 colors
	endif
	if &termencoding == ""
		set termencoding=utf-8
	endif
	" Show tabs and trailing whitespace visually
	if &termencoding == "utf-8"
		set list listchars=tab:»\ ,trail:·,extends:…
	else
		set list listchars=tab:>\ ,trail:.,extends:>
	endif
endif

" Auto commands
if has("eval")
	" Force active window to the top of the screen without losing its size
	fun! <SID>WindowToTop()
		let l:h=winheight(0)
		wincmd K
		execute "resize" l:h
	endfun
endif
if has("autocmd") && has("eval")
	" Always do a full syntax refresh
	autocmd BufEnter * syntax sync fromstart

	" For help files, move them to the top window and make <Return> behave
	" like <C-]> (jump to tag)
	autocmd FileType help :call <SID>WindowToTop()
	autocmd FileType help nmap <buffer> <Return> <C-]>

	" Set default text width to 78 for text files
	"autocmd BufNewFile,BufRead *.txt if &tw == 0 | set tw=78 | endif

	" Return to the last selected line
	autocmd BufReadPost *
		\ if line("'\"") > 0 && line ("'\"") <= line("$") |
		\     exe "normal g'\"" |
		\ endif
	autocmd FileType crontab set backupcopy=yes

	" Change some settings for certain languages
	autocmd FileType xhtml set et sw=2 sts=2
	autocmd FileType html set et sw=2 sts=2
	autocmd FileType xml set et sw=2 sts=2
	autocmd FileType python set et sw=4 sts=4 foldlevel=3
	autocmd FileType make set noet sw=8 ts=8
	autocmd BufNewFile,BufRead *.md,*.markdown setlocal filetype=ghmarkdown

	" Set line/relative numbers depending on mode
	autocmd InsertEnter * :set nornu number
	autocmd InsertLeave * :set relativenumber
endif

" Remap some annoying defaults (Q formats paragraphs, q: quits)
noremap Q gq
nnoremap q: :q

" Don't fold docstrings or imports
let g:SimpylFold_fold_docstring = 0
let g:SimpylFold_fold_import = 0

" Set up table-mode
let g:table_mode_corner_corner = "+"
let g:table_mode_header_fillchar = "="

" Get multi-cursor to play nice with CtrlP
let g:multi_cursor_prev_key = '<C-u>'

" Have CtrlP use git ls-files
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files -co --exclude-standard']

inoremap ,... …
inoremap ,-- –
inoremap ,--- —
inoremap ,(c) ©
inoremap ,(r) ®
inoremap ,o °
inoremap ,+- ±

