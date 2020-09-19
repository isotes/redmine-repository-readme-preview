require_dependency 'repository_readme_preview'

Redmine::Plugin.register :repository_readme_preview do
	name 'Repository Readme Preview'
	author 'Robert Sauter'
	description 'Inline preview of Readme files in repository browser'
	version '0.1.0'
	url 'https://github.com/isotes/redmine-repository-readme-preview'
	author_url 'https://github.com/isotes'
end
