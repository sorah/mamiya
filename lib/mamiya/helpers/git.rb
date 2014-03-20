def git_ignored_files
  git_clean_out = `git clean -ndx`.lines
  prefix = /^Would (?:remove|skip repository) /

  if git_clean_out.any? { |_| prefix !~ _ }
    puts git_clean_out
    raise "`git clean -ndx` doesn't return line starting with 'Would remove' or 'Would skip'"
  end

  excludes = git_clean_out.grep(prefix).map{ |_| _.sub(prefix, '').chomp }
  if package_under
    excludes.grep(/^#{Regexp.escape(package_under)}/).map{ |_| _.sub(/^#{Regexp.escape(package_under)}\/?/, '') }
  else
    excludes
  end
end

if options[:exclude_git_clean_targets]
  build(:prepend) do
    set :exclude_from_package, exclude_from_package + git_ignored_files()
  end
end
