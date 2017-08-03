module IncrementalRegenerationFixer
  def IncrementalRegenerationFixer.init(site)
    if site.regenerator.disabled?
      return
    end

    # This is a fix for the following bug:
    #
    #   https://github.com/jekyll/jekyll/issues/4112
    #
    # To work around it, we'll remember groups of interdependent files;
    # if any of the files in a group changes, we'll make sure to
    # regenerate *all* the files in that group.
    interdependent_files = []

    config = site.config['incremental_regeneration_fixer']
    if not config
      raise ("You probably want to specify incremental_regeneration_fixer " +
             "config if you want to use this plugin")
    end

    globs = config['interdependent_files']
    if not globs
      return
    end

    for glob in globs
      group = Dir["#{site.source}/#{glob}"]
      if group.length == 0
        raise ("The path '#{glob}' contains no files! Please fix " +
               "interdependent_files in your site's _config.yml.")
      end
      interdependent_files << group
    end

    for group in interdependent_files
      for srcfile in group
        if site.regenerator.modified? srcfile
          for dependent_file in group
            site.regenerator.force dependent_file
          end
          break
        end
      end
    end
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  IncrementalRegenerationFixer.init(site)
end
