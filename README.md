# android-runner
Run gradle and android related stuff

Android Studio craves more gigabytes of RAM that I am willing to buy so this plugin was crated to alleviate some of the problems of Android related development.

## Usage
The plugin needs to know where your `gradlew` is and it assumes it's at the root of the entire android project.

Use `:GradleSetup /path/to/android/project` for bootstrapping.

It will set the following:
```vim
" <arg> denotes the /path/to/android/project argument
g:android_project_root = <arg>
g:gradle_project_root  = <arg>
g:gradle_bin           = <arg> .. '/gradlew'
```

After `:GradleSetup` the plugin checks every 2 seconds for connected devices.
If there is only one, it is selected as the target device.

The default `adb binary` is `$ANDROID_SDK/platform-tools/adb`
If you wish to use some other `adb` binary, set `g:adb_bin` to it.

## Commands

Most of the commands take optional arguments, which is most likely `apk_name`.

If not specified, `g:android_target_app` and `g:target_device` are used.

```vim
GradleRun           - runs `gradle` commands with `g:gradle_project_root` as current working dir, and `g:gradle_flags` as the flags
AdbSelectDevice     - select one of the detected devices as your target
AdbShell            - spawn shell on the target device
AdbRun              - run a command on the  target device
AdbDevices          - list all devices
AdbInstall          - install given apk on target device
AdbStart            - start given app on target device
AdbLogcat           - start logcat (or pidcat)
AdbLogcatClear      - clear logcat
AdbSelectBuildType  - select apk build type
AdbPush             - push given apk to target device
AdbShazam           - push, install, start, logcat
```

## Configuration

Variables:

```vim
g:android_target_device - ID of the target device
g:android_target_app    - name of the target app
g:android_project_root  - path to the android project root
g:gradle_bin            - path to gradlew
g:gradle_project_root   - dirname of g:gradle_bin
g:adb_bin               - path to adb, defaults to $ANDROID_SDK/platform-tools/adb
g:gradle_flags          - flags that are injected into gradle invocations, default to `-p`
```

## Bonus

To stop a job press `<C-c>` in the job's buffer.

To clear the logcat press `<leader>c` in the job's buffer.
