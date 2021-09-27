if exists('android_runner_loaded')
    finish
endif
let g:android_runner_loaded = 1

" TODO: fzf
" TODO: get build types from gradle
" TODO: gradle autocomplete
" TODO: pidcat
" TODO: term#run

let g:adb_bin               = get( g:, 'adb_bin'              , systemlist('which adb')[0] )
let g:android_target_device = get( g:, 'android_target_device', '' )
let g:android_target_app    = get( g:, 'android_target_app'   , '' )
let g:android_project_root  = get( g:, 'android_project_root' , '' )

let g:gradle_bin            = get( g:, 'gradle_bin'           , '' )
let g:gradle_project_root   = get( g:, 'gradle_project_root'  , '' ) " systemlist( 'dirname ' . g:gradle_bin )[0]

let g:android_lldb_server_bin = get( g:, 'android_lldb_server_bin', '' )
"systemlist( 'dirname ' . g:gradle_bin )[0]

command! -nargs=1 -complete=customlist,gradle#getTasks       GradleRun          call gradle#run(<f-args>)
command! -nargs=? -complete=customlist,adb#completeDevices   AdbSelectDevice    call adb#SelectDevice(<f-args>)
command! -nargs=0                                            AdbShell           call adb#shell()
command! -nargs=1                                            AdbRun             call adb#run(<f-args>)
command! -nargs=0                                            AdbDevices         echom adb#devices()->join("\n")
command! -nargs=?                                            AdbInstall         call adb#installApp(<f-args>)
command! -nargs=?                                            AdbStart           call adb#startApp(<f-args>)
command! -nargs=?                                            AdbLogcat          call adb#getLogcatOutput(<f-args>)
command! -nargs=?                                            AdbLogcatClear     call adb#clearLogcat(<f-args>)
command! -nargs=1 -complete=customlist,adb#completeBuildType AdbSelectBuildType call adb#SelectBuildType(<f-args>)
command! -nargs=+ -complete=file                             AdbPush            call adb#push(<f-args>)
command! -nargs=1 -complete=dir                              AdbChangeAndroidProjectRoot call adb#setAndroidProjectRoot(<f-args>)

" this does push, install, start, logcat
command! -nargs=*                                            AdbShazam call adb#shazam(<f-args>)
