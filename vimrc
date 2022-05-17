" General options
set nocompatible               " Be iMproved
set backspace=indent,eol,start " make backspace delete lots of things
set autoindent          " use auto-indent
set ruler               " display a ruler
set rnu                 " display relative line numbers
set nowrap              " do not wrap long lines in display
set nojoinspaces        " do not use double-spaces after .!? when joining
set textwidth=0         " turn off wordwrap while editing
set showcmd             " show partial commands in the status line
set showmatch           " highlight matching parens
set hlsearch            " highlight prior search matches
set incsearch           " incrementally search during / command
set ignorecase          " ignore case in searches...
set smartcase           " ... but only when everything's lowercase
set lazyredraw          " speed up macros
set noerrorbells        " switch off annoying error beeps
set novisualbell        " disable the visual bell too
set expandtab           " expand tab characters
set tabstop=4           " tab characters are 4 spaces wide
set softtabstop=4       " soft-tab stops are 4 spaces wide
set shiftwidth=4        " shift commands shift 4 chars left / right
set scrolloff=3         " show three lines of context when scrolling
set sidescrolloff=4     " show four columns of context when scrolling
set hidden              " allow edit buffers to be hidden
set virtualedit=block   " enable virtual editing (partial tabs) in vblock
set modelines=10        " read 10 lines for modes
set colorcolumn=+1,80   " display a bar just after "textwidth" and at 80
set completeopt=menu    " don't display preview window with completions
let mapleader=","       " leader key is a comma

" Permit a huge viminfo and command history
set viminfo='1000,f1,<100,h
set history=500

" Pretty print options
set printfont=courier:h9
set printoptions=paper:a4,formfeed:y,number:y,left:36pt,right:36pt,top:36pt,bottom:36pt

if has("packages")
	if isdirectory("/usr/share/vim-scripts/AlignPlugin")
		packadd! AlignPlugin
	endif
	if isdirectory("/usr/share/vim-scripts/python-indent")
		packadd! python-indent
	endif
	if isdirectory("/usr/share/vim-scripts/supertab")
		packadd! supertab
	endif
endif

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
	if !exists('g:airline_symbols')
		let g:airline_symbols = {}
	endif
	let g:airline_symbols.crypt = '⌇'
	let g:airline_symbols.dirty = '⌁'
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

" Terminal configuration
if &term =~ "xterm" || &term =~ "screen"
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
	autocmd FileType vim set noet tw=79
	autocmd FileType mail setlocal formatoptions=2awtcq spell
	autocmd FileType xhtml set et sw=2 sts=2
	autocmd FileType html set et sw=2 sts=2
	autocmd FileType xml set et sw=2 sts=2
	autocmd FileType make set noet sw=8 ts=8
	autocmd FileType rst set tw=79
	autocmd BufNewFile,BufRead *.md,*.markdown setlocal filetype=ghmarkdown
	autocmd BufNewFile,BufRead *.moin,*.wiki setlocal filetype=moin
	autocmd FileType mail let g:SuperTabDefaultCompletionType="<c-x><c-u>"
	autocmd FileType mail let g:notmuch_query_suffix="
		\ AND NOT from:*noreply*@*
		\ AND NOT from:*@bugs.launchpad.net
		\ AND NOT from:*@code.launchpad.net
		\ AND NOT from:rt@admin.canonical.com
		\ AND NOT from:notifications@github.com"

	" Set line/relative numbers depending on mode
	autocmd InsertEnter * :set nornu number
	autocmd InsertLeave * :set relativenumber
endif

" Set up table-mode
let g:table_mode_corner_corner = "+"
let g:table_mode_header_fillchar = "="

" Configure syntastic
let g:syntastic_mode_map = {
	\ "mode": "passive",
	\ "active_filetypes": [],
	\ "passive_filetypes": [] }
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_aggregate_errors = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_python_checkers = ['pylint']
if &termencoding == "utf-8"
	let g:syntastic_error_symbol = "\u274C"
	let g:syntastic_warning_symbol = "\u2757"
	let g:syntastic_style_error_symbol = "\u2753"
	let g:syntastic_style_warning_symbol = "\u2753"
else
	let g:syntastic_error_symbol = "X"
	let g:syntastic_warning_symbol = "!"
	let g:syntastic_style_error_symbol = "?"
	let g:syntastic_style_warning_symbol = "?"
endif

" Disable lots of Jedi stuff (too slow on a Pi)
let g:jedi#show_call_signatures = 0
let g:jedi#smart_auto_mappings = 0
let g:jedi#popup_on_dot = 0

" Configure tagbar
let g:tagbar_autofocus = 1
let g:tagbar_position = 'topleft vertical'
let g:tagbar_show_visibility = 0
let g:tagbar_show_tag_count = 1
let g:tagbar_iconchars = ['▸', '▾']
let g:tagbar_file_size_limit = 100000

" Convert bug numbers into LP: # markdown links
function! BugLink() abort
	" Are we at the start of a WORD?
	let pos = getpos('.')
	normal! bw
	if pos != getpos('.')
		" We weren't at the start of a WORD, so move back to it
		normal! b
	endif
	" If there's a leading # then strip it off
	if getpos('.')[2] > 1 && getline('.')[getpos('.')[2] - 2] == "#"
		normal! hx
	endif
	let bug = expand('<cword>')
	execute 'normal! ce[LP: #' . bug . '](https://launchpad.net/bugs/' . bug . ')'
