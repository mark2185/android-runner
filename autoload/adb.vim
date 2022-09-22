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

var timer_id = -1

const g:app_pkg = 'com.microblink.exerunner'

export def SetPort( port: string )
    g:adb_port = str2nr(port)
enddef

def ExecuteSync( cmd: list< string > ): string
    return cmd
           ->join()
           ->systemlist()
           ->join("\n")
enddef

def CreateAdbCmd( cmd: list< string >, device: string = <string>g:android_target_device ): list< string >
    return [
        g:adb_bin,
        '-s',
        device,
        '-P',
        string(g:adb_port)
    ] + cmd
enddef

def GetProperty( property: string, device: string = <string> g:android_target_device ): string
    return CreateAdbCmd( [ 'shell', 'getprop', property ], device )
           ->join()
           ->systemlist()
           ->join()
           ->trim()
enddef

def GetDeviceInfo( properties: list<string> = ['sdk', 'version', 'model'], device: string = <string> g:android_target_device ): dict< string >
    var result = { 'device': device }
    for property in properties
                    ->filter( (_, v) => index( android_properties->keys(), v ) != -1 )
        result[ property ] = GetProperty( android_properties[ property ], device )
    endfor
    return result
enddef

def IsDeviceValid( target_device: string ): bool
    return !empty( target_device )
        && index( Devices(['device']), { 'device': target_device } ) != -1
enddef

export def Devices( properties: list< string > = [] ): list< dict< string > >
    if empty( g:adb_bin )
        echom 'g:adb_bin not set!'
        return []
    endif
    const devices = systemlist( printf( "%s -P %d devices", g:adb_bin, g:adb_port ) )
            ->filter( '!empty( v:val )' )
            ->map( 'v:val->matchstr(''\v^(.+)\s+device$'')' )
            ->filter( '!empty(v:val)' )
            ->map( 'v:val->split()[0]' )
            ->map( 'v:val->trim()' )

    var result = []
    for d in devices
        result->add( GetDeviceInfo( properties, d ) )
    endfor
    return result
enddef

export def GetPid( app_name: string = printf( "%s.%s", g:app_pkg, g:android_target_app ) ): number
    if !IsDeviceValid( g:android_target_device )
        echom printf( "Device '%s' not found!", g:android_target_device )
        return -1
    endif

    # TODO: only works for newer androids ( >= 7, I guess, haven't bisected)
    # const cmd = [
    #     'shell',
    #     'pidof',
    #     '-s',
    #     app_name
    # ]

    # waterproof solution
    const cmd = [
        'shell',
        'ps',
        printf('| egrep "\b%s\b"', app_name),
        "| tr -s ' '",
        "| cut -d' ' -f2",
    ]

    echom "Checking pidof: " .. app_name
    return CreateAdbCmd( cmd )
           ->join()
           ->systemlist()
           ->get( 0, '-1' ) # this returns a string because systemlist returns strings
           ->str2nr()
enddef

export def Install( src: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ) ): string
    if !IsDeviceValid( g:android_target_device )
        echom 'Device not found!'
        return 'Device not valid'
    endif

    return ExecuteSync( CreateAdbCmd( [ 'shell', 'pm', 'install', '-t', '-r', src ] ) )
enddef

export def InstallAsync( src: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ) ): void
    if !IsDeviceValid( g:android_target_device )
        echom 'Device not found!'
        return
    endif

    call job#Run( CreateAdbCmd( [ 'shell', 'pm', 'install', '-t', '-r', src ] ) )
enddef

var build_type_name = 'debug'

export def CompleteBuildType( ...args: list< any > ): list< string >
    return ['debug', 'release', 'distribute']
enddef

export def SelectBuildType( build_type: string ): void
    build_type_name = build_type
enddef

export def Push(
      src: string = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name ),
      dst: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ),
     ): void

    if !IsDeviceValid( g:android_target_device )
        echom 'Device not found!'
        return
    endif

    if empty( g:android_project_root )
        echom 'Android project root is empty, use :GradleSetup'
        return
    endif

    silent cexpr ExecuteSync( CreateAdbCmd( [ 'push', src, dst ] ) )
    botright copen
enddef

export def PushAsync(
      src: string = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name ),
      dst: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ),
     ): void

    if !IsDeviceValid( g:android_target_device )
        echom 'Device not found!'
        return
    endif

    if empty( g:android_project_root )
        echom 'Android project root is empty, use :GradleSetup'
        return
    endif

    call job#Run( CreateAdbCmd( [ 'push', src, dst ] ) )
