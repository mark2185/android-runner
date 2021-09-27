let s:android_properties = #{
        \ SDK          : 'ro.build.version.sdk'    ,
        \ version      : 'ro.build.version.release',
        \ brand        : 'ro.product.brand'        ,
        \ model        : 'ro.product.model'        ,
        \ manufacturer : 'ro.product.manufacturer' ,
        \ country      : 'persist.sys.country'     ,
        \ language     : 'persist.sys.language'    ,
        \ timezone     : 'persist.sys.timezone'    ,
        \ abi          : 'ro.product.cpu.abi',
      \}

" Returns device property as string
function! s:getProperty( device, property ) abort
    let l:cmd = s:createAdbCmd( [ 'shell', 'getprop', a:property ], a:device )
    return systemlist( l:cmd->join() )->join()
endfunction

" Returns device info as dictionary
function! s:getDeviceInfo( device, properties = [ 'sdk', 'version', 'model' ] ) abort
    let l:result = #{ device : a:device }
    for property in a:properties
        if has_key( s:android_properties, property )
            let l:result[ property ] = s:getProperty( a:device, s:android_properties[ property ] )
        endif
    endfor
    return l:result
endfunction

function! s:isDeviceValid( target_device = g:android_target_device ) abort
    return !empty( a:target_device )
            \ && index( adb#devices(['device'])->map('v:val["device"]'), a:target_device ) != -1
endfunction

function! s:createAdbCmd( cmd, device = g:android_target_device ) abort
    let l:cmd = [
            \ g:adb_bin,
            \ '-s',
            \ a:device
        \]
    return l:cmd + a:cmd
endfunction

function! adb#getPid( app_name = g:app_pkg . '.' . g:android_target_app ) abort
    if !s:isDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    let l:cmd = [
        \ 'shell',
        \ 'pidof',
        \ a:app_name ]

    let l:output = systemlist( s:createAdbCmd( l:cmd )->join()  )
    return get( l:output, 0, -1 )
endfunction

function! adb#setAndroidProjectRoot( path ) abort
    if !isdirectory( a:path )
        echom "This is not a valid directory!"
        return
    endif

    let g:android_project_root = a:path
    let g:gradle_project_root = g:android_project_root
    let g:gradle_bin          = g:gradle_project_root . '/gradlew'
endfunction

" let g:android_target_device = ''
" let g:android_target_app = ''
" if len(adb#completeDevices()) == 1
"     let g:android_target_device = adb#completeDevices()[0]
" endif

function! adb#completeDevices(...) abort
    return adb#devices( [ 'brand', 'model' ] )->map( 'printf("%s - %s", v:val["device"], v:val["model"])' )
endfunction

function! adb#SelectDevice( ... ) abort
    if !a:0
        echom 'Current target device: ' . ( empty( g:android_target_device ) ? 'none' : g:android_target_device )
    else
        let g:android_target_device = a:1->split('-')[0]->trim()
    endif
    " TODO: inputlist() ?
endfunction

let s:build_type_name = 'distribute'

let g:app_pkg = 'com.microblink.exerunner'

function! adb#setAppPkg( app_pkg ) abort
    let g:app_pkg = a:app_pkg
endfunction

function! adb#completeBuildType(...) abort
    return ['debug', 'release', 'distribute']
endfunction

function! adb#SelectBuildType( build_type ) abort
    let s:build_type_name = a:build_type
endfunction

function! adb#push(
    \ src = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, s:build_type_name, s:build_type_name ),
    \ dst = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ),
    \ async = v:true ) abort
    if !s:isDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    if empty( g:android_project_root )
        echom "Android project root is empty!"
        " TODO: ask to user if they want to 
        " set it based on gradle_bin
        return
    endif

    let l:cmd = s:createAdbCmd( [ 'push', a:src, a:dst ] ) 
    echom "Running: " . string(l:cmd)
    if a:async
        call job#run( l:cmd )
    else
        echom systemlist( l:cmd->join() )->join("\n")
    endif
endfunction

"grant_permissions_message = '-g: grant all runtime permissions'
function! adb#installApp( src = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ) ) abort
    if !s:isDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    call job#run( s:createAdbCmd( [ 'shell', 'pm', 'install', '-t', '-r', a:src ] ) )
    " return systemlist( l:cmd )->join()
