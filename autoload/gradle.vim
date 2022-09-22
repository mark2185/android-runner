vim9script

def CreateGradleCmd( cmd: list< string > ): list< string >
    return [
        g:gradle_bin,
        '-p',
        g:gradle_project_root,
        g:gradle_flags,
    ] + cmd
enddef

# if it starts with [a-z], it's a task
# this is used for autocompletion
export def GetTasks( arglead: string, cmdline: string, cursor_pos: number ): list< string >
    return systemlist( CreateGradleCmd( [ ':app:tasks' ] )->join() )
                ->filter( '!empty( v:val )' )
                ->filter( 'v:val =~# "^[a-z]"' )
                ->map( 'v:val->split("-")[0]->trim()' )
                ->map( '":app:" .. v:val' )
                ->filter( (_, v) => v =~# arglead )
enddef

export def Run( ...args: list< string > ): void
    if !executable( g:gradle_bin )
        echom printf("Gradle binary '%s' is not found.", g:gradle_bin )
        return
    endif

    cexpr CreateGradleCmd( args )
          ->join()
          ->systemlist()
          ->join("\n")
enddef

export def RunAsync( ...args: list< string > ): void
    if !executable( g:gradle_bin )
        echom printf("Gradle binary '%s' is not found.", g:gradle_bin )
        return
    endif

    # echom "I got: " .. string(args)
    job#Run( CreateGradleCmd( args ) )
enddef

export def Setup( dir: string ): void
    # trim '/' from the end
    const directory        = dir->trim( '/', 2 )
    g:android_project_root = directory
    g:gradle_project_root  = directory
    # TODO: validate
    g:gradle_bin           = g:gradle_project_root .. '/gradlew'
    g:adb_bin              = $ANDROID_SDK->trim( '/', 2 ) ..  '/platform-tools/adb'
enddef

defcompile
