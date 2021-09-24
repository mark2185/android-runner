if exists('android_runner_loaded')
    finish
endif
let g:android_runner_loaded = 1

let g:gradle_bin            = get( g:, 'gradle_bin'           , '' )
let g:adb_bin               = get( g:, 'adb_bin'              , '' )
let g:android_target_device = get( g:, 'android_target_device', '' )
let g:android_target_app    = get( g:, 'android_target_app'   , '' )

command! -nargs=1 -complete=customlist,gradle#getTasks       GradleRun          call gradle#run(<f-args>)
command! -nargs=? -complete=customlist,adb#completeDevices   AdbSelectDevice    call adb#SelectDevice(<f-args>)
command! -nargs=0                                            AdbShell           call adb#shell()
command! -nargs=1                                            AdbRun             call adb#run(<f-args>)
command! -nargs=0                                            AdbDevices         echom adb#devices()
command! -nargs=?                                            AdbInstall         call adb#installApp(<f-args>)
command! -nargs=?                                            AdbStart           call adb#startApp(<f-args>)
command! -nargs=?                                            AdbLogcat          call adb#getLogcatOutput(<f-args>)
command! -nargs=?                                            AdbLogcatClear     call adb#clearLogcat(<f-args>)
command! -nargs=1 -complete=customlist,adb#completeBuildType AdbSelectBuildType call adb#SelectBuildType(<f-args>)
command! -nargs=?                                            AdbPush            call adb#push(<f-args>)
" this does push, install, start, logcat
command! -nargs=*                                            AdbShazam call adb#shazam(<f-args>)