enddef

# TODO: inputlist may be friendlier() ?
export def SelectDevice( device: string = '' ): void
    if !empty( device )
        g:android_target_device = device
    else
        const devices = Devices( ['device'] )
        if len( devices ) == 1
            g:android_target_device = devices[ 0 ][ 'device' ]
        else
            # inputlist ?
        endif
    endif
enddef

#let s:build_type_name = 'distribute'
#
#
#function! SetAppPkg( app_pkg ) abort
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
export def Start(
     app_name:       string = <string>g:android_target_app,
     package_path:   string = 'com.microblink.exerunner',
     activity_class: string = 'com.microblink.exerunner.RunActivity'
     ): string

    if !IsDeviceValid( g:android_target_device )
        return 'Device not found!'
    endif

    return ExecuteSync( CreateAdbCmd( [
        'shell',
        'am',
        'start',
        '-n',
        printf( '%s.%s/%s', package_path, app_name, activity_class ),
        '-a',
        'android.intent.action.MAIN',
        '-c',
        'android.intent.category.LAUNCHER'
        ] ) )
enddef

export def StartAsync(
     app_name:       string = <string>g:android_target_app,
     package_path:   string = 'com.microblink.exerunner',
     activity_class: string = 'com.microblink.exerunner.RunActivity' ): void

    if !IsDeviceValid( g:android_target_device )
        echom 'Device not found!'
        return
    endif

    call job#Run( CreateAdbCmd( [
        'shell',
        'am',
        'start',
        '-n',
        printf( '%s.%s/%s', package_path, app_name, activity_class ),
        '-a',
        'android.intent.action.MAIN',
        '-c',
        'android.intent.category.LAUNCHER'
        ] ) )
enddef

#function! StartAppDebug( app_name = g:android_target_app, package_path = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity' ) abort
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
#    call job#Run( l:cmd )
#    " return systemlist( l:cmd )->join()
#endfunction
#
#function! ClearLogcat( app_name = g:app_pkg . '.' . g:android_target_app ) abort
#    if !s:isDeviceValid()
#        echom printf( "Device '%s' not found!", g:android_target_device )
#        return
#    endif
#
#    call system( s:createAdbCmd( [ 'logcat', '-c', '--pid', GetPid( a:app_name ) ] )->join() )
#    echom "Logcat cleared!"
#endfunction
#
#function! GetPidcatOutput( app_name = g:android_target_app )
#endfunction
#

# TODO: in a separate buffer so it doesn't interefere with jobs
export def GetLogcatOutput( app_name: string = 'com.microblink.exerunner.' .. g:android_target_app ): void
    if !IsDeviceValid( g:android_target_device )
        echom 'Device not found!'
        return
    endif

    if GetPid( app_name ) == -1
        echom printf( "%s is not running!", app_name )
        return
    endif

    # TODO: check if pidcat exists and use that
    job#Run( CreateAdbCmd( [ 'logcat', '--pid', string( GetPid( app_name ) ) ] ) )
enddef
#
#function! GetPidcatOutput( app_name = 'com.microblink.exerunner.' . g:android_target_app ) abort
#    if !s:isDeviceValid()
#        echom printf( "Device '%s' not found!", g:android_target_device )
#        return
#    endif
#
#    call job#Run( ['pidcat', a:app_name] )
#endfunction
#
#function! KillServer() abort
#    call job#Run( g:adb_bin . ' kill-server' )
#endfunction
#

export def Restart(): void
    call job#Run( [ printf( '%s -P %d kill-server && %s -P %d start-server', g:adb_bin, g:adb_port, g:adb_bin, g:adb_port ) ] )
enddef

export def Shazam(
     app_name:       string = <string>g:android_target_app,
     package_path:   string = 'com.microblink.exerunner',
     activity_class: string = 'RunActivity'
    ): void

    SelectDevice()

    if !IsDeviceValid( g:android_target_device )
        echom 'Device not found!'
        return
    endif

    if empty( g:android_project_root )
        echom 'Android project root is empty, please use :GradleSetup'
        return
    endif

    # push
    const src = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name )
    const dst = printf( '/data/local/tmp/%s.%s', g:app_pkg, app_name )

    job#AddToQueue( CreateAdbCmd( [ 'push', src, dst ] ) )

    # install
    const app_apk = printf('/data/local/tmp/%s.%s', g:app_pkg, app_name )

    job#AddToQueue( CreateAdbCmd( [ 'shell', 'pm', 'install', '-t', '-r', app_apk ] ) )

    # start
    job#AddToQueue( CreateAdbCmd( [
        'shell', 'am', 'start', '-n',
        printf( '%s.%s/%s.%s', package_path, app_name, package_path, activity_class ),
        '-a', 'android.intent.action.MAIN',
        '-c', 'android.intent.category.LAUNCHER'
        ] ) )

    job#ProcessQueue()
