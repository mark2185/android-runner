vim9script

const android_properties = {
    SDK:          'ro.build.version.sdk',
    version:      'ro.build.version.release',
    brand:        'ro.product.brand',
    model:        'ro.product.model',
    manufacturer: 'ro.product.manufacturer',
    country:      'persist.sys.country',
    language:     'persist.sys.language',
    timezone:     'persist.sys.timezone',
    abi:          'ro.product.cpu.abi',
}

# TODO: remove string after transition to vim9
def CreateAdbCmd( cmd: list< string >, device: string = string( g:android_target_device ) ): list< string >
    return [
        g:adb_bin,
        '-s',
        device
    ] + cmd
enddef

# TODO: remove string after transition to vim9
def GetProperty( property: string, device: string = string( g:android_target_device ) ): string
    return CreateAdbCmd( [ 'shell', 'getprop', property ], device )
           ->join()
           ->systemlist()
           ->join()
enddef

# TODO: remove string after transition to vim9
# Returns device info as dictionary
def GetDeviceInfo( properties: list< string > = [ 'sdk', 'version', 'model' ], device: string = string( g:android_target_device ) ): dict< string >
    var result = { device: device }
    for property in properties
        if has_key( android_properties, property )
            result[ property ] = GetProperty( android_properties[ property ], device )
        endif
    endfor
    return result
enddef

def adb#devices( properties: list< string > = [] ): any
  return systemlist( g:adb_bin .. ' devices' )
         ->filter( '!empty( v:val )' )
         ->map( 'v:val->matchstr(''\v^(.+)\s+device$'')' )
         ->filter( '!empty(v:val)' )
         ->map( 'v:val->split()[0]' )
         ->map( 'v:val->trim()' )
         ->map( (_, v) => GetDeviceInfo( v, properties->empty() ? v:none : properties ) )
enddef

def IsDeviceValid( target_device: string = string( g:android_target_device ) ): bool
    return !empty( target_device )
           && index( adb#devices(['device'])
                     ->map('v:val["device"]'),
                     target_device ) != -1
enddef

def adb#getPid( app_name: string = string( g:app_pkg .. '.' .. g:android_target_app ) ): number
    if !IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return -1
    endif

    const cmd = [
        'shell',
        'pidof',
        app_name
    ]

    return CreateAdbCmd( cmd )
           ->join()
           ->systemlist()
           ->get( 0, -1 )
enddef

def adb#installApp( src = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ) ): void
    if IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    call job#run( CreateAdbCmd( [ 'shell', 'pm', 'install', '-t', '-r', src ] ) )
enddef

var build_type_name = 'debug'

def adb#push(
      src: string = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name ),
      dst: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ),
      async: bool = v:true ): void

    if IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return
    endif

    if empty( g:android_project_root )
        echom "Android project root is empty!"
        # TODO: ask to user if they want to 
        # set it based on gradle_bin
        return
    endif

    echom CreateAdbCmd( [ 'push', src, dst ] )
        ->join()
        ->systemlist()
        ->join("\n")
enddef

def adb#pushAsync(
      src: string = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name ),
      dst: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ),
      async: bool = v:true ): void

    if IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return
    endif

    if empty( g:android_project_root )
        echom "Android project root is empty!"
        # TODO: ask to user if they want to 
        # set it based on gradle_bin
        return
    endif

    call job#run( CreateAdbCmd( [ 'push', src, dst ] ) )
enddef
#
#function! adb#setAndroidProjectRoot( path ) abort
#    if !isdirectory( a:path )
#        echom "This is not a valid directory!"
#        return
#    endif
#
#    let g:android_project_root = a:path
#    let g:gradle_project_root = g:android_project_root
#    let g:gradle_bin          = g:gradle_project_root . '/gradlew'
#endfunction
#
#" let g:android_target_device = ''
#" let g:android_target_app = ''
#" if len(adb#completeDevices()) == 1
#"     let g:android_target_device = adb#completeDevices()[0]
#" endif
#
#function! adb#completeDevices(...) abort
#    return adb#devices( [ 'brand', 'model' ] )->map( 'printf("%s - %s", v:val["device"], v:val["model"])' )
#endfunction
#
def adb#SelectDevice( ...device: list< string > ): void
    if empty( device )
        echom 'Current target device: ' .. ( empty( g:android_target_device ) ? 'none' : g:android_target_device )
    else
        g:android_target_device = device[ 0 ]
    endif
    # TODO: inputlist() ?
