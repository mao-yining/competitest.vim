vim9script

# Test for :CompetiTest run in a C file.
def g:Test_Runner_c()
	tabnew ./main.c
	:CompetiTest run
	sleep 1
	if !filereadable("main.exe")
		echoerr "Compile Failed"
	else
		delete("main.exe")
	endif
enddef

# vim: shiftwidth=2 softtabstop=2 noexpandtab
