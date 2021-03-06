require 'formula'

def complete?
  ARGV.include? "--complete"
end

def postgres?
  ARGV.include? "--with-postgres"
end

def mysql?
  ARGV.include? "--with-mysql"
end

def no_python?
  ARGV.include? "--without-python"
end

class Gdal <Formula
  url 'http://download.osgeo.org/gdal/gdal-1.7.3.tar.gz'
  head 'https://svn.osgeo.org/gdal/trunk/gdal', :using => :svn
  homepage 'http://www.gdal.org/'
  md5 'c4673970bd2285032de9ae9bbd82754a'

  depends_on 'jpeg'
  depends_on 'giflib'
  depends_on 'proj'
  depends_on 'geos'

  if complete?
    # Raster libraries
    depends_on "netcdf" # Also brings in HDF5
    depends_on "jasper" # May need a keg-only GeoJasPer library as this one is
                        # not geo-spatially enabled.

    # Vector libraries
    depends_on "unixodbc" # OS X version is not complete enough
    depends_on "libspatialite"
    depends_on "xerces-c"
  end

  depends_on "postgresql" if postgres?
  depends_on "mysql" if mysql?

  def options
    [
      ['--complete', 'Use additional Homebrew libraries to provide more drivers.'],
      ['--with-postgres', 'Specify PostgreSQL as a dependency.'],
      ['--with-mysql', 'Specify MySQL as a dependency.'],
      ['--without-python', 'Build without Python support (disables a lot of tools).']
    ]
  end

  def get_configure_args
    args = [
      # Base configuration.
      "--disable-debug",
      "--with-local=#{prefix}",
      "--with-threads",
      "--with-libtool",

      # GDAL native backends.
      "--with-libtiff=internal", # For bigTIFF support
      "--with-geotiff=internal",
      "--with-pcraster=internal",
      "--with-pcidsk=internal",
      "--with-bsb",
      "--with-grib",
      "--with-pam",

      # Backends supported by OS X.
      "--with-libz=/usr",
      "--with-png=/usr/X11",
      "--with-expat=/usr",
      "--with-curl=/usr/bin/curl-config",
      "--with-sqlite3=/usr",

      # Default Homebrew backends.
      "--with-jpeg=#{HOMEBREW_PREFIX}",
      "--with-jpeg12",
      "--with-gif=#{HOMEBREW_PREFIX}",

      # GRASS backend explicitly disabled.  Creates a chicken-and-egg problem.
      # Should be installed seperately after GRASS installation using the
      # official GDAL GRASS plugin.
      "--without-grass",
      "--without-libgrass"
    ]

    # Optional library support for additional formats.
    if complete?
      args.concat [
        "--with-netcdf=#{HOMEBREW_PREFIX}",
        "--with-hdf5=#{HOMEBREW_PREFIX}",
        "--with-jasper=#{HOMEBREW_PREFIX}",
        "--with-odbc=#{HOMEBREW_PREFIX}",
        "--with-spatialite=#{HOMEBREW_PREFIX}",
        "--with-xerces=#{HOMEBREW_PREFIX}"
      ]
    else
      args.concat [
        "--without-cfitsio",
        "--without-netcdf",
        "--without-ogdi",
        "--without-hdf4",
        "--without-hdf5",
        "--without-jasper",
        "--without-xerces",
        "--without-epsilon",
        "--without-spatialite",
        "--with-dods-root=no",

        # The following libraries are either proprietary or available under
        # non-free licenses.  Interested users will have to install such
        # software manually.
        "--without-msg",
        "--without-mrsid",
        "--without-jp2mrsid",
        "--without-kakadu",
        "--without-fme",
        "--without-ecw",
        "--without-dwgdirect"
      ]
    end

    # Database support.
    args << "--without-pg" unless postgres?
    args << "--without-mysql" unless mysql?
    args << "--without-sde"    # ESRI ArcSDE databases
    args << "--without-ingres" # Ingres databases
    args << "--without-oci"    # Oracle databases
    args << "--without-idb"    # IBM Informix DataBlades

    # Hombrew-provided databases.
    args << "--with-pg=#{HOMEBREW_PREFIX}/bin/pg_config" if postgres?
    args << "--with-mysql=#{HOMEBREW_PREFIX}/bin/mysql_config" if mysql?

    args << "--without-python" # Installed using a seperate set of
                                         # steps so that everything winds up
                                         # in the prefix.

    # Scripting APIs that have not been re-worked to respect Homebrew prefixes.
    #
    # Currently disabled as they install willy-nilly into locations outside of
    # the Hombrew prefix.  Enable if you feel like it, but uninstallation may be
    # a manual affair.
    #
    # TODO: Fix installation of script bindings so they install into the
    # Homebrew prefix.
    args << "--without-perl"
    args << "--without-php"
    args << "--without-ruby"

    return args
  end

  def install
    system "./configure", "--prefix=#{prefix}", *get_configure_args
    system "make"
    system "make install"

    unless no_python?
      # If setuptools happens to be installed, setup.py will cowardly refuse to
      # install to anywhere that is not on the PYTHONPATH.
      #
      # Really setuptools, we're all consenting adults here...
      python_lib = lib + "python"
      ENV.append 'PYTHONPATH', python_lib

      # setuptools is also apparently incapable of making the directory it's
      # self
      python_lib.mkpath

      # `python-config` may try to talk us into building bindings for more
      # architectures than we really should.
      if snow_leopard_64?
        ENV.append_to_cflags '-arch x86_64'
      else
        ENV.append_to_cflags '-arch i386'
      end

      Dir.chdir 'swig/python' do
        system "python", "setup.py", "install_lib", "--install-dir=#{python_lib}"
        bin.install Dir['scripts/*']
      end
    end
  end

  unless no_python?
    def caveats
      <<-EOS
This version of GDAL was built with Python support.  In addition to providing
modules that makes GDAL functions available to Python scripts, the Python
binding provides ~18 additional command line tools.  However, both the Python
bindings and the additional tools will be unusable unless the following
directory is added to the PYTHONPATH:
    #{HOMEBREW_PREFIX}/lib/python
      EOS
    end
  end
end
