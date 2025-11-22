vim9script

# Test for :CompetiTest run in a C file.
def g:Test_Runner_c()
	assert_equal("\n[competitest] commands: subcommand r doesn't exist!", execute("CompetiTest r"))
	assert_equal("\n[competitest] run_testcases: need a valid testcase!", execute("CompetiTest run"))
	silent! edit Xmain.c
	var lines: list<string> =<< trim END
		#include "stdio.h"

		int main() {
				int a, b;
				scanf("%d%d", &a, &b);
				printf("%d", a + b);

				return 0;
		}
	END
	setline(1, lines)
	silent! write
	try
		:CompetiTest add_testcase
		setline(1, "1 2")
		feedkeys("\<Tab>", 'tx')
		setline(1, "3")
		feedkeys("s", 'tx')
		assert_equal("\n[competitest] run_testcases: testcase 1 doesn't exist!", execute("CompetiTest run 0 1"))
		tabclose
	finally
		CompetiTest delete_testcase 0
		delete("Xmain.c")
	endtry
enddef


def g:Test_Testcase_Actions()
	silent! edit XTest_Testcase_Actions.c
	assert_equal("\n[competitest] commands: add_testcase: exactly 0 sub-arguments required.", execute("CompetiTest add_testcase 0"))
	assert_equal("\n[competitest] picker: there's no testcase to pick from.", execute("CompetiTest edit_testcase"))
	assert_equal("\n[competitest] edit_testcase: testcase 0 doesn't exist!", execute("CompetiTest edit_testcase 0"))
	:CompetiTest add_testcase
	setline(1, "1 2")
	feedkeys("\<Tab>", 'tx')
	setline(1, "3")
	feedkeys("s", 'tx')
	try
		assert_equal("", execute("CompetiTest edit_testcase"))
		assert_false(popup_list()->empty())
		assert_equal(" Edit a Testcase ", popup_getoptions(popup_list()[0]).title)
		normal x
		assert_equal("", execute("CompetiTest edit_testcase 0"))
		assert_equal("1 2", getline(1))
		feedkeys("\<Tab>", 'tx')
		assert_equal("3", getline(1))
		normal q
		assert_equal("\n[competitest] edit_testcase: testcase 1 doesn't exist!", execute("CompetiTest edit_testcase 1"))
		:CompetiTest add_testcase
		setline(1, "4 5")
		feedkeys("\<Tab>", 'tx')
		setline(1, "8")
		feedkeys("s", 'tx')

		# Delete Testcase 1
		assert_equal("", execute("CompetiTest delete_testcase"))
		assert_false(popup_list()->empty())
		assert_equal(" Delete a Testcase ", popup_getoptions(popup_list()[0]).title)
		feedkeys("j\<CR>", 'tx')
	finally
		CompetiTest delete_testcase 0
		assert_equal("\n[competitest] delete_testcase: testcase 1 doesn't exist!", execute("CompetiTest delete_testcase 1"))
	endtry
enddef