enddef
#
#let s:build_type_name = 'distribute'
#
#let g:app_pkg = 'com.microblink.exerunner'
#
#function! adb#setAppPkg( app_pkg ) abort
#    let g:app_pkg = a:app_pkg
#endfunction
#
#function! adb#completeBuildType(...) abort
#    return ['debug', 'release', 'distribute']
#endfunction
#
#function! adb#SelectBuildType( build_type ) abort
#    let s:build_type_name = a:build_type
#endfunction
#
#
#"grant_permissions_message = '-g: grant all runtime permissions'
#
#" let s:package_path = 'com.microblink.exerunner'
#" let s:activity_class = 'com.microblink.exerunner.RunActivity'
#
#" benchmark_app_pkg = 'com.microblink.exerunner.' . 'application_build.application_name'
#" activity_class = 'com.microblink.exerunner.RunActivity'
def adb#startApp( app_name: string = string(g:android_target_app ), package_path = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity' ): void
    if IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    call job#run( CreateAdbCmd( [
        'shell',
        'am',
        'start',
        '-n',
        package_path .. '.' .. app_name .. '/' .. activity_class,
        '-a',
        'android.intent.action.MAIN',
        '-c',
        'android.intent.category.LAUNCHER'
        ] ) )
enddef
#
#function! adb#startAppDebug( app_name = g:android_target_app, package_path = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity' ) abort
#    if !s:isDeviceValid()
#        echom printf( "Device '%s' not found!", g:android_target_device )
#        return 
#    endif
#
#    let l:cmd = s:createAdbCmd( [
#        \ 'shell',
#        \ 'am',
#        \ 'start',
#        \ '-D',
#        \ a:package_path . '.' . a:app_name . '/' . a:activity_class,
#        \ '-a',
#        \ 'android.intent.action.MAIN',
#        \ '-c',
#        \ 'android.intent.category.LAUNCHER'
#        \ ] )
#    call job#run( l:cmd )
#    " return systemlist( l:cmd )->join()
#endfunction
#
#function! adb#clearLogcat( app_name = g:app_pkg . '.' . g:android_target_app ) abort
#    if !s:isDeviceValid()
#        echom printf( "Device '%s' not found!", g:android_target_device )
#        return 
#    endif
#
#    call system( s:createAdbCmd( [ 'logcat', '-c', '--pid', adb#getPid( a:app_name ) ] )->join() )
#    echom "Logcat cleared!"
#endfunction
#
#function! adb#getPidcatOutput( app_name = g:android_target_app )
#endfunction
#
def adb#getLogcatOutput( app_name: string = 'com.microblink.exerunner.' .. g:android_target_app ): void
    if IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    if adb#getPid( app_name ) == -1
        echom printf( "%s is not running!", app_name )
        return
    endif

    call job#run( CreateAdbCmd( [ 'logcat', '--pid', adb#getPid( app_name ) ] ) )
