vim9script

const job_bufname = 'android_execute'

var android_job = {}
var job_bufid   = -1

def CreateJobBuffer(): number
    if job_bufid != -1
        throw "Buffer already exists!"
    endif

    job_bufid = bufadd( job_bufname )
    call setbufvar( job_bufid, "&buftype", 'nofile' )
    call setbufvar( job_bufid, "&modifiable", 0 )
    call setbufvar( job_bufid, "&hidden",     0 )
    call setbufvar( job_bufid, "&swapfile",   0 )
    call setbufvar( job_bufid, "&wrap",       0 )
    call setbufvar( job_bufid, "&modifiable", 0 )

    call bufload( job_bufname )

    silent exec 'keepalt below split ' .. job_bufname

    nmap <buffer> <C-c> :call job#stop()<CR>
    nmap <buffer> <C-r> :call job#clearBuffer()<CR>

    return job_bufid
enddef

def CloseJobBuffer(): void
    if job_bufid == -1
        return
    endif

    exec 'bwipeout ' .. job_bufid
    job_bufid = -1
enddef

def CreateQuickFix(): void
    if job_bufid == -1
        return
    endif

    # just to be sure all messages were processed
    sleep 100m

    execute 'cgetbuffer ' .. job_bufid
    silent call setqflist( [], 'a', { 'title': android_job[ 'cmd' ]->join() } )
enddef

def CloseCallback( channel: channel ): void
    if !has_key( android_job, 'job') 
        return
    endif

    echon ( job_info( s:android_job[ 'job' ] )[ 'exitval' ] != 0 ) ? "Failure!" : "Success!"
    echon "\n" .. android_job[ 'cmd' ]->join()

    call CreateQuickFix()
    call CloseJobBuffer()

    # Remove android job
    android_job = {}

    copen
enddef

def job#stop(): void
    if empty( android_job )
        # for fixing an undesired state in which there is no job running,
        # but a buffer still exists
        call CloseJobBuffer()
        return
    endif

    android_job[ 'job' ]->job_stop()

    echom 'Job is cancelled!'
enddef

def job#clearBuffer(): void
    call setbufvar( job_bufid, "&modifiable", 1 )
    exe ":%delete _"
    call setbufvar( job_bufid, "&modifiable", 0 )
enddef

def job#run( cmd: list< string > ): void
    if job_bufid != -1
        echom 'Job already running!'
    endif

    cclose

    call CloseJobBuffer()
    const buffer_id = CreateJobBuffer()

    android_job = {
        cmd: cmd,
        job: job_start( cmd, {
           close_cb: function( 's:CloseCallback' ),
           out_io: 'buffer', out_buf: buffer_id, out_modifiable: 0,
           err_io: 'buffer', err_buf: buffer_id, err_modifiable: 0
        } )
    }
enddef

defcompile
