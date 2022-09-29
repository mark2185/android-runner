vim9script

const android_properties = {
    sdk:          'ro.build.version.sdk',
    abi:          'ro.product.cpu.abi',
    brand:        'ro.product.brand',
    manufacturer: 'ro.product.manufacturer',
    model:        'ro.product.model',
    version:      'ro.build.version.release',
    country:      'persist.sys.country',
    language:     'persist.sys.language',
    timezone:     'persist.sys.timezone',
}

var timer_id = -1

# TODO: make configurable
const g:app_pkg = 'com.microblink.exerunner'

# export def SetAppPkg( app_pkg ): void
#     let g:app_pkg = a:app_pkg
# enddef

# TODO: when it gets implemented
#class Target = {
#    'device': string
#    'appID': string
#}

# {{{ private functions
def ExecuteSync( cmd: list< string > ): list< any >
    return cmd->join()->systemlist()
enddef

def CreateAdbCmd( cmd: list< string >, deviceSerial: string = '' ): list< string >
    var finalCommand: list< string > = [ g:adb_bin, '-P', g:adb_port ]
    if !empty( deviceSerial )
        finalCommand += [ '-s', deviceSerial ]
    endif
    return finalCommand + cmd
enddef

def GetProperty( device: string, property: string ): string
    const adbCmd = CreateAdbCmd( [ 'shell', 'getprop', property ], device )
    return ExecuteSync( adbCmd )
        ->join()
        ->trim()
enddef

def GetDeviceInfo( serialID: string, properties: list<string> = [ 'sdk', 'version', 'model' ] ): dict< string >
    var result = { 'device': serialID }
    for property in properties
        if has_key( android_properties, property )
            result[ property ] = GetProperty( serialID, android_properties[ property ] )
        endif
    endfor
    return result
enddef

def IsDeviceValid( target_device: string ): bool
    if empty( target_device )
        return false
    endif

    const allDevices = Devices()
    if empty( allDevices )
        return false
    endif

    for d in allDevices
        if d['device'] == target_device
            return true
        endif
    endfor

    return false
enddef
# }}}

export def Restart(): void
    ExecuteSync( CreateAdbCmd( [ 'kill-server'  ] ) )
    ExecuteSync( CreateAdbCmd( [ 'start-server' ] ) )
    echon "ADB restarted on port " .. g:adb_port
enddef

export def Devices( properties: list< string > = [] ): list< dict< string > >
    const devices = ExecuteSync( CreateAdbCmd( [ 'devices' ] ) )
            ->filter( '!empty( v:val )' )                      # remove empty lines
            ->filter( 'v:val[0] != "*"' )                      # e.g. "* daemon starting"
            ->filter( 'v:val !~ "^List of devices attached"' )
            ->map( 'v:val->split()[0]' )                       # take serial IDs

    var result = []
    for d in devices
        result->add( GetDeviceInfo( d, properties ) )
    endfor
    return result
enddef

export def SetPort( port: string )
    g:adb_port = port
enddef

export def GetPid( app_name: string = printf( "%s.%s", g:app_pkg, g:android_target_app ) ): number
    if !SelectDevice()
        echom "No devices found"
        return -1
    endif

    # TODO: only works for newer androids ( >= 7, I guess, haven't bisected)
    # older androids print out all PIDs on the system
    # const cmd = [
    #     'shell', 'pidof',
    #     '-s', app_name
    # ]

    # poor man's version
    const cmd = [
        'shell', 'ps',
        printf('| egrep "\b%s\b"', app_name),
        "| tr -s ' '",
        "| cut -d' ' -f2",
    ]

    const cmdOutput = ExecuteSync( CreateAdbCmd( cmd, g:android_target_device ) )
    return cmdOutput
           ->get( 0, '-1' ) # this returns a string because systemlist returns strings
           ->str2nr()
enddef

export def Shell(): void
    if !SelectDevice()
        echom "No devices found"
        return
    endif

    const shellCmd = CreateAdbCmd( [ 'shell' ], g:android_target_device )

    # TODO: job#OpenInTerminal( string )
    execute 'botright term ++close ++rows=20 ' .. shellCmd->join()
enddef

