vim9script
import autoload "../autoload/competitest/utils.vim"
def g:Test_FormatStringModifiers()
  const modifiers = {
    "NAME": "John",
    "AGE": "30",
    "CITY": "New York",
    "get_year": (_) => "2026",
    "get_uppercase": (name: string): string => name->toupper(),
  }

  var result = utils.FormatStringModifiers("Hello World", modifiers)
  result->assert_equal("Hello World")

  result = utils.FormatStringModifiers("Hello $(NAME)", modifiers)
  result->assert_equal("Hello John")

  result = utils.FormatStringModifiers("$(NAME) is $(AGE) years old from $(CITY)", modifiers)
  result->assert_equal("John is 30 years old from New York")

  result = utils.FormatStringModifiers("Year: $(get_year)", modifiers)
  result->assert_equal("Year: 2026")

  result = utils.FormatStringModifiers("$(get_uppercase)", modifiers, "hello")
  result->assert_equal("HELLO")

  result = utils.FormatStringModifiers("$(NAME) in $(get_uppercase)", modifiers, "new york")
  result->assert_equal("John in NEW YORK")

  result = utils.FormatStringModifiers("Price: $()100", {"": "$"})
  result->assert_equal("Price: $100")

  result = utils.FormatStringModifiers("The $(NAME) $(CITY) project", modifiers)
  result->assert_equal("The John New York project")

  try
    utils.FormatStringModifiers("Hello $(UNKNOWN)", modifiers)
  catch
    assert_exception("FormatStringModifiers: unrecognized modifier $(UNKNOWN)")
  endtry

  try
    utils.FormatStringModifiers("Hello $(NAME", modifiers)
  catch
    assert_exception("FormatStringModifiers: unclosed modifier")
  endtry

  try
    utils.FormatStringModifiers("Price: $100", modifiers)
  catch
    assert_exception("FormatStringModifiers: '$' isn't followed by '('")
  endtry

  try
    utils.FormatStringModifiers("Price: $", modifiers)
  catch
    assert_exception("FormatStringModifiers: '$' at end without '('")
  endtry

  try
    utils.FormatStringModifiers("Test $(NUM)", {NUM: 123})
  catch
    assert_exception("FormatStringModifiers: unrecognized modifier $(NUM)")
  endtry

  try
    utils.FormatStringModifiers("Test $()", {})
  catch
    assert_exception("FormatStringModifiers: unrecognized modifier $()")
  endtry

  result = utils.FormatStringModifiers("$(NAME)-$(AGE)_$(get_uppercase)", modifiers, "test")
  result->assert_equal("John-30_TEST")
enddef

def g:Test_EvalString()
  const filepath = "/home/user/projects/test.cpp"

  var result = utils.EvalString(filepath, "File: $(FNAME)")
  result->assert_equal("File: " .. fnamemodify(filepath, ":t"))

  result = utils.EvalString(filepath, "Base: $(FNOEXT)")
  result->assert_equal("Base: " .. fnamemodify(filepath, ":t:r"))

  result = utils.EvalString(filepath, "Ext: $(FEXT)")
  result->assert_equal("Ext: " .. fnamemodify(filepath, ":e"))

  result = utils.EvalString(filepath, "Path: $(FABSPATH)")
  result->assert_equal("Path: " .. filepath)

  result = utils.EvalString(filepath, "Dir: $(ABSDIR)")
  result->assert_equal("Dir: " .. fnamemodify(filepath, ":p:h"))

  result = utils.EvalString(filepath, "Home: $(HOME)")
  result->assert_equal("Home: " .. expand("~"))

  result = utils.EvalString(filepath, "$(FNOEXT).$(FEXT) in $(ABSDIR)")
  result->assert_equal("test.cpp in " .. fnamemodify(filepath, ":p:h"))

  try
    utils.EvalString(filepath, "Test $(UNKNOWN)")
  catch
    assert_exception("FormatStringModifiers:")
  endtry
enddef

def g:Test_Integration()
  var filepath = "/tmp/test.py"

  var result = utils.EvalString(filepath, "Processing $(FNAME) in $(ABSDIR)")
  result->assert_equal("Processing test.py in " .. fnamemodify(filepath, ":p:h"))

  filepath = "/path/to/file-with.dots.py"
  result = utils.EvalString(filepath, "$(FNOEXT).$(FEXT)")
  result->assert_equal("file-with.dots.py")

  filepath = "/home/user/README"
  result = utils.EvalString(filepath, "$(FNAME) - $(FEXT)")
  result->assert_equal("README - ")

  filepath = "/home/user/.vimrc"
  result = utils.EvalString(filepath, "$(FNAME).$(FEXT)")
  result->assert_equal(".vimrc.")
enddef
