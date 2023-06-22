help([[
Load environment to build post on hera
]])

-- cmake_ver=os.getenv("cmake_ver") or "3.20.1"
-- load(pathJoin("cmake", cmake_ver))

load("spack-stack")
load("stack-intel/2021.6.0")
load("stack-openmpi/4.1.5")

load("hdf5/1.10.6")
load("netcdf-c/4.7.4")
load("netcdf-fortran/4.5.4")
load("jasper/2.0.25")
load("libpng/1.6.37")
load("zlib/1.2.11")
load("g2/3.4.5")
load("g2tmpl/1.10.2")

load("bacio/2.4.1")
load("ip/3.3.3")
load("sp/2.3.3")
load("crtm/2.4.0")
load("w3emc/2.9.2")
load("nemsio/2.5.4")
load("sigio/2.3.2")
load("sfcio/1.4.1")
load("wrf_io/1.2.0")

setenv("CC","mpicc")
setenv("CXX","mpicpc")
setenv("FC","mpifort")

whatis("Description: post build environment")
