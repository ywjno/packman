class Boost < PACKMAN::Package
  url 'https://downloads.sourceforge.net/project/boost/boost/1.57.0/boost_1_57_0.tar.bz2'
  sha1 'e151557ae47afd1b43dc3fac46f8b04a8fe51c12'
  version '1.57.0'

  # Toolsets supported by Boost:
  #   acc, como, darwin, gcc, intel-darwin, intel-linux, kcc, kylix,
  #   mipspro, mingw(msys), pathscale, pgi, qcc, sun, sunpro, tru64cxx, vacpp

  option :use_cxx11 => true

  binary do
    compiled_on :Mac, '=~ 10.10'
    compiled_by :cxx => [ :gnu, '=~ 5.2' ]
    sha1 'c30efd5f5d0699f11b654410b0549f091eaf302a'
    version '1.57.0'
  end

  def install
    cxx_compiler = PACKMAN.compiler(:cxx).command
    compiler_flags = PACKMAN.compiler(:cxx).default_flags[:cxx]
    toolset = PACKMAN.compiler(:cxx).vendor
    # Rename toolset according to Boost.Build rule.
    if toolset == :intel
      # Lower version (e.g. 11.1) has issues to compile Boost.
      if PACKMAN.compiler(:cxx).version <= '11.1'
        PACKMAN.report_error "Intel compiler is too old to compile Boost! See "+
          "https://software.intel.com/en-us/articles/boost-1400-compilation-error-while-building-with-intel-compiler/"
      end
      if PACKMAN.mac?
        toolset << '-darwin'
      elsif PACKMAN.linux?
        toolset << '-linux'
      end
    elsif toolset == :gnu
      if PACKMAN.mac?
        toolset = 'darwin'
      elsif PACKMAN.linux?
        toolset = 'gcc'
      end
    elsif toolset == :llvm
      if PACKMAN.mac?
        toolset = 'clang-darwin'
      elsif PACKMAN.linux?
        toolset = 'clang-linux'
      end
    end
    compiler_flags << ' -std=c++11' if use_cxx11?
    open('user-config.jam', 'w') do |file|
      file << "using #{toolset} : : #{cxx_compiler} : <compilerflags>#{compiler_flags}"
    end
    args = %W[
      --prefix=#{prefix}
      --with-toolset=#{toolset}
    ]
    PACKMAN.run './bootstrap.sh', *args
    args = %W[
      --prefix=#{prefix}
      -q
      -d2
      -j2
      toolset=#{toolset}
      variant=release
      install
    ]
    # Check if python development files are installed.
    if not PACKMAN.os_installed? ['python-dev', 'python-devel']
      PACKMAN.report_warning 'Python development files are not installed, '+
        'so Boost will be installed without python library.'
      PACKMAN.report_warning "If you really need that library, cancel and "+
        "install #{PACKMAN.red 'python-dev'} or #{PACKMAN.red 'python-devel'}."
      args << '--without-python'
    end
    if PACKMAN.mac? and toolset =~ /clang/
      # Boost.Log cannot be built using Apple GCC at the moment. Disabled
      # on such systems.
      args << "--without-log"
    end
    PACKMAN.run './b2', *args
  end
end