# if there's only one device, select that one
# if there are multiple, bring up a menu
# returns true on successful selection
export def SelectDevice( device: string = '' ): bool
    if !empty(device)
        const isValid = IsDeviceValid( device )
        if isValid
            g:android_target_device = device
        else
            echom printf("Device '%s' is not valid!", device )
        endif
        return isValid
    endif

    const allDevices = Devices( [ 'device', 'brand', 'manufacturer', 'model' ] )
    if empty( allDevices )
        echom "No devices detected"
        return false
    endif

    if len( allDevices ) == 1
        g:android_target_device = allDevices[ 0 ][ 'device' ]
        return true
    endif

    const usr_input: number = inputlist(
        [ 'Which device do you wish to select?' ]
        + deepcopy( allDevices )
        -> map( ( i, d ) => printf( '%d: %s (%s %s)', i + 1, d['device'], d['manufacturer'], d['model'] ) ) )

    if usr_input == 0 || usr_input == -1
        return false
    endif

    const device_index: number = usr_input - 1
    g:android_target_device = allDevices[ device_index ][ 'device' ]
    return true
enddef

# TODO: gradle should have :app:install{Debug,Release,Distribute}
export def Install( src: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ) ): string
    if !SelectDevice()
        echom 'No devices found'
        return 'error installing'
    endif

    return ExecuteSync( CreateAdbCmd( [ 'shell', 'pm', 'install', '-t', '-r', src ] ) )->join("\n")
enddef

# TODO: gradle should have this
export def InstallAsync( src: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ) ): void
    if !SelectDevice()
        echom 'No devices found'
        return
    endif

    call job#Run( CreateAdbCmd( [ 'shell', 'pm', 'install', '-t', '-r', src ] ) )
enddef

var build_type_name = 'debug'

export def CompleteBuildType( ...args: list< any > ): list< string >
    return [ 'debug', 'release', 'distribute' ]
enddef

export def SelectBuildType( build_type: string ): void
    build_type_name = build_type
enddef

export def Push(
      src: string = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name ),
      dst: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ),
    ): void

    if !SelectDevice()
        echom 'No devices found'
        return
    endif

    if empty( g:android_project_root )
        echom 'Android project root is empty, use :GradleSetup'
        return
    endif

    silent cexpr ExecuteSync( CreateAdbCmd( [ 'push', src, dst ], g:android_target_device ) )->join("\n")
    botright copen
enddef

export def PushAsync(
      src: string = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name ),
      dst: string = printf( '/data/local/tmp/%s.%s', g:app_pkg, g:android_target_app ),
     ): void

    if !SelectDevice()
        echom 'No devices found'
        return
    endif

    if empty( g:android_project_root )
        echom 'Android project root is empty, use :GradleSetup'
        return
    endif

    call job#Run( CreateAdbCmd( [ 'push', src, dst ], g:android_target_device ) )
enddef

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
        '-a', 'android.intent.action.MAIN',
        '-c', 'android.intent.category.LAUNCHER'
        ], g:android_target_device ) )->join("\n")
enddef

export def StartAsync(
     app_name:       string = <string>g:android_target_app,
     package_path:   string = 'com.microblink.exerunner',
     activity_class: string = 'com.microblink.exerunner.RunActivity' ): void

    if !SelectDevice()
        echom 'No devices found'
        return
    endif

    call job#Run( CreateAdbCmd( [
        'shell',
        'am',
        'start',
        '-n',
        printf( '%s.%s/%s', package_path, app_name, activity_class ),
        '-a', 'android.intent.action.MAIN',
        '-c', 'android.intent.category.LAUNCHER'
        ], g:android_target_device ) )
enddef

export def LogcatClear(): void
    const logcatClearCmd = CreateAdbCmd( [ 'logcat', '-b', 'all', '-c' ], g:android_target_device )
    ExecuteSync( logcatClearCmd )
enddef

# TODO: in a separate buffer so it doesn't interefere with jobs
export def GetLogcatOutput( app_name: string = 'com.microblink.exerunner.' .. g:android_target_app ): void
    if !SelectDevice()
        echom 'No devices found'
        return
    endif

    if GetPid( app_name ) == -1
        echom printf( "%s is not running!", app_name )
        return
    endif

    # TODO: implement clearing
    if g:adb_use_pidcat
        execute 'botright term ++close ++rows=20 pidcat ' .. app_name
    else
        const appPid = string( GetPid( app_name ) )
        const logcatCmd = CreateAdbCmd( [ 'logcat', '--pid', appPid ], g:android_target_device )
        execute 'botright term ++close ++rows=20 ' .. logcatCmd->join()
        tnoremap <buffer> <leader>c :call adb#LogcatClear()<CR>
    endif
