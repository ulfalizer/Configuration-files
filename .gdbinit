set prompt \ \ (gdb)\ 
# set target-wide-charset UTF16
# set case-sensitive off

# C/C++ stuff

define pp
    print *$arg0
end

set print object
set print pretty
set print vtbl

# Site-specific settings

source ~/conf/gdblocal
