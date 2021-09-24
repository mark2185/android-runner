function! adb#setAndroidProjectRoot( path ) abort
    if !isdirectory( a:path )
        echom "This is not a valid directory!"
        return
    endif

    let g:android_project_root = a:path
endfunction

let s:android_properties = #{
        \ SDK          : 'ro.build.version.sdk'    ,
        \ version      : 'ro.build.version.release',
        \ brand        : 'ro.product.brand'        ,
        \ model        : 'ro.product.model'        ,
        \ manufacturer : 'ro.product.manufacturer' ,
        \ country      : 'persist.sys.country'     ,
        \ language     : 'persist.sys.language'    ,
        \ timezone     : 'persist.sys.timezone'    ,
      \}

" Returns device property as string
function! adb#getProperty(device, property) abort
  let l:cmd = [
    \ g:adb_bin,
    \ '-s',
    \ a:device,
    \ 'shell getprop',
    \ a:property
    \ ]->join()
  return systemlist(l:cmd)->join()
endfunction

function! adb#getDeviceInfo( device, properties = [ 'sdk', 'version', 'model' ] ) abort
    let l:result = #{ device : a:device }
    for property in a:properties
        if has_key( s:android_properties, property )
            let l:result[ property ] = adb#getProperty( a:device, s:android_properties[ property ] )
        endif
    endfor
    return l:result
endfunction

" let g:android_target_device = ''
" let g:android_target_app = ''
" if len(adb#completeDevices()) == 1
"     let g:android_target_device = adb#completeDevices()[0]
" endif

function! adb#SelectDevice( ... ) abort
    if !a:0
        echom 'Current target device: ' . ( empty( g:android_target_device ) ? 'none' : g:android_target_device )
    else
        let g:android_target_device = a:1->split('-')[0]->trim()
    endif
    " TODO: inputlist()
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

" TODO: rename to indicate bool return value
function! s:deviceValid( target_device = g:android_target_device )
    if empty( a:target_device )
        return v:false
    endif

    return index( adb#devices(['device'])->map('v:val["device"]'), a:target_device ) != -1
        " echom printf("Target device '%s' isn't connected!", a:target_device)
        " let g:android_target_device = ''
        " return v:false
    " endif

    return v:true
endfunction

function! adb#push( apk_name = g:android_target_app ) abort
    if !s:deviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    if empty( g:android_project_root )
        echom "Android project root is empty!"
        " TODO: ask to user if they want to 
        " set it based on gradle_bin
        return
    endif

    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'push',
        \ printf( '%s/%s/build/outputs/apk/%s/%s-%s.apk', g:android_project_root, a:apk_name, a:apk_name, s:build_type_name, s:build_type_name ),
        \ '/data/local/tmp/' . g:app_pkg . '.' . a:apk_name,
        \ ]
    call job#run( l:cmd )
endfunction

"grant_permissions_message = '-g: grant all runtime permissions'
function! adb#installApp( apk_name = g:android_target_app ) abort
    if !s:deviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'shell',
        \ 'pm',
        \ 'install',
        \ '-t',
        \ '-r',
        \ '/data/local/tmp/' . g:app_pkg . '.' . a:apk_name
        \ ]

    call job#run( l:cmd )
    " return systemlist( l:cmd )->join()
endfunction

" let s:package_path = 'com.microblink.exerunner'
" let s:activity_class = 'com.microblink.exerunner.RunActivity'

" benchmark_app_pkg = 'com.microblink.exerunner.' . 'application_build.application_name'
" activity_class = 'com.microblink.exerunner.RunActivity'
function! adb#startApp( app_name = g:android_target_app, package_path = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity' ) abort
    if !s:deviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'shell',
        \ 'am',
        \ 'start',
        \ '-n',
        \ a:package_path . '.' . a:app_name . '/' . a:activity_class,
        \ '-a',
        \ 'android.intent.action.MAIN',
        \ '-c',
        \ 'android.intent.category.LAUNCHER'
        \ ]
    call job#run( l:cmd )
    " return systemlist( l:cmd )->join()
endfunction

function! s:getPid( app_name ) abort
    if !s:deviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'shell',
        \ 'pidof',
        \ g:app_pkg . '.' . a:app_name
        \ ]->join()

    " echom l:cmd
    return systemlist(l:cmd)[0]
endfunction

function! adb#clearLogcat( app_name = g:android_target_app ) abort
    if !s:deviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'logcat',
        \ '-c',
        \ '--pid',
        \ s:getPid( a:app_name )
        \ ]

    call system( l:cmd->join() )
    echom "Logcat cleared!"
endfunction

function! adb#getLogcatOutput( app_name = g:android_target_app ) abort
    if !s:deviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'logcat',
        \ '--pid',
        \ s:getPid( a:app_name )
        \ ]

    call job#run( l:cmd )
endfunction

function! adb#killServer() abort
    call job#run( g:adb_bin . ' kill-server' )
endfunction

function! adb#completeDevices(...) abort
    " echom adb#devices( ['model'] )
    return adb#devices( [ 'brand', 'model' ] )->map( 'printf("%s - %s", v:val["device"], v:val["model"])' )
endfunction

function! adb#devices( properties = [] ) abort
  let l:adb_output = systemlist(g:adb_bin . ' devices')
  let l:adb_devices = []

  for line in l:adb_output
    let l:adb_device = matchlist(line, '\v^(.+)\s+device$')
    if !empty( l:adb_device )
      let l:serial = l:adb_device[1]->trim()
      let l:info   = adb#getDeviceInfo( l:serial, empty( a:properties ) ? v:none : a:properties )
      call add(l:adb_devices, l:info)
    endif
  endfor

  return l:adb_devices
endfunction

function! adb#shazam( app_name = g:android_target_app, package_path = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity'  ) abort
    if !s:deviceValid()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    if empty( g:android_project_root )
        echom "Android project root is empty!"
        return
    endif

    " push
    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'push',
        \ printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, s:build_type_name, s:build_type_name ),
        \ '/data/local/tmp/' . g:app_pkg . '.' . a:app_name,
        \ ]

    echom systemlist( l:cmd->join() )->join("\n")

    if v:shell_error | return | endif

    " install
    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'shell',
        \ 'pm',
        \ 'install',
        \ '-t',
        \ '-r',
        \ '/data/local/tmp/' . g:app_pkg . '.' . a:app_name
        \ ]

    echom systemlist( l:cmd->join() )->join("\n")

    sleep 2

    if v:shell_error | return | endif
    
    " start
    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'shell',
        \ 'am',
        \ 'start',
        \ '-n',
        \ a:package_path . '.' . a:app_name . '/' . a:activity_class,
        \ '-a',
        \ 'android.intent.action.MAIN',
        \ '-c',
        \ 'android.intent.category.LAUNCHER'
        \ ]

    echom systemlist( l:cmd->join() )->join("\n")

    if v:shell_error | return | endif

    sleep 2

    call adb#getLogcatOutput()
endfunction

function! adb#shell( target_device = g:android_target_device ) abort
    if !s:deviceValid( a:target_device )
        echom printf( "Device '%s' not found!", a:target_device )
        return 
    endif
    execute printf( 'bo term ++close adb -s %s shell', a:target_device )
endfunction

function! adb#run( cmd ) abort
    if !executable( g:adb_bin )
        echom printf( 'adb binary %s is not found.', g:adb_bin )
    endif

    call job#run( [ g:adb_bin, a:cmd ] )
endfunction
