let g:gradle_project_root = systemlist( 'dirname ' . g:gradle_bin )[0]

" TODO: cannot process --console plain for some reason
function! s:createGradleCmd(cmd) abort
    let l:cmd = [
            \ g:gradle_bin,
            \ '-p',
            \ g:gradle_project_root,
            \ a:cmd
        \]
    return l:cmd
endfunction

"if it starts with [a-z], it's a task
function! gradle#getTasks( arglead, cmdline, cursor_pos ) abort
    let l:output = systemlist( s:createGradleCmd( ' :app:tasks' )->join() )
    let l:output = l:output
                \->filter('!empty(v:val)')
    " echom 'New: ' . string(l:output)
    let l:output = l:output
                \->filter('v:val =~# "^[a-z]"')
                \->map('v:val->split("-")[0]->trim()')
                \->map('":app:" . v:val')

    " echom 'New: ' . string(l:output[0])
    " if a:arglead !~# l:output[0]
    "     echom "Match!"
    " endif

    " echom "a:arglead " . a:arglead
    let l:output = l:output
                \->filter("a:arglead !~# v:val")
    return l:output
endfunction

function! gradle#run( cmd ) abort
    if !executable( g:gradle_bin )
        echom printf('Gradle binary %s is not found.', g:gradle_bin )
    endif

    call job#run( s:createGradleCmd( a:cmd ) )
endfunction
