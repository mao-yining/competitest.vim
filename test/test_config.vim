vim9script
import autoload "../autoload/competitest/config.vim"

# Test LoadLocalConfig function
def g:Test_LoadLocalConfig()
  var result: dict<any>
  const temp_dir = tempname()
  mkdir(temp_dir, "p")
  defer delete(temp_dir, "rf")

  const sub_dir = temp_dir .. "/subdir"
  mkdir(sub_dir, "p")

  # Test 1: No config file
  config.LoadLocalConfig(temp_dir)->assert_equal(null_dict)

  # Test 2: Config file in current directory
  const config_content =<< trim END
    {
      save_current_file: false,
      maximum_time: 3000,
      custom_setting: "test"
    }
  END
  writefile(config_content, temp_dir .. "/.competitest.vim")


  result = config.LoadLocalConfig(temp_dir)
  result.save_current_file->assert_equal(false)
  result.maximum_time->assert_equal(3000)
  result.custom_setting->assert_equal("test")

  # Test 3: Config file in parent directory
  result = config.LoadLocalConfig(sub_dir)
  result.save_current_file->assert_equal(false)
  result.maximum_time->assert_equal(3000)

  # Test 4: Invalid config file (not returning dict)
  writefile(["'string'"], temp_dir .. "/.competitest.vim")
  result = config.LoadLocalConfig(temp_dir)
  result->assert_equal(null_dict)
  execute("message")->split('\n')[-1]->assert_match('doesn''t return a dict.$')

  writefile(["ab c"], temp_dir .. "/.competitest.vim")
  result = config.LoadLocalConfig(temp_dir)
  execute("message")->split('\n')[-1]->assert_match('Undefined variable: ab$')

  # Test 5: Non-existent directory
  result = config.LoadLocalConfig("/non/existent/directory")
  result->assert_equal(null_dict)
enddef

def g:Test_LoadLocalConfigAndExtend()
  # Setup temporary directory with config
  const temp_dir = tempname()
  mkdir(temp_dir, "p")
  defer delete(temp_dir, "rf")

  const config_content =<< trim END
    {
      save_current_file: false,
      maximum_time: 4000,
      runner_ui: { open_when_compilation_fails: false }
    }
  END
  writefile(config_content, temp_dir .. "/.competitest.vim")

  # Create a buffer in the temp directory
  const test_file = temp_dir .. "/test.cpp"
  writefile(["int main() { return 0; }"], test_file)
  silent! edit `=test_file`
  const bufnr = bufnr()

  # Test 1: Load and extend from local config
  var result = config.LoadLocalConfigAndExtend(temp_dir, bufnr)

  # Should have local config values
  result.save_current_file->assert_equal(false)
  result.maximum_time->assert_equal(4000)

  # Should have merged runner_ui
  result.runner_ui.open_when_compilation_fails->assert_equal(false) # from local

  # Should have default values
  result.local_config_file_name->assert_equal(".competitest.vim")

  # Test 2: Without bufnr (use g:competitest_configs as base)
  g:competitest_configs.multiple_testing = 3
  result = config.LoadLocalConfigAndExtend(temp_dir)
  result.multiple_testing->assert_equal(3) # from global
  result.save_current_file->assert_equal(false) # from local
  result.maximum_time->assert_equal(4000) # from local

  # Test 3: With empty bufnr config
  setbufvar(bufnr, "competitest_configs", {})
  result = config.LoadLocalConfigAndExtend(temp_dir, bufnr)
  result.save_current_file->assert_equal(false)
  result.maximum_time->assert_equal(4000)
  result.multiple_testing->assert_equal(-1) # default value
enddef

def g:Test_LoadBufferConfig()
  # Setup temporary directory
  const temp_dir = tempname()
  mkdir(temp_dir, "p")
  defer delete(temp_dir, "rf")

  # Create config file
  const config_content =<< trim END
    {
      save_current_file: false,
      custom_buffer_setting: "loaded"
    }
  END
  writefile(config_content, temp_dir .. "/.competitest.vim")

  # Create test file and buffer
  const test_file = temp_dir .. "/test.py"
  writefile(["print('hello')"], test_file)
  silent! edit `=test_file`
  var bufnr = bufnr()

  setbufvar(bufnr, "competitest_configs", {})

  config.LoadBufferConfig(bufnr)

  const buf_config = getbufvar(bufnr, "competitest_configs")
  buf_config.save_current_file->assert_equal(false)
  buf_config.custom_buffer_setting->assert_equal("loaded")
  buf_config.local_config_file_name->assert_equal(".competitest.vim")
enddef

def g:Test_GetBufferConfig()
  const temp_dir = tempname()
  mkdir(temp_dir, "p")
  defer delete(temp_dir, "rf")

  writefile(["{ maximum_time: 500 }"], temp_dir .. "/.competitest.vim")

  const test_file = temp_dir .. "/test.rs"
  writefile(["fn main() {}"], test_file)
  silent! edit `=test_file`
  const bufnr = bufnr()

  const custom_config = { maximum_time: 1000, custom_value: "test" }
  setbufvar(bufnr, "competitest_configs", custom_config)
  var result = config.GetBufferConfig(bufnr)
  result.maximum_time->assert_equal(1000)
  result.custom_value->assert_equal("test")
enddef