enddef

export def Shazam(
        app_name:       string = <string>g:android_target_app,
        package_path:   string = 'com.microblink.exerunner',
        activity_class: string = 'RunActivity'
    ): void

    if empty( g:android_project_root )
        echom 'Android project root is empty, please use :GradleSetup'
        return
    endif

    if !SelectDevice()
        echom 'No devices found'
        return
    endif

    # push
    const src = printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, build_type_name, build_type_name )
    const dst = printf( '/data/local/tmp/%s.%s', g:app_pkg, app_name )

    job#AddToQueue( CreateAdbCmd( [ 'push', src, dst ], g:android_target_device ) )

    # install
    const app_apk = printf( '/data/local/tmp/%s.%s', g:app_pkg, app_name )

    job#AddToQueue( CreateAdbCmd( [ 'shell', 'pm', 'install', '-t', '-r', app_apk ], g:android_target_device ) )

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

export def LaunchDebugger(): void
    if empty( g:android_project_root )
        echom 'Android project root is empty, please use :GradleSetup'
        return
    endif

    if !SelectDevice()
        echom 'No devices found'
        return
    endif

    if empty(g:android_lldb_armv7_server_bin) && empty(g:android_lldb_armv8_server_bin)
        echom "g:android_lldb_armv{7,8}server_bin is empty! Not pushing lldb-server!"
    else
        const lldbServerDst = '/data/local/tmp/lldb-server'

        const lsOutput = ExecuteSync( CreateAdbCmd( [ 'shell', 'ls', lldbServerDst ], g:android_target_device ) )
        if v:shell_error || "No such file or directory" =~ lsOutput->get( 0, '' )
            # push necessary
            const abi = GetDeviceInfo( g:android_target_device, ['abi'] )['abi']
            const android_lldb_servers = {
                'armeabi-v7a': g:android_lldb_armv7_server_bin,
                'arm64-v8a': g:android_lldb_armv8_server_bin,
            }
            const pushCmd = [ 'push', android_lldb_servers[abi], lldbServerDst ]
            job#AddToQueue( CreateAdbCmd( pushCmd, g:android_target_device ) )
        endif

        # copy to root of app
        job#AddToQueue( CreateAdbCmd( [
            'shell',
            'run-as',
            'com.microblink.exerunner.' .. g:android_target_app,
            'cp',
            '-f',
            lldbServerDst,
            '.' ], g:android_target_device ) )
    endif

    # start app in Debug mode
    job#AddToQueue( CreateAdbCmd( [
        'shell', 'am', 'start', '-D',
        printf( 'com.microblink.exerunner.%s/com.microblink.exerunner.RunActivity', g:android_target_app ),
        '-a', 'android.intent.action.MAIN',
        '-c', 'android.intent.category.LAUNCHER'
        ] ) )

    job#AddToQueue( CreateAdbCmd( [
        'forward',
        'tcp:' .. string(g:jdb_port),
        'jdwp:%PID%'
        ], g:android_target_device
    ) )

    job#ProcessQueue()
enddef

export def StopLLDB()
    var cmd = CreateAdbCmd( [
        'shell',
        'run-as',
        g:app_pkg .. '.' .. g:android_target_app,
        'pkill',
        'lldb-server'
    ], g:android_target_device )

    ExecuteSync( cmd )
enddef

export def RunAsync( ...args: list< string > ): void
    call job#Run( [ printf( "%s -P %d", g:adb_bin, g:adb_port ) ] + args )
enddef

export def Run( ...args: list< string > ): void
    const cmd = [ printf( "%s -P %d", g:adb_bin, g:adb_port ) ] + args

    setqflist( [], 'r' )
    cexpr ExecuteSync( cmd )->join("\n")
    setqflist( [], 'a', { 'title': cmd->join() } )
    botright copen
enddef

export def InputText( ...args: list< string > ): void
    if !SelectDevice()
        echom 'No devices found'
        return
    endif

    const replacedSpace = args->join("%s")
    ExecuteSync( CreateAdbCmd( [ 'shell', 'input', 'text', replacedSpace ], g:android_target_device ) )
enddef

defcompile
