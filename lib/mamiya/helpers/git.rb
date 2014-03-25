require 'time'

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

def git_head
  git_show = `git show --pretty=fuller -s`
  commit, comment = git_show.split(/\n\n/, 2)

  {
    commit: commit.match(/^commit (.+)$/)[1],
    author: commit.match(/^Author:\s*(?<name>.+?) <(?<email>.+?)>$/).
      tap {|match| break Hash[match.names.map {|name| [name.to_sym, match[name]] }] },
    author_date: Time.parse(commit.match(/^AuthorDate:\s*(.+)$/)[1]),
    committer: commit.match(/^Commit:\s*(?<name>.+?) <(?<email>.+?)>$/).
      tap {|match| break Hash[match.names.map {|name| [name.to_sym, match[name]] }] },
    commit_date: Time.parse(commit.match(/^CommitDate:\s*(.+)$/)[1]),
  }
end

if options[:exclude_git_clean_targets]
  build(:prepend) do
    set :exclude_from_package, exclude_from_package + git_ignored_files()
  end
end

options[:add_commit_hash_to_package_name] = true unless options.key?(:add_commit_hash_to_package_name)
if options[:add_commit_hash_to_package_name]
  package_name do |candidate|
    candidate + [git_head[:commit]]
  end
end

options[:include_head_commit_to_meta] = true unless options.key?(:include_head_commit_to_meta)
if options[:include_head_commit_to_meta]
  package_meta do |candidate|
    candidate.merge(git: git_head())
  end
end
