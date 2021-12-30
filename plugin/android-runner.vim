vim9script

if exists('g:android_runner_loaded')
    finish
endif
const g:android_runner_loaded = 1

# TODO: fzf
# TODO: get build types from gradle
# TODO: gradle autocomplete
# TODO: pidcat
# TODO: term#run
# TODO: timer for checking new adb devices
# TODO: GradleRun default options
# TODO: config file for variables

g:adb_bin                = get( g:, 'adb_bin',               systemlist('which adb')[0] )
g:android_target_device  = get( g:, 'android_target_device', '' )
g:android_target_app     = get( g:, 'android_target_app',    '' )
g:android_project_root   = get( g:, 'android_project_root',  '' )

g:gradle_bin             = get( g:, 'gradle_bin',         g:android_project_root .. '/gradlew' )
g:gradle_project_root    = get( g:, 'gradle_project_root', g:android_project_root )
g:gradle_flags           = get( g:, 'gradle_flags', '-p' )
g:android_disable_pidcat = get( g:, 'android_disable_pidcat', v:false )

g:android_lldb_server_bin = get( g:, 'android_lldb_server_bin', '' )

# TODO: command for killing app on device

command! -nargs=1 -complete=dir                              GradleSetup        call gradle#setup(<f-args>)
command! -nargs=* -complete=customlist,gradle#getTasks       GradleRun          call gradle#runAsync(<f-args>)

command! -nargs=?                                            AdbShell           call adb#shell(<f-args>)
command! -nargs=?                                            AdbSelectDevice    call adb#selectDevice()
command! -nargs=*                                            AdbRun             call adb#run(<f-args>)
command! -nargs=0                                            AdbDevices         echom adb#devices()
#command! -nargs=?                                            AdbInstall         call adb#installApp(<f-args>)
#command! -nargs=?                                            AdbStart           call adb#startApp(<f-args>)
command! -nargs=?                                            AdbLogcat          call adb#getLogcatOutput(<f-args>)
command! -nargs=?                                            AdbLogcatClear     call adb#clearLogcat(<f-args>)
command! -nargs=? AdbStartLLDB  call adb#startLLDB(<f-args>)
command! -nargs=? AdbStartDebug call adb#startAppDebug(<f-args>)
command! -nargs=? AdbStopLLDB   call adb#stopLLDB(<f-args>)
#command! -nargs=1 -complete=customlist,adb#completeBuildType AdbSelectBuildType call adb#SelectBuildType(<f-args>)
#command! -nargs=+ -complete=file                             AdbPush            call adb#push(<f-args>)
#command! -nargs=1 -complete=dir                              AdbChangeAndroidProjectRoot call adb#setAndroidProjectRoot(<f-args>)

## this does push, install, start
command! -nargs=*  AdbShazam   call adb#shazam(<f-args>)
## this does push, install, start in debug mode
command!           AdbDebugger call adb#launchDebugger()
