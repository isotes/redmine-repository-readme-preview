module RepositoryReadmePreview

	MARKDOWN_EXTENSIONS = %w[.md .markdown].freeze
	TEXTILE_EXTENSIONS = %w[.textile].freeze
	EXTENSION_PREFERENCE = (MARKDOWN_EXTENSIONS + TEXTILE_EXTENSIONS + [''] + %w[.txt .rdoc]).freeze

	class RepositoryReadmePreviewHookListener < Redmine::Hook::ViewListener
		def view_repositories_show_contextual(context = {})
			repository = context[:repository]
			request = context[:request]
			rev = request[:rev]
			path = request.params['path'] || ''

			readmes = (repository.entries(path, rev) || []).select { |f| f.name =~ /readme((\.).+)?/i }
			return '' if readmes.empty?

			readme = readmes.map { |f| [EXTENSION_PREFERENCE.index(File.extname(f.name).downcase) || 999, f.name.downcase, f] }.min[2]

			if readme.size > 50000
				return context[:controller].send(:render_to_string, {
					partial: 'repository/readme_preview',
					locals: {
						file_too_large: true,
						filename: File.basename(readme.path),
					}
				})
			end

			readme_text = Redmine::CodesetUtil.to_utf8_by_setting(repository.cat(readme.path, rev))

			format_name = ''
			if MARKDOWN_EXTENSIONS.include?(File.extname(readme.path))
				format_name = Redmine::WikiFormatting.format_names.find { |name| name.downcase.include?('markdown') }
			elsif TEXTILE_EXTENSIONS.include?(File.extname(readme.path))
				format_name = Redmine::WikiFormatting.format_names.find { |name| name.downcase.include?('textile') }
			end


			# Calculate the prefix for repository-internal links and images.
			# A repository may be accessed via: PROJECT/repository, PROJECT/repository/NAME, or PROJECT/repository/NAME/revisions/REV/show
			# Links and images work without specifying REV but not without specifying .../repository/NAME
			prefix = ''
			unless request.params.include?('rev')
				prefix = request.path + '/' + (request.params.include?('repository_id') ? '' : repository.identifier + '/')
			end

			context[:controller].send(:render_to_string, {
				partial: 'repository/readme_preview',
				locals: {
					html: fix_inline_links(Redmine::WikiFormatting.formatter_for(format_name).new(readme_text).to_html, prefix),
					file_too_large: false,
					filename: File.basename(readme.path),
				}
			})
		end

		def view_layouts_base_html_head(_context = {})
			stylesheet_link_tag(:plugin, plugin: 'repository_readme_preview')
		end

		def gsub_local_links!(string, regex)
			string.gsub!(regex) {
				m = Regexp.last_match
				m[:link].match(/\A\w+:/) ? m[0] : yield(m)
			}
		end

		def fix_inline_links(html, prefix)
			gsub_local_links!(html, /(?<pre><a href="(\.\.\/)*)(?<link>[^"]*)(?<post>"( title="[^"]*")? class="external">)/) { |m|
				m[:pre] + prefix + 'entry/' + m[:link] + '">'
			}
			gsub_local_links!(html, /(?<pre><img src="(\.\.\/)*)(?<link>[^"]*)(?<post>"( alt="[^"]*")?( title="[^"]*")? \/>)/) { |m|
				STDERR.write("#{m[:link]}  -- #{prefix + 'raw/' + m[:link]}\n")
				m[:pre] + prefix + 'raw/' + m[:link] + m[:post]
			}
			html
		end
	end
end
