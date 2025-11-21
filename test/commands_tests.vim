vim9script

# Test for :CompetiTest run in a C file.
def g:Test_Runner_c()
	tabnew ./main.c
	assert_equal(execute("CompetiTest r"), "\n[competitest] commands: subcommand r doesn't exist!")
	assert_equal(execute("feedkeys(\":CompetiTest r\\<Tab>\\<CR>\")", "t"), "")
	assert_equal(execute("CompetiTest run"), "")
enddef

# vim: shiftwidth=2 softtabstop=2 noexpandtab
