let s:android_buf = 'android_execute'
let s:android_job = {}

function! s:createQuickFix() abort
    " just to be sure all messages were processed
    sleep 100m
    let l:bufnr = bufnr(s:android_buf)
    if l:bufnr == -1
        return
    endif

    silent execute 'cgetbuffer ' . l:bufnr
    silent call setqflist( [], 'a', { 'title' : s:android_job[ 'cmd' ] } )

    " Remove android job
    let s:android_job = {}
    call s:closeBuffer()
endfunction

function! s:closeBuffer() abort
    let l:bufnr = bufnr(s:android_buf)
    if l:bufnr == -1
        return
    endif

    let l:winnr = bufwinnr(l:bufnr)
    if l:winnr != -1
        exec l:winnr.'wincmd c'
    endif

    silent exec 'bwipeout ' . l:bufnr
endfunction

function! job#stop() abort
    if empty(s:android_job)
        call s:closeBuffer()
        return
    endif
    let l:job = s:android_job['job']
    call job_stop(l:job)
    call s:createQuickFix()
    copen
    echom 'Job is cancelled!'
endfunction

function! job#clearBuffer() abort
    call setbufvar( bufnr( s:android_buf ), "&modifiable", 1 )
    %delete _
    call setbufvar( bufnr( s:android_buf ), "&modifiable", 0 )
endfunction

function! s:createJobBuf() abort
    call s:closeBuffer()
    silent execute 'keepalt below 10split ' . s:android_buf

    setlocal bufhidden=hide buftype=nofile buflisted nolist
    setlocal noswapfile nowrap nomodifiable

    nmap <buffer> <C-c> :call job#stop()<CR>
    nmap <buffer> <leader>c :call job#clearBuffer()<CR>

    return bufnr(s:android_buf)
endfunction

function! s:vimClose(channel) abort
    let l:ret_code = job_info(s:android_job['job'])['exitval']
    if l:ret_code == 0
        echon "Success!\n" . s:android_job['cmd']
    else
        echon "Failure!\n" . s:android_job['cmd']
    endif

    call s:createQuickFix()
    silent copen
endfunction

function! job#run( cmd ) abort
    silent cclose
    let l:outbufnr = s:createJobBuf()
    let s:android_job[ 'cmd' ] = type( a:cmd ) == v:t_list ? a:cmd->join() : a:cmd
    let l:job = job_start( a:cmd, {
                \ 'close_cb': function( 's:vimClose' ),
                \ 'out_io' : 'buffer', 'out_buf' : l:outbufnr,
                \ 'err_io' : 'buffer', 'err_buf' : l:outbufnr,
                \ 'out_modifiable' : 0,
                \ 'err_modifiable' : 0,
                \ } )

   let s:android_job['job'] = l:job
    if !has('nvim')
       let s:android_job['channel'] = job_getchannel(l:job)
    endif
endfunction
