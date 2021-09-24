let g:android_project_root = systemlist( 'dirname ' . g:gradle_bin )[0]

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
        echom 'Current target device: ' . (empty( g:android_target_device ) ? 'none' : g:android_target_device)
    else
        let g:android_target_device = a:1
    endif
    " TODO: inputlist()
endfunction

let s:build_type_name = 'distribute'

let s:app_pkg = 'com.microblink.exerunner'

function! adb#completeBuildType(...) abort
    return ['debug', 'release', 'distribute']
endfunction

function! adb#SelectBuildType( build_type ) abort
    let s:build_type_name = a:build_type
endfunction

function! s:checkDevice()
    return empty( g:android_target_device )
endfunction

function! adb#push( apk_name = g:android_target_app ) abort
    if s:checkDevice()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'push',
        \ printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, s:build_type_name, s:build_type_name ),
        \ '/data/local/tmp/' . s:app_pkg . '.' . a:apk_name,
        \ ]
    call job#run( l:cmd )
endfunction

"grant_permissions_message = '-g: grant all runtime permissions'
function! adb#installApp( apk_name = g:android_target_app ) abort
    if s:checkDevice()
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
        \ '/data/local/tmp/' . s:app_pkg . '.' . a:apk_name
        \ ]

    call job#run( l:cmd )
    " return systemlist( l:cmd )->join()
endfunction

" let s:package_path = 'com.microblink.exerunner'
" let s:activity_class = 'com.microblink.exerunner.RunActivity'

" benchmark_app_pkg = 'com.microblink.exerunner.' . 'application_build.application_name'
" activity_class = 'com.microblink.exerunner.RunActivity'
function! adb#startApp( app_name = g:android_target_app, package_path = 'com.microblink.exerunner', activity_class = 'com.microblink.exerunner.RunActivity' ) abort
    if s:checkDevice()
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
    if s:checkDevice()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'shell',
        \ 'pidof',
        \ s:app_pkg . '.' . a:app_name
        \ ]->join()

    " echom l:cmd
    return systemlist(l:cmd)[0]
endfunction

function! adb#clearLogcat( app_name = g:android_target_app ) abort
    if s:checkDevice()
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
    if s:checkDevice()
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
    return adb#devices( [ 'model' ] )->map( "v:val['device']" )
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
    if s:checkDevice()
        echom printf( "Device '%s' not found!", g:android_target_device )
        return 
    endif

    " push
    let l:cmd = [
        \ g:adb_bin,
        \ '-s',
        \ g:android_target_device,
        \ 'push',
        \ printf( '%s/app/build/outputs/apk/%s/app-%s.apk', g:android_project_root, s:build_type_name, s:build_type_name ),
        \ '/data/local/tmp/' . s:app_pkg . '.' . a:app_name,
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
        \ '/data/local/tmp/' . s:app_pkg . '.' . a:app_name
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

function! adb#shell() abort
    " bottom term adb -s device shell
endfunction

function! adb#run( cmd ) abort
    if !executable( g:adb_bin )
        echom printf( 'adb binary %s is not found.', g:adb_bin )
    endif

    call job#run( [ g:adb_bin, a:cmd ] )
endfunction