enddef

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
#function! ProfileStart( target_device = g:android_target_device ) abort
#    if !s:isDeviceValid( a:target_device ) abort
#        echom printf( "Device '%s' not found!", a:target_device )
#        return
#    endif
#endfunction
#
#let s:lldb_port = 0
#
#function! GetLLDBport() abort
#    return s:lldb_port
#endfunction

# def StartLLDB( target_device: any = g:android_target_device )
#     if !IsDeviceValid( target_device )
#         echom printf( "Device '%s' not found!", target_device )
#         return
#     endif

#     # TODO: check if the file already exists
#     var cmd = [
#         'shell',
#         'ls',
#         '/data/local/tmp/lldb-server'
#     ]

#     const found_lldb_server = 'no such file' !~# ExecuteSync( CreateAdbCmd( cmd ) )

#     if found_lldb_server
#         # TODO: get it from ANDROID_SDK and getprop cpu.abi
#         if empty( g:android_lldb_server_bin ) || !executable( g:android_lldb_server_bin )
#             echom printf( "Binary '%s' not found or not executable!", g:android_lldb_server_bin )
#             return
#         endif

#         call Push( g:android_lldb_server_bin, '/data/local/tmp/lldb-server' )

#         if v:shell_error | echom "Shell error!" | botright copen | return | endif

#         cmd = [
#             'shell',
#             'run-as',
#             printf( '%s.%s', g:app_pkg, g:android_target_app ),
#             'cp',
#             '/data/local/tmp/lldb-server',
#             '.'
#         ]

#         call Run( cmd->join() )

#         if v:shell_error | echom "Shell error!" | botright copen | return | endif
#     endif

#     cmd = [
#         'shell',
#         'run-as',
#         printf( '%s.%s', g:app_pkg, g:android_target_app ),
#         './lldb-server',
#         'platform',
#         '--server',
#         '--listen "*:54321"',
#         '&'
#     ]

#     # Run( cmd->join() )
#     botright cexpr ExecuteSync( [ g:adb_bin ] + cmd )

#     sleep 2
#     if v:shell_error | echom "Shell error!" | botright copen | return | endif

#     cmd = [
#         'forward',
#         'tcp:54321',
#         'tcp:54321'
#     ]

#     botright cexpr ExecuteSync( [ g:adb_bin ] + cmd )

#     sleep 2
#     if v:shell_error | echom "Shell error!" | botright copen | return | endif
# enddef

# this requires running AdbShazam first
export def LaunchDebugger(): void
    if empty(g:android_lldb_armv7_server_bin) && empty(g:android_lldb_armv8_server_bin)
        echom "g:android_lldb_armv{7,8}server_bin is empty! Not pushing lldb-server!"
    else
        # push lldb-server
        # TODO: only if necessary

        const abi = GetDeviceInfo( ['abi'] )['abi']
        var android_lldb_server = ''
        if abi == 'armeabi-v7a'
            android_lldb_server = g:android_lldb_armv7_server_bin
        else
            android_lldb_server = g:android_lldb_armv8_server_bin
        endif
        job#AddToQueue( CreateAdbCmd( [ 'push', android_lldb_server, '/data/local/tmp/lldb-server' ] ) )

        # copy to root of app
        job#AddToQueue( CreateAdbCmd( [
            'shell',
            'run-as',
            'com.microblink.exerunner.' .. g:android_target_app,
            'cp',
            '/data/local/tmp/lldb-server',
            '.' ] ) )
    endif

    # start app in Debug mode
    job#AddToQueue( CreateAdbCmd( [
        'shell', 'am', 'start', '-D',
        printf( 'com.microblink.exerunner.%s/com.microblink.exerunner.RunActivity', g:android_target_app ),
        '-a', 'android.intent.action.MAIN',
        '-c', 'android.intent.category.LAUNCHER'
        ] ) )

    # necessary for the app to start up
    # TODO: don't guesstimate
    job#AddToQueue( [ 'sleep', '4' ] )

    job#AddToQueue( CreateAdbCmd( [
        'forward',
        'tcp:' .. string(g:jdb_port),
        'jdwp:%PID%'
    ] ) )

    job#ProcessQueue()
