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

const g:app_pkg = 'com.microblink.exerunner'

def ExecuteSync( cmd: list< string > ): string
    return cmd
           ->join()
           ->systemlist()
           ->join("\n")
enddef

def CreateAdbCmd( cmd: list< string >, device: any = g:android_target_device ): list< string >
    return [
        g:adb_bin,
        '-s',
        device
    ] + cmd
enddef

def GetProperty( property: string, device: string = string( g:android_target_device ) ): string
    return CreateAdbCmd( [ 'shell', 'getprop', property ], device )
           ->join()
           ->systemlist()
           ->join()
enddef

def GetDeviceInfo( properties: list< string > = [ 'sdk', 'version', 'model' ], device: string = string( g:android_target_device ) ): dict< string >
    var result = { 'device': device }
    for property in properties
                    ->filter( (_, v) => index( android_properties->keys(), v ) != -1 )
        result[ property ] = GetProperty( android_properties[ property ], device )
    endfor
    return result
enddef

def IsDeviceValid( target_device: string = string( g:android_target_device ) ): bool
    return !empty( target_device )
           #&& index( adb#devices(['device'])
           #          ->map( ( _, v ) => v[ 'device' ]),
           #          target_device ) != -1
enddef

def adb#devices( properties: list< string > = [] ): list< dict< string > >
    const devices = systemlist( g:adb_bin .. ' devices' )
            ->filter( '!empty( v:val )' )
            ->map( 'v:val->matchstr(''\v^(.+)\s+device$'')' )
            ->filter( '!empty(v:val)' )
            ->map( 'v:val->split()[0]' )
            ->map( 'v:val->trim()' )

    var result = []
    for d in devices
        echom d
        result->add( GetDeviceInfo( properties, d ) )
    endfor
    return result
enddef

def adb#getPid( app_name: any = g:app_pkg .. '.' .. g:android_target_app ): number
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
           ->get( 0, '-1' ) # this returns a string because systemlist returns strings
           ->str2nr()
enddef

def adb#install( src = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ) ): string
    if !IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 'Device not valid'
    endif

    return ExecuteSync( CreateAdbCmd( [ 'shell', 'pm', 'install', '-t', '-r', src ] ) )
enddef

def adb#installAsync( src = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ) ): void
    if !IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    call job#run( CreateAdbCmd( [ 'shell', 'pm', 'install', '-t', '-r', src ] ) )
enddef

var build_type_name = 'debug'

def adb#completeBuildType( ...args: list< any > ): list< string >
    return ['debug', 'release', 'distribute']
enddef

def adb#SelectBuildType( build_type: string ): void
    build_type_name = build_type
enddef

def adb#push(
      src: string = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name ),
      dst: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ),
     ): void

    if !IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return
    endif

    if empty( g:android_project_root )
        echom "Android project root is empty!"
        # TODO: ask to user if they want to 
        # set it based on gradle_bin
        return
    endif

    cexpr ExecuteSync( CreateAdbCmd( [ 'push', src, dst ] ) )
enddef

def adb#pushAsync(
      src: string = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name ),
      dst: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ),
      async: bool = v:true ): void

    if !IsDeviceValid()
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
def adb#completeDevices( arglead: string, cmdline: string, cursor_pos: number ): list< string >
    var result = [] 
    for entry in adb#devices( [ 'device' ] )
        result->add( entry['device'] )
    endfor
    return result
enddef

# TODO: inputlist may be friendlier() ?
def adb#selectDevice( ...device: list< string > ): void
    if empty( device )
        echom 'Current target device: ' .. ( empty( g:android_target_device ) ? 'none' : g:android_target_device )
    else
        g:android_target_device = device[ 0 ]
    endif
enddef

