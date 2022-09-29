# android-runner
Run `gradle` and android related stuff

Android Studio craves more gigabytes of RAM that I am willing to buy so this plugin was created to alleviate some of the problems of Android related development.

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

After `:GradleSetup` the plugin checks every second for connected devices.
If there is only one, it is selected as the target device.

The default `adb` binary is searched for in:
  - `$ANDROID_SDK/platform-tools/adb`
  - `$(which adb)`

An error message will pop up if it fails.
If you wish to use some other `adb` binary, set `g:adb_bin` to it.

## Commands

Most of the commands take optional arguments, which is most likely `apk_name`.

If not specified, `g:android_target_app` and `g:target_device` are used.

```vim
GradleRun           - runs `gradle` commands with `g:gradle_project_root` as current working dir, and `g:gradle_flags` as the flags
AdbSetPort          - set port (default: `5037`)
AdbSelectDevice     - select one of the detected devices as your target
AdbShell            - spawn shell on the target device
AdbRun              - run a command on the  target device
AdbInputText        - inputs given text on the device
AdbDevices          - list all devices
AdbInstall          - install given apk on target device
AdbStart            - start given app on target device
AdbLogcat           - start logcat (or pidcat)
AdbLogcatClear      - clear logcat
AdbSelectBuildType  - select apk build type
AdbPush             - push given apk to target device
AdbShazam           - push, install, start
AdbDebugger         - push, install, start in debug mode
```

Default `LLDB` server port is `54321`.

## Using the debugger

### 0. Pre-setup

Be sure to set the following variables so that the correct `lldb-server` can be pushed to the device:
```vim
g:android_lldb_armv8_server_bin
g:android_lldb_armv7_server_bin
```

If you're using the portable version of AS, downloaded straight from its site, the servers should be in these directories:
```
$> ls android-studio/plugins/android-ndk/resources/lldb/android/
arm64-v8a armeabi x86 x86_64
```

### 1. Setup

Run `:GradleSetup /path/to/android/project`.

Run `:GradleRun :app:assembleDebug` or any other `gradle` command you need.

Set `g:android_target_app` to the final app name, e.g. `CoreUtilsTest`.

If you have only one android device connected, it'll be used for running the `adb` commands.
But if you have more than one, please set the ID through `:AdbSelectDevice`.

Run `:AdbDebugger`

Note: if you want to preset the GradleSetup so you don't have to invoke it, this is GradleSetup in a nutshell:
```vim
def Setup( dir: string )
    g:android_project_root = dir
    g:gradle_project_root  = dir
    g:gradle_bin           = dir .. '/gradlew'
```

### 2. Launch Vimspector

Here's the config:

```json
{
    "configurations": {
        "Remote android debugging": {
            "remote-request": "launch",
            "adapter": {
                "extends": "CodeLLDB",
                "variables": {
                    "AndroidApp": "com.package.application",
                    "AndroidDevice": "<device-serial-here>",
                    "ADBPort": "${ADBPort:5037}"
                },
                "launch": {
                    "delay": "2000m",
                    "remote": {
                        "host": "localhost",
                        "runCommands": [
                            [ "jdb", "-attach", "localhost:54321" ],
                            [
                                "adb",
                                "-P", "${ADBPort}",
                                "-s", "${AndroidDevice}",
                                "shell", "run-as", "${AndroidApp}",
                                "./lldb-server", "platform", "--listen", "\"*:54321\""
                            ]
                        ]
                    }
                }
            },
            "breakpoints": {
                "exception": {
                    "cpp_catch": "N",
                    "cpp_throw": "N"
                }
            },
            "variables": {
                "pid": {
                    "shell":  [
                        "adb", "shell", "ps",
                        "| grep \"${AndroidApp}\"",
                        "| tr -s ' '",
                        "| cut -d' ' -f2"
                    ]
                }
            },
            "configuration": {
                "environment": {
                    "ANDROID_ADB_SERVER_PORT": "${ADBPort}"
                },
                "initCommands": [
                    "platform select remote-android",
                    "platform connect connect://localhost:54321"
                ],
                "pid": "${pid}",
                "request": "attach"
            }
        }
    }
}
```

### Notes

If you get the "failed to get reply to handshake packet", you likely need a longer delay.

Also, the serial ID and the PID are in `g:android_target_device` and `g:android_target_app_pid` respectively, so you can use `<C-R>=g:<variable_name><CR>` to insert them wherever you need to.

If the `lldb-server` says that the address is already used, you can kill the server by either relaunching the app via `:AdbDebugger` or invoking `:call adb#StopLLDB()` directly.

## Configuration

Variables:

```vim
g:android_target_device         - ID of the target device
g:android_target_app            - name of the target app
g:android_project_root          - path to the android project root
g:android_lldb_armv8_server_bin - path to the armv8 version of lldb-server
g:android_lldb_armv7_server_bin - path to the armv7 version of lldb-server
g:gradle_bin                    - path to gradlew
g:gradle_project_root           - dirname of g:gradle_bin
g:adb_bin                       - path to adb, defaults to `$ANDROID_SDK/platform-tools/adb` or `which adb`
g:adb_port                      - port for adb to use, defaults to 5037
g:gradle_flags                  - flags that are injected into gradle invocations, default to `-p`
```

## Bonus

To stop a job press `<C-c>` in the job's buffer.

### WIP

To clear the logcat press `<leader>c` in the job's buffer.
