module PACKMAN
  def self.collect_packages(options = [])
    options = [options] if not options.class == Array
    package_root = ConfigManager.package_root
    PACKMAN.mkdir(package_root)
    if not ConfigManager.use_ftp_mirror == 'no'
      report_notice "Use FTP mirror #{Tty.blue}#{ConfigManager.use_ftp_mirror}#{Tty.reset}."
    end
    # Download packages to package_root.
    collect_all = ( CommandLine.has_option? '-all' or options.include? :all )
    if collect_all
      package_names = Dir.glob("#{ENV['PACKMAN_ROOT']}/packages/*.rb").map { |f| File.basename(f).gsub('.rb', '').capitalize }
      package_names.delete('Packman_packages')
    else
      package_names = ConfigManager.packages.keys
    end
    package_names.each do |package_name|
      if not collect_all
        install_spec = ConfigManager.packages[package_name]
        package = PACKMAN::Package.instance package_name, install_spec
        download_package(package_root, package)
      else
        PACKMAN::Package.all_instances(package_name).each do |package|
          download_package(package_root, package)
        end
      end
    end
  end

  def self.download_package(package_root, package, is_recursive = false)
    # Recursively download dependency packages.
    package.dependencies.each do |depend|
      depend_package_name = depend.capitalize
      if not ConfigManager.packages.keys.include? depend_package_name
        depend_package = PACKMAN::Package.instance depend_package_name
        download_package(package_root, depend_package, true)
      end
    end
    # Skip package that is provided by system.
    return if package.labels.include?('should_provided_by_system')
    # Check if there is any patch to download.
    patch_counter = -1
    package.patches.each do |patch|
      patch_counter += 1
      url = patch.url
      patch_file_name = "#{package.class}.patch.#{patch_counter}"
      patch_file_path = "#{package_root}/#{patch_file_name}"
      if File.exist? patch_file_path
        if PACKMAN.sha1_same? patch_file_path, patch.sha1
          next
        end
      end
      report_notice "Download patch #{url}."
      if not ConfigManager.use_ftp_mirror == 'no'
        url = "#{ConfigManager.use_ftp_mirror}/#{patch_file_name}"
      end
      PACKMAN.download(package_root, url, patch_file_name)
    end
    # Check if there is any attachment to download.
    package.attachments.each do |attach|
      url = attach.url
      attach_file_name = "#{File.basename(URI.parse(url).path)}"
      attach_file_path = "#{package_root}/#{attach_file_name}"
      if File.exist? attach_file_path
        if PACKMAN.sha1_same? attach_file_path, attach.sha1
          next
        end
      end
      report_notice "Download attachment #{url}."
      if not ConfigManager.use_ftp_mirror == 'no'
        url = "#{ConfigManager.use_ftp_mirror}/#{attach_file_name}"
      end
      PACKMAN.download(package_root, url, attach_file_name)
    end
    # Download current package.
    if package.respond_to? :url
      package_file_path = "#{package_root}/#{package.filename}"
      if File.exist? package_file_path
        return if PACKMAN.sha1_same? package_file_path, package.sha1
      end
      PACKMAN.report_notice "Download package #{Tty.red}#{package.class}#{Tty.reset}."
      url = package.url
      if not ConfigManager.use_ftp_mirror == 'no'
        url = "#{ConfigManager.use_ftp_mirror}/#{package.filename}"
      end
      PACKMAN.download(package_root, url, package.filename)
    elsif package.respond_to? :git
      package_dir_path = "#{package_root}/#{package.dirname}"
      if Dir.exist? package_dir_path
        return if PACKMAN.sha1_same? package_dir_path, package.sha1
      end
      PACKMAN.report_notice "Download package #{Tty.red}#{package.class}#{Tty.reset}."
      if not ConfigManager.use_ftp_mirror == 'no'
        url = "#{ConfigManager.use_ftp_mirror}/#{package.dirname}"
        PACKMAN.download(package_root, url, package.dirname)
      else
        PACKMAN.git_clone(package_root, package.git, package.tag, package.dirname)
      end
    end
  end
end
