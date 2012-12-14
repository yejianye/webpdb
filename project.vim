if filereadable("session.vim")
	source session.vim
endif
autocmd CursorHold,CursorHoldI * mksession! session.vim
set wildignore+=*.js,*.pyc
"set tags=~/Documents/idoocard/idoosrv/**/tags
"let g:ctrlp_custom_ignore = {'dir': 'idoosrv/mongodb/data'}