#let s:build_type_name = 'distribute'
#
#
#function! adb#setAppPkg( app_pkg ) abort
#    let g:app_pkg = a:app_pkg
#endfunction
#
#
#
#
#"grant_permissions_message = '-g: grant all runtime permissions'
#
#" let s:package_path = 'com.microblink.exerunner'
#" let s:activity_class = 'com.microblink.exerunner.RunActivity'
#
#" benchmark_app_pkg = 'com.microblink.exerunner.' . 'application_build.application_name'
#" activity_class = 'com.microblink.exerunner.RunActivity'
def adb#start( app_name: any = g:android_target_app, package_path: string = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity' ): string
    if !IsDeviceValid()
        return printf( "Device '%s' not found!", g:android_target_device )
    endif

    return ExecuteSync( CreateAdbCmd( [
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

def adb#startAsync( app_name: string = string(g:android_target_app ), package_path = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity' ): void
    if !IsDeviceValid()
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
    if !IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    if adb#getPid( app_name ) == -1
        echom printf( "%s is not running!", app_name )
        return
    endif

    call job#run( CreateAdbCmd( [ 'logcat', '--pid', string( adb#getPid( app_name ) ) ] ) )
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

def adb#shazam( app_name: any = g:android_target_app, package_path: string = 'com.microblink.exerunner', activity_class: string = 'RunActivity' ): void
    if !IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    if empty( g:android_project_root )
        echom "Android project root is empty!"
        return
    endif

    # push
    const src = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name )
    const dst = printf( '/data/local/tmp/%s.%s', g:app_pkg, app_name )

    call adb#push( src, dst )

    if v:shell_error | echom "Shell returned error!" | copen | return | endif

    # install
    const app_apk = printf('/data/local/tmp/%s.%s', g:app_pkg, app_name )

    call adb#install( app_apk )

    if v:shell_error | echom "Shell returned error!" | copen | return | endif

    # TODO: check on android if it's done
    sleep 2
    
    # start
    const app = printf( '%s.%s/%s.%s', package_path, app_name, package_path, activity_class )

    echom "Sending: " .. app
    echom adb#start( 'CoreUtilsTest' )

    if v:shell_error | echom "Shell returned error!" | copen | return | endif

    sleep 2

    call adb#getLogcatOutput() # printf( '%s.%s', package_path, app_name ) )
enddef
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

def adb#startLLDB( target_device: any = g:android_target_device )
    if !IsDeviceValid( target_device )
        echom printf( "Device '%s' not found!", target_device )
        return 
    endif

    # TODO: get it from ANDROID_SDK and getprop cpu.abi
    if empty( g:android_lldb_server_bin ) || !executable( g:android_lldb_server_bin )
        echom printf( "Binary '%s' not found or not executable!", g:android_lldb_server_bin )
        return 
    endif

    call adb#push( g:android_lldb_server_bin, '/data/local/tmp/lldb-server' )

    if v:shell_error | echom "Shell error!" | copen | return | endif

    var cmd = [
        'shell',
        'run-as',
        printf( '%s.%s', g:app_pkg, g:android_target_app ),
        'cp',
        '/data/local/tmp/lldb-server',
        '.'
    ]

    # TODO: this is broken: https://github.com/vim/vim/issues/8926
    # call adb#run( cmd )
    ExecuteSync( [ g:adb_bin ] + cmd )

    if v:shell_error | echom "Shell error!" | copen | return | endif

    cmd = [
        'shell',
        'run-as',
        printf( '%s.%s', g:app_pkg, g:android_target_app ),
        './lldb-server',
        'platform',
        'server',
        '--listen "*:54321"',
        '&'
    ]

    # TODO: this is broken: https://github.com/vim/vim/issues/8926
    # call adb#run( cmd )
    ExecuteSync( [ g:adb_bin ] + cmd )

    sleep 2
    if v:shell_error | echom "Shell error!" | copen | return | endif

    cmd = [
        'forward',
        'tcp:54321',
        'tcp:54321'
    ]

    # TODO: this is broken: https://github.com/vim/vim/issues/8926
    # call adb#run( cmd )
    ExecuteSync( [ g:adb_bin ] + cmd )

    sleep 2
    if v:shell_error | echom "Shell error!" | copen | return | endif
enddef

def adb#startAppDebug( app_name: any = g:android_target_app, package_path = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity' )
    if !IsDeviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    var cmd = CreateAdbCmd( [
        'shell',
        'am',
        'start',
        '-D',
        printf( '%s.%s/%s', package_path, app_name, activity_class ),
        '-a',
        'android.intent.action.MAIN',
        '-c',
        'android.intent.category.LAUNCHER'
    ] )

    ExecuteSync( cmd )
    # call job#run( cmd )

    # TODO: don't guesstimate
    sleep 2

    cmd = CreateAdbCmd( [
        'forward',
        'tcp:54321',
        'jdwp:' .. string( adb#getPid( [ package_path, app_name ]->join('.')) )
    ] )

    # TODO: this is broken: https://github.com/vim/vim/issues/8926
    # call adb#run( cmd )
    ExecuteSync( cmd )

    # TODO: don't guesstimate
    sleep 3

    job#run( [ 'jdb', '-attach', 'localhost:54321' ] )
    echom "Pid is: " .. string( adb#getPid( [ package_path, app_name ]->join('.') ) )
enddef

def adb#stopLLDB( target_device: any = g:android_target_device )
    var cmd = CreateAdbCmd( [
        'shell',
        'run-as',
        g:app_pkg .. '.' .. g:android_target_app,
        'pkill',
        'lldb-server'
    ] )

    cgetexpr ExecuteSync( cmd )

    cmd = [
        'pkill', 
        'jdb'
    ]

    cexpr ExecuteSync( cmd )

    sleep 2
    if v:shell_error | echom "Shell error!" | copen | return | endif
enddef


def adb#shell( target_device: any = g:android_target_device ): void
    if !IsDeviceValid( target_device )
        echom printf( "Device '%s' not found!", target_device )
        return 
    endif

    execute printf( 'bo term ++close %s -s %s shell', g:adb_bin, target_device )
enddef

def adb#runAsync( ...args: list< string > ): void
    if !executable( g:adb_bin )
        echom printf( 'adb binary %s is not found.', g:adb_bin )
    endif

    call job#run( [ g:adb_bin ] + args )
enddef

export def adb#run( ...args: list< string > ): void
    if !executable( g:adb_bin )
        echom printf( 'adb binary %s is not found.', g:adb_bin )
    endif

    const cmd = [ g:adb_bin ] + args

    cexpr ExecuteSync( cmd )
enddef

defcompile
