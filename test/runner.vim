vim9script
# Script to run a unit tests
# The global variable TestName should be set to the name of the file
# containing the tests.
def LoadPlugin()
	filetype on
	set wildmenu
	# Set the $LSP_PROFILE environment variable to profile the LSP plugin
	var do_profile: bool = false
	if exists('$LSP_PROFILE')
		do_profile = true
	endif
	if do_profile
		# profile the LSP plugin
		profile start profile.txt
		profile! file */competitest/*
	endif
	source ../plugin/competitest.vim
enddef

def RunTests()
	set nomore
	set debug=beep
	delete('results.txt')

	# Get the list of test functions in this file and call them
	var fns: list<string> = execute('function /^Test_')
		->split("\n")
		->map("v:val->substitute('^def ', '', '')")
		->sort()
	if fns->empty()
		# No tests are found
		writefile(['No tests are found'], 'results.txt')
		return
	endif
	for f in fns
		v:errors = []
		v:errmsg = ''
		try
			:%bw!
			exe $'g:{f}'
		catch
			call add(v:errors, $'Error: Test {f} failed with exception {v:exception} at {v:throwpoint}')
		endtry
		if v:errmsg != ''
			call add(v:errors, $'Error: Test {f} generated error {v:errmsg}')
		endif
		if !v:errors->empty()
			writefile(v:errors, 'results.txt', 'a')
			writefile([$'{f}: FAIL'], 'results.txt', 'a')
		else
			writefile([$'{f}: pass'], 'results.txt', 'a')
		endif
	endfor
enddef

try
	LoadPlugin()
	exe $'source {g:TestName}'
	RunTests()
catch
	writefile(['FAIL: Tests in ' .. g:TestName .. ' failed with exception ' .. v:exception .. ' at ' .. v:throwpoint], 'results.txt', 'a')
endtry

qall!

# vim: shiftwidth=2 softtabstop=2 noexpandtab