endfunction
nnoremap <Leader>lp :exe ":call BugLink()"<CR>

" Remap some annoying defaults (Q formats paragraphs, q: quits)
noremap Q gq
nnoremap q: :q

" Some normal-mode mappings for various plugins
nnoremap <Leader>pl :SyntasticCheck<CR>
nnoremap <Leader>pr :SyntasticReset<CR>:lclose<CR>
nnoremap <Leader>ff :PickerEdit<CR>
nnoremap <Leader>fg :PickerEdit<CR>
nnoremap <Leader>fb :PickerBuffer<CR>
nnoremap <Leader>tb :TagbarToggle<CR>

nnoremap ]e :lnext<CR>
nnoremap [e :lprevious<CR>

" Some mappings for Unicode chars
inoremap <Leader>,, ,
inoremap <Leader>... …
inoremap <Leader>- –
inoremap <Leader>-- —
inoremap <Leader>al α
inoremap <Leader>Al Α
inoremap <Leader>be β
inoremap <Leader>Be Β
inoremap <Leader>ga γ
inoremap <Leader>Ga Γ
inoremap <Leader>de δ
inoremap <Leader>De Δ
inoremap <Leader>ep ε
inoremap <Leader>Ep Ε
inoremap <Leader>la λ
inoremap <Leader>La Λ
inoremap <Leader>pi π
inoremap <Leader>Pi Π
inoremap <Leader>si σ
inoremap <Leader>Si Σ
inoremap <Leader>th θ
inoremap <Leader>Th Θ
inoremap <Leader>om ω
inoremap <Leader>Om Ω
inoremap <Leader>qA ∀
inoremap <Leader>qE ∃
inoremap <Leader>~= ≈
inoremap <Leader><= ≤
inoremap <Leader>>= ≥
inoremap <Leader>1/2 ½
inoremap <Leader>1/3 ⅓
inoremap <Leader>1/4 ¼
inoremap <Leader>1/5 ⅕
inoremap <Leader>1/8 ⅛
inoremap <Leader>2/3 ⅔
inoremap <Leader>2/5 ⅖
inoremap <Leader>3/4 ¾
inoremap <Leader>3/5 ⅗
inoremap <Leader>3/8 ⅜
inoremap <Leader>4/5 ⅘
inoremap <Leader>5/8 ⅝
inoremap <Leader>7/8 ⅞
inoremap <Leader>2r √
inoremap <Leader>3r ∛
inoremap <Leader>4r ∜
inoremap <Leader>p ʹ
inoremap <leader>pp ʺ
inoremap <Leader>**0 ⁰
inoremap <Leader>**1 ¹
inoremap <Leader>**2 ²
inoremap <Leader>**3 ³
inoremap <Leader>**4 ⁴
inoremap <Leader>**i ⁱ
inoremap <Leader>**n ⁿ
inoremap <Leader>_0 ₀
inoremap <Leader>_1 ₁
inoremap <Leader>_2 ₂
inoremap <Leader>_3 ₃
inoremap <Leader>_4 ₄
inoremap <Leader>_n ₙ
inoremap <Leader>_p ₚ
inoremap <Leader>/ ÷
inoremap <Leader>* ×
inoremap <Leader>+- ±
inoremap <Leader>o °
inoremap <Leader>m µ
inoremap <Leader>inf ∞
inoremap <Leader>(c) ©
inoremap <Leader>(r) ®
inoremap <Leader>TM ™
inoremap <Leader>est ℮
inoremap <Leader>co ℅
inoremap <Leader>-> →
inoremap <Leader>-< ←
inoremap <Leader>-^ ↑
inoremap <Leader>-v ↓
inoremap <Leader>=> ⇒
inoremap <Leader>=< ⇐
inoremap <Leader>=^ ⇑
inoremap <Leader>=v ⇓
inoremap <Leader>HT ⇥
inoremap <Leader>CR ↵
inoremap <Leader>LF ↴
inoremap <Leader>FF ↡
inoremap <Leader>BS ⌫
inoremap <Leader>SHIFT ⇧
inoremap <Leader>CAPS ⇬
inoremap <Leader>NUM ⇭
inoremap <Leader>SP  
inoremap <Leader>tick ✓
inoremap <Leader>cross ✗

inoremap <Leader>h ─
inoremap <Leader>v │
inoremap <Leader>tl ┌
inoremap <Leader>tr ┐
inoremap <Leader>bl └
inoremap <Leader>br ┘
inoremap <Leader>rm ┤
inoremap <Leader>lm ├
inoremap <Leader>bm ┴
inoremap <Leader>tm ┬
inoremap <Leader>mm ┼
inoremap <Leader>df ╱
inoremap <Leader>db ╲
inoremap <Leader>dx ╳

inoremap <Leader>a> ▸
inoremap <Leader>a< ◂
inoremap <Leader>a^ ▴
inoremap <Leader>av ▾

command DiffSwap vert new | set bt=nofile | r # | 0d_ | diffthis | wincmd p | diffthis