endfunction

" let s:package_path = 'com.microblink.exerunner'
" let s:activity_class = 'com.microblink.exerunner.RunActivity'

" benchmark_app_pkg = 'com.microblink.exerunner.' . 'application_build.application_name'
" activity_class = 'com.microblink.exerunner.RunActivity'
function! adb#startApp( app_name = g:android_target_app, package_path = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity' ) abort
    if !s:isDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    let l:cmd = s:createAdbCmd( [
        \ 'shell',
        \ 'am',
        \ 'start',
        \ '-n',
        \ a:package_path . '.' . a:app_name . '/' . a:activity_class,
        \ '-a',
        \ 'android.intent.action.MAIN',
        \ '-c',
        \ 'android.intent.category.LAUNCHER'
        \ ] )
    call job#run( l:cmd )
    " return systemlist( l:cmd )->join()
endfunction

function! adb#startAppDebug( app_name = g:android_target_app, package_path = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity' ) abort
    if !s:isDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    let l:cmd = s:createAdbCmd( [
        \ 'shell',
        \ 'am',
        \ 'start',
        \ '-D',
        \ a:package_path . '.' . a:app_name . '/' . a:activity_class,
        \ '-a',
        \ 'android.intent.action.MAIN',
        \ '-c',
        \ 'android.intent.category.LAUNCHER'
        \ ] )
    call job#run( l:cmd )
    " return systemlist( l:cmd )->join()
endfunction