enddef

# TODO: under construction
#export def StartAppDebug(
#     app_name: any  = <string>g:android_target_app,
#     package_path   = 'com.microblink.exerunner',
#     activity_class = 'com.microblink.exerunner.RunActivity'
#    ): void
#
#    if !IsDeviceValid( g:android_target_device )
#        echom printf( "Device '%s' not found!", g:android_target_device )
#        return
#    endif
#
#    # push
#    const src = printf( '%s/app/build/outputs/apk/debug/app-debug.apk', g:android_project_root )
#    const dst = printf( '/data/local/tmp/%s.%s', g:app_pkg, app_name )
#
#    call Push( src, dst )
#
#    if v:shell_error | echom "Shell returned error!" | botright copen | return | endif
#
#    # install
#    const app_apk = printf('/data/local/tmp/%s.%s', g:app_pkg, app_name )
#
#    call Install( app_apk )
#
#    var cmd = CreateAdbCmd( [
#        'shell',
#        'am',
#        'start',
#        '-D',
#        printf( '%s.%s/%s', package_path, app_name, activity_class ),
#        '-a',
#        'android.intent.action.MAIN',
#        '-c',
#        'android.intent.category.LAUNCHER'
#    ] )
#
#    ExecuteSync( cmd )
#    # call job#Run( cmd )
#
#    # TODO: don't guesstimate
#    sleep 2
#
#    const app_pid = string( GetPid( [ package_path, app_name ]->join('.') ) )
#    cmd = CreateAdbCmd( [
#        'forward',
#        'tcp:54321',
#        'jdwp:' .. app_pid
#    ] )
#
#    ExecuteSync( cmd )
#
#    # TODO: don't guesstimate
#    sleep 3
#
#    botright cexpr ExecuteSync( [ 'jdb', '-attach', 'localhost:54321', '&' ] )
#    echom "Pid is: " .. app_pid .. ", it's stored in the register p"
#    setreg( 'p', app_pid )
#enddef

export def StopLLDB( target_device: any = g:android_target_device )
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

    botright cexpr ExecuteSync( cmd )

    sleep 2
    if v:shell_error | echom "Shell error!" | botright copen | return | endif
enddef

export def Shell( target_device: string = <string>g:android_target_device ): void
    # echom printf( "I got: '%s'", target_device )
    if !IsDeviceValid( target_device )
        echom 'Device not found!'
        return
    endif

    execute printf( 'botright term ++close %s -s %s shell', g:adb_bin, target_device )
enddef

export def RunAsync( ...args: list< string > ): void
    if !executable( g:adb_bin )
        echom printf( "adb binary '%s' is not found.", g:adb_bin )
    endif

    call job#Run( [ printf( "%s -P %d", g:adb_bin, g:adb_port ) ] + args )
enddef

export def Run( ...args: list< string > ): void
    if !executable( g:adb_bin )
        echom printf( "adb binary '%s' is not found.", g:adb_bin )
    endif

    const cmd = [ printf( "%s -P %d", g:adb_bin, g:adb_port ) ] + args

    setqflist( [], 'r' )
    cexpr ExecuteSync( cmd )
    setqflist( [], 'a', { 'title': cmd->join() } )
    botright copen
enddef

export def InputText( ...args: list< string > ): void
    SelectDevice()

    if !IsDeviceValid( g:android_target_device )
        echom 'Device not found!'
        return
    endif

    # echom args
    # Run( [ args ] )
enddef

export def SelectAndroidDevice( timer: number ): void
    if IsDeviceValid( g:android_target_device )
        return
    endif
    const devices = Devices( [] )
    if empty( devices )
        g:android_target_device = ''
    elseif len( devices ) == 1
        g:android_target_device = devices[0]['device']
    endif
enddef

export def StartDeviceWatch(): void
    if timer_id == -1
        timer_id = timer_start( 1000, funcref('SelectAndroidDevice'), { 'repeat': -1 } )
    endif
enddef

export def StopDeviceWatch(): void
    if timer_id == -1
        return
    endif
    timer_stop( timer_id )
    timer_id = -1
enddef

defcompile
