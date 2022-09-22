vim9script

export def SetPort( port: string )
    g:jdb_port = str2nr(port)
enddef

defcompile