function! adb#clearLogcat( app_name = g:app_pkg . '.' . g:android_target_app ) abort
    if !s:isDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    call system( s:createAdbCmd( [ 'logcat', '-c', '--pid', adb#getPid( a:app_name ) ] )->join() )
    echom "Logcat cleared!"
endfunction

function! adb#getPidcatOutput( app_name = g:android_target_app )
endfunction

function! adb#getLogcatOutput( app_name = 'com.microblink.exerunner' . g:android_target_app ) abort
    if !s:isDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    call job#run( s:createAdbCmd( [ 'logcat', '--pid', adb#getPid( a:app_name ) ] ) )
endfunction

function! adb#getPidcatOutput( app_name = 'com.microblink.exerunner.' . g:android_target_app ) abort
    if !s:isDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    call job#run( ['pidcat', a:app_name] )
endfunction

function! adb#killServer() abort
    call job#run( g:adb_bin . ' kill-server' )
endfunction

function! adb#devices( properties = [] ) abort
  let l:adb_output = systemlist( g:adb_bin . ' devices' )->filter( '!empty( v:val )' )
  let l:adb_devices = []

  for l:adb_device in l:adb_output
              \->map( 'v:val->matchstr(''\v^(.+)\s+device$'')' )
              \->filter( '!empty(v:val)' )
              \->map( 'v:val->split()[0]' )
              \->map( 'v:val->trim()' )
      let l:info = s:getDeviceInfo( l:adb_device, empty( a:properties ) ? v:none : a:properties )
      call add(l:adb_devices, l:info)
  endfor

  return l:adb_devices
endfunction

function! adb#shazam( app_name = g:android_target_app, package_path = 'com.microblink.exerunner', activity_class = 'RunActivity'  ) abort
    if !s:isDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    if empty( g:android_project_root )
        echom "Android project root is empty!"
        return
    endif

    " push
    let l:src = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, s:build_type_name, s:build_type_name )
    let l:dst = '/data/local/tmp/' . g:app_pkg . '.' . a:app_name

    echom systemlist( s:createAdbCmd( [ 'push', l:src, l:dst ] )->join() )->join("\n")

    if v:shell_error | echom "Shell returned error!" | return | endif

    " install
    let l:app = '/data/local/tmp/' . g:app_pkg . '.' . a:app_name

    echom systemlist( s:createAdbCmd(['shell', 'pm', 'install', '-t', '-r', l:app ])->join() )->join("\n")

    if v:shell_error | echom "Shell returned error!" | return | endif

    sleep 2
    
    " start
    let l:app = a:package_path . '.' . a:app_name . '/' . a:package_path . '.' . a:activity_class

    echom systemlist( s:createAdbCmd([ 'shell', 'am', 'start', '-n', l:app, '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER'])->join() )->join("\n")

    if v:shell_error | echom "Shell returned error!" | return | endif

    sleep 2

    call adb#getLogcatOutput( a:package_path . '.' . a:app_name )
endfunction

 " profile start [--user <USER_ID> current]
 "         [--sampling INTERVAL | --streaming] <PROCESS> <FILE>
 "     Start profiler on a process.  The given <PROCESS> argument
 "       may be either a process name or pid.  Options are:
 "     --user <USER_ID> | current: When supplying a process name,
 "         specify user of process to profile; uses current user if not
 "         specified.
 "     --sampling INTERVAL: use sample profiling with INTERVAL microseconds
 "         between samples.
 "     --streaming: stream the profiling output to the specified file.
 " profile stop [--user <USER_ID> current] <PROCESS>
 "     Stop profiler on a process.  The given <PROCESS> argument
 "       may be either a process name or pid.  Options are:
 "     --user <USER_ID> | current: When supplying a process name,
 "         specify user of process to profile; uses current user if not
 "         specified.
function! adb#profileStart( target_device = g:android_target_device ) abort
    if !s:isDeviceValid( a:target_device ) abort
        echom printf( "Device '%s' not found!", a:target_device )
        return 
    endif
endfunction

let s:lldb_port = 0

function! adb#getLLDBport() abort
    return s:lldb_port
endfunction

function! adb#startLLDB( target_device = g:android_target_device ) abort
    if !s:isDeviceValid( a:target_device )
        echom printf( "Device '%s' not found!", a:target_device )
        return 
    endif

    "TODO: get it from ANDROID_SDK and getprop cpu.abi
    if empty( g:android_lldb_server_bin ) || !executable( g:android_lldb_server_bin )
        echom printf( "Binary '%s' not found or not executable!", g:android_lldb_server_bin )
        return 
    endif

    call adb#push( g:android_lldb_server_bin, '/data/local/tmp/lldb-server', v:false )

    if v:shell_error | echom "Shell error!" | return | endif
    let l:cmd = [
        \ 'shell',
        \ 'run-as',
        \ g:app_pkg . '.' . g:android_target_app,
        \ 'cp',
        \ '/data/local/tmp/lldb-server',
        \ '.'
    \]
    " /data/data/' . g:app_pkg . '.' . g:android_target_app

    echom "Running: " . string(l:cmd)
    call adb#run( l:cmd->join(), v:false )

    if v:shell_error | echom "Shell error!" | return | endif
    let l:cmd = [
        \'shell',
        \'run-as',
        \ g:app_pkg . '.' . g:android_target_app,
        \ './lldb-server',
        \ 'platform',
        \ 'server',
        \ '--listen "*:54321"',
        \ '&' ]

    echom "Running: " . string(l:cmd)
    call adb#run( l:cmd->join(), v:false )
    sleep 2
    if v:shell_error | echom "Shell error!" | return | endif

    " TODO: run `adb forward tcp:54321 tcp:54321`
    " TODO: run `adb forward tcp:54321 jdwp:<pid>`
    " TODO: run `jdb -attach localhost:54321
endfunction

function! adb#stopLLDB( target_device = g:android_target_device ) abort
    let l:cmd = [
        \'shell',
        \'run-as',
        \ g:app_pkg . '.' . g:android_target_app,
        \ 'pkill',
        \ 'lldb-server' ]

    call adb#run( l:cmd->join() )
    sleep 2
    if v:shell_error | echom "Shell error!" | return | endif
endfunction

function! adb#shell( target_device = g:android_target_device ) abort
    if !s:isDeviceValid( a:target_device )
        echom printf( "Device '%s' not found!", a:target_device )
        return 
    endif
    execute printf( 'bo term ++close %s -s %s shell', g:adb_bin, a:target_device )
endfunction

function! adb#run( cmd, async = v:true ) abort
    if !executable( g:adb_bin )
        echom printf( 'adb binary %s is not found.', g:adb_bin )
    endif

    let l:cmd = [ g:adb_bin ] + a:cmd->split() 

    if a:async
        call job#run( [ g:adb_bin ] + a:cmd->split() )
    else
        echom systemlist( l:cmd->join() )->join("\n")
    endif
endfunction
