vim9script

const job_bufname = 'android_execute'

var android_job = {}
var job_bufid   = -1
var job_queue: list< list< string > > = []

def CreateJobBuffer(): number
    if job_bufid != -1
        throw "Buffer already exists!"
    endif

    job_bufid = bufadd( job_bufname )
    setbufvar( job_bufid, "&buftype", 'nofile' )
    setbufvar( job_bufid, "&modifiable", 0 )
    setbufvar( job_bufid, "&hidden",     0 )
    setbufvar( job_bufid, "&swapfile",   0 )
    setbufvar( job_bufid, "&wrap",       0 )
    setbufvar( job_bufid, "&modifiable", 0 )

    bufload( job_bufname )

    silent exec 'keepalt botright split ' .. job_bufname

    nmap <buffer> <C-c> :call job#stop()<CR>
    nmap <buffer> <C-r> :call job#clearBuffer( job_bufid )<CR>

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
    silent setqflist( [], 'a', { 'title': android_job[ 'cmd' ]->join() } )
enddef

def EvalCmd( cmd: list< string > ): list< string >
    for i in range( len( cmd ) )
        if cmd[ i ] =~# '%PID%'
            const pid = string(adb#getPid())
            cmd[ i ] = substitute( cmd[ i ], '%PID%', pid, '' )
            echom "PID is " .. pid
            g:android_target_app_pid = str2nr(pid)
        endif
    endfor
    return cmd
enddef

def StartJob( cmd: list< string >, buffer_id: number = job_bufid ): void
    android_job = {
        cmd: cmd,
        job: job_start( EvalCmd(cmd), {
           close_cb: function( 's:CloseCallback' ),
           out_io: 'buffer', out_buf: buffer_id, out_modifiable: 0,
           err_io: 'buffer', err_buf: buffer_id, err_modifiable: 0
        } )
    }
enddef

def CloseCallback( channel: channel ): void
    if empty( android_job ) || !has_key( android_job, 'job')
        return
    endif

    const exitval = job_info( s:android_job[ 'job' ] )[ 'exitval' ]
    echon android_job[ 'cmd' ]->join() .. "\n"
    if exitval == 0
        if len( job_queue ) >= 1
            echom "Callback: exitval 0, remaining jobs: " .. len( job_queue )
            var job = remove( job_queue, 0 )
            StartJob( job )
            return
        endif
    else
        echon 'Failure!'
        job#clearQueue()
    endif

    CreateQuickFix()
    CloseJobBuffer()

    # Remove android job
    android_job = {}

    cwindow
enddef

def job#stop(): void
    if empty( android_job )
        # for fixing an undesired state in which there is no job running,
        # but a buffer still exists
        CloseJobBuffer()
        return
    endif

    android_job[ 'job' ]->job_stop()

    echom 'Job is cancelled!'
enddef

def job#clearBuffer( buffer_id: number ): void
    setbufvar( buffer_id, "&modifiable", 1 )
    exe ":%delete _"
    setbufvar( buffer_id, "&modifiable", 0 )
enddef

def job#run( cmd: list< string > ): void
    if job_bufid != -1
        echom 'Job already running!'
        return
    endif

    cclose

    call CloseJobBuffer()
    const buffer_id = CreateJobBuffer()

    StartJob( cmd, buffer_id )
enddef

def job#processQueue(): void
    if len( job_queue ) == 0
        echom 'Job queue empty!'
        return
    endif

    var job = remove( job_queue, 0 )
    echom "Processing queue, remaining jobs: " .. len( job_queue )
    job#run( job )
enddef

def job#addToQueue( cmd: list< string >): void
    add( job_queue, cmd )
enddef

def job#clearQueue(): void
    echom "Cleaning queue! Dropping " .. len( job_queue ) .. " jobs!"
    job_queue = []
enddef

defcompile
