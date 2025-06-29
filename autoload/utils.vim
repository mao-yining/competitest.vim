vim9script

export def ReadTemplate(ft: string): list<string>
  const tpl_file = $"{g:competitest_config.template_dir}/{ft}.tpl"
  if filereadable(tpl_file)
    return readfile(tpl_file)
  endif
  return []
enddef

export def SafeWrite(lines: list<string>, fname: string): void
  try
    writefile(lines, fname)
  catch
    echoerr $'Failed to write {fname}: {v:exception}'
  endtry
enddef

# Add to existing utils.vim
export def SanitizeFilename(name: string): string
  # Remove invalid characters
  return substitute(name, '[\\/*?:"<>|]', '', 'g')->trim()
enddef