enddef
#
#function! adb#getPidcatOutput( app_name = 'com.microblink.exerunner.' . g:android_target_app ) abort
#    if !s:isDeviceValid()
#        echom printf( "Device '%s' not found!", g:android_target_device )
#        return 
#    endif
#
#    call job#run( ['pidcat', a:app_name] )
#endfunction
#
#function! adb#killServer() abort
#    call job#run( g:adb_bin . ' kill-server' )
#endfunction
#
#
#function! adb#shazam( app_name = g:android_target_app, package_path = 'com.microblink.exerunner', activity_class = 'RunActivity'  ) abort
#    if !s:isDeviceValid()
#        echom printf( "Device '%s' not found!", g:android_target_device )
#        return 
#    endif
#
#    if empty( g:android_project_root )
#        echom "Android project root is empty!"
#        return
#    endif
#
#    " push
#    let l:src = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, s:build_type_name, s:build_type_name )
#    let l:dst = '/data/local/tmp/' . g:app_pkg . '.' . a:app_name
#
#    echom systemlist( s:createAdbCmd( [ 'push', l:src, l:dst ] )->join() )->join("\n")
#
#    if v:shell_error | echom "Shell returned error!" | return | endif
#
#    " install
#    let l:app = '/data/local/tmp/' . g:app_pkg . '.' . a:app_name
#
#    echom systemlist( s:createAdbCmd(['shell', 'pm', 'install', '-t', '-r', l:app ])->join() )->join("\n")
#
#    if v:shell_error | echom "Shell returned error!" | return | endif
#
#    sleep 2
#    
#    " start
#    let l:app = a:package_path . '.' . a:app_name . '/' . a:package_path . '.' . a:activity_class
#
#    echom systemlist( s:createAdbCmd([ 'shell', 'am', 'start', '-n', l:app, '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER'])->join() )->join("\n")
#
#    if v:shell_error | echom "Shell returned error!" | return | endif
#
#    sleep 2
#
#    call adb#getLogcatOutput( a:package_path . '.' . a:app_name )
#endfunction
#
# " profile start [--user <USER_ID> current]
# "         [--sampling INTERVAL | --streaming] <PROCESS> <FILE>
# "     Start profiler on a process.  The given <PROCESS> argument
# "       may be either a process name or pid.  Options are:
# "     --user <USER_ID> | current: When supplying a process name,
# "         specify user of process to profile; uses current user if not
# "         specified.
# "     --sampling INTERVAL: use sample profiling with INTERVAL microseconds
# "         between samples.
# "     --streaming: stream the profiling output to the specified file.
# " profile stop [--user <USER_ID> current] <PROCESS>
# "     Stop profiler on a process.  The given <PROCESS> argument
# "       may be either a process name or pid.  Options are:
# "     --user <USER_ID> | current: When supplying a process name,
# "         specify user of process to profile; uses current user if not
# "         specified.
#function! adb#profileStart( target_device = g:android_target_device ) abort
#    if !s:isDeviceValid( a:target_device ) abort
#        echom printf( "Device '%s' not found!", a:target_device )
#        return 
#    endif
#endfunction
#
#let s:lldb_port = 0
#
#function! adb#getLLDBport() abort
#    return s:lldb_port
#endfunction
#
#function! adb#startLLDB( target_device = g:android_target_device ) abort
#    if !s:isDeviceValid( a:target_device )
#        echom printf( "Device '%s' not found!", a:target_device )
#        return 
#    endif
#
#    "TODO: get it from ANDROID_SDK and getprop cpu.abi
#    if empty( g:android_lldb_server_bin ) || !executable( g:android_lldb_server_bin )
#        echom printf( "Binary '%s' not found or not executable!", g:android_lldb_server_bin )
#        return 
#    endif
#
#    call adb#push( g:android_lldb_server_bin, '/data/local/tmp/lldb-server', v:false )
#
#    if v:shell_error | echom "Shell error!" | return | endif
#    let l:cmd = [
#        \ 'shell',
#        \ 'run-as',
#        \ g:app_pkg . '.' . g:android_target_app,
#        \ 'cp',
#        \ '/data/local/tmp/lldb-server',
#        \ '.'
#    \]
#    " /data/data/' . g:app_pkg . '.' . g:android_target_app
#
#    echom "Running: " . string(l:cmd)
#    call adb#run( l:cmd->join(), v:false )
#
#    if v:shell_error | echom "Shell error!" | return | endif
#    let l:cmd = [
#        \'shell',
#        \'run-as',
#        \ g:app_pkg . '.' . g:android_target_app,
#        \ './lldb-server',
#        \ 'platform',
#        \ 'server',
#        \ '--listen "*:54321"',
#        \ '&' ]
#
#    echom "Running: " . string(l:cmd)
#    call adb#run( l:cmd->join(), v:false )
#    sleep 2
#    if v:shell_error | echom "Shell error!" | return | endif
#
#    " TODO: run `adb forward tcp:54321 tcp:54321`
#    " TODO: run `adb forward tcp:54321 jdwp:<pid>`
#    " TODO: run `jdb -attach localhost:54321
#endfunction
#
#function! adb#stopLLDB( target_device = g:android_target_device ) abort
#    let l:cmd = [
#        \'shell',
#        \'run-as',
#        \ g:app_pkg . '.' . g:android_target_app,
#        \ 'pkill',
#        \ 'lldb-server' ]
#
#    call adb#run( l:cmd->join() )
#    sleep 2
#    if v:shell_error | echom "Shell error!" | return | endif
#endfunction
#

def adb#shell( target_device: string = string( g:android_target_device ) ): void
    if IsDeviceValid( target_device )
        echom printf( "Device '%s' not found!", target_device )
        return 
    endif

    execute printf( 'bo term ++close %s -s %s shell', g:adb_bin, target_device )
enddef

def adb#runAsync( ...cmd: list< string > ): void
    if !executable( g:adb_bin )
        echom printf( 'adb binary %s is not found.', g:adb_bin )
    endif

    call job#run( [ g:adb_bin ] + cmd )
enddef

def adb#runSync( ...args: list< string > ): void
    if !executable( g:adb_bin )
        echom printf( 'adb binary %s is not found.', g:adb_bin )
    endif

    const cmd = [ g:adb_bin ] + args

    echom cmd
          ->join()
          ->systemlist()
          ->join("\n")
enddef

defcompile
