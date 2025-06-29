vim9script

# 必须使用 export 导出函数
export def ReadTemplate(ft: string): list<string>
  const tpl_file = $"{g:competitest_config.template_dir}/{ft}.tpl"
  if filereadable(tpl_file)
    return readfile(tpl_file)
  endif
  return []
enddef

# 可以添加更多模板相关函数
export def TemplateExists(ft: string): bool
  return filereadable($"{g:competitest_config.template_dir}/{ft}.tpl")
enddef
