vim9script

def CreateGradleCmd( cmd: list< string > ): list< string >
    return [
        g:gradle_bin,
        '-p',
        g:gradle_project_root
    ] + cmd
enddef

# if it starts with [a-z], it's a task
# this is used for autocompletion
export def gradle#getTasks( arglead: string, cmdline: string, cursor_pos: number ): list< string >
    return systemlist( CreateGradleCmd( [ ':app:tasks' ] )->join() )
                ->filter( '!empty( v:val )' )
                ->filter( 'v:val =~# "^[a-z]"' )
                ->map( 'v:val->split("-")[0]->trim()' )
                ->map( '":app:" .. v:val' )
                ->filter( (_, v) => v =~# arglead )
enddef

export def gradle#runAsync( ...args: list< string > ): void
    if !executable( g:gradle_bin )
        echom printf('Gradle binary %s is not found.', g:gradle_bin )
    endif

    cexpr CreateGradleCmd( args )
          ->join()
          ->systemlist()
          ->join("\n")
enddef

export def gradle#run( ...args: list< string > ): void
    if !executable( g:gradle_bin )
        echom printf('Gradle binary %s is not found.', g:gradle_bin )
    endif

    # echom "I got: " .. string(args)
    job#run( CreateGradleCmd( args ) )
enddef

defcompile
