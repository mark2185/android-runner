vim9script

if exists('g:android_runner_loaded')
    finish
endif
const g:android_runner_loaded = 1

if !has('patch-8.2.4053')
    echom "android-runner requires patch 8.2.4053!"
    finish
endif

# TODO: fzf
# TODO: get build types from gradle
# TODO: gradle autocomplete
# TODO: pidcat
# TODO: term#run
# TODO: config file for variables

g:adb_port               = get( g:, 'adb_port', 5037  )
g:jdb_port               = get( g:, 'jdb_port', 54321 )
g:adb_bin                = get( g:, 'adb_bin', systemlist('which adb')[0] )
g:adb_use_pidcat         = get( g:, 'adb_use_pidcat', 0 )
g:android_target_device  = get( g:, 'android_target_device', '' )
g:android_target_app     = get( g:, 'android_target_app',    '' )
g:android_project_root   = get( g:, 'android_project_root',  '' )

g:gradle_bin             = get( g:, 'gradle_bin',          g:android_project_root .. '/gradlew' )
g:gradle_project_root    = get( g:, 'gradle_project_root', g:android_project_root )
g:gradle_flags           = get( g:, 'gradle_flags', '-P android.native.buildOutput=verbose' )
g:android_disable_pidcat = get( g:, 'android_disable_pidcat', v:false )

g:android_lldb_armv8_server_bin = get( g:, 'android_lldb_armv8_server_bin', '' )
g:android_lldb_armv7_server_bin = get( g:, 'android_lldb_armv7_server_bin', '' )

# TODO: command for killing app on device

command! -nargs=1 -complete=dir                              GradleSetup        call gradle#Setup(<f-args>)
command! -nargs=* -complete=customlist,gradle#GetTasks       GradleRun          call gradle#RunAsync(<f-args>)

command! -nargs=?                                            AdbShell           call adb#Shell(<f-args>)
command! -nargs=?                                            AdbSelectDevice    call adb#SelectDevice(<f-args>)
command! -nargs=*                                            AdbRun             call adb#Run(<f-args>)
command! -nargs=0                                            AdbDevices         echom adb#Devices()
#command! -nargs=?                                            AdbInstall         call adb#InstallApp(<f-args>)
#command! -nargs=?                                            AdbStart           call adb#StartApp(<f-args>)
command! -nargs=?                                            AdbLogcat          call adb#GetLogcatOutput(<f-args>)
command! -nargs=?                                            AdbLogcatClear     call adb#ClearLogcat(<f-args>)
command! -nargs=? AdbStartLLDB  call adb#StartLLDB(<f-args>)
command! -nargs=? AdbStartDebug call adb#StartAppDebug(<f-args>)
command! -nargs=? AdbStopLLDB   call adb#StopLLDB(<f-args>)
command! -nargs=1 -complete=customlist,adb#CompleteBuildType AdbSelectBuildType call adb#SelectBuildType(<f-args>)
command! -nargs=*                                            AdbInputText       call adb#InputText(<f-args>)
command! -nargs=1                                            AdbSetPort         call adb#SetPort(<f-args>)
#command! -nargs=+ -complete=file                             AdbPush            call adb#Push(<f-args>)
#command! -nargs=1 -complete=dir                              AdbChangeAndroidProjectRoot call adb#SetAndroidProjectRoot(<f-args>)

## this does push, install, start
command! -nargs=*  AdbShazam   call adb#Shazam(<f-args>)
## this does push, install, start in debug mode
command!           AdbDebugger call adb#LaunchDebugger()
