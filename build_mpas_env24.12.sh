module load gcc
module remove hdf5 netcdf
module load parallel-netcdf
module load netcdf-mpi
#module load conda
#conda activate npl
#export PYTHONPATH=/glade/campaign/mmm/wmr/mpas_tutorial/python_scripts
#module load ncview
#export PATH=/glade/campaign/mmm/wmr/mpas_tutorial/metis/bin:${PATH}

make clean CORE=atmosphere
make clean CORE=init_atmosphere

#if run mpas pio mode, enable this module load
cp Makefile.orig Makefile
module load parallelio
#export PIO=/glade/work/haiyingx/ParallelIO_012026/install_gcc_logging
#export LD_LIBRARY_PATH=/glade/work/haiyingx/ParallelIO_012026/install_gcc_logging/lib:$LD_LIBRARY_PATH

#if use smiol
#cp Makefile.orig Makefile

#install_pnetcdf_flib which is scorpio flib not flib_legacy can be used in this script
#cp Makefile.pnetcdf Makefile
#export PIO=/glade/derecho/scratch/haiyingx/scorpio-scorpio-v1.8.0/install_pnetcdf_flib/
##cannot use install_adios2 in this script
##export PIO=/glade/derecho/scratch/haiyingx/scorpio-scorpio-v1.8.0/install_adios2/


#if want to use gptl timing, enable my gptl installation and use it in the make
#export GPTL=/glade/u/apps/derecho/24.12/spack/opt/spack/gptl/8.1.1/cray-mpich/8.1.29/gcc/12.4.0/idx7
#export GPTL=/glade/derecho/scratch/haiyingx/GPTL/install_mpas



#make -j8 gnu CORE=init_atmosphere AUTOCLEAN=true TIMER_LIB=gptl
#make -j8 gnu CORE=atmosphere AUTOCLEAN=true TIMER_LIB=gptl
make -j8 gnu CORE=init_atmosphere AUTOCLEAN=true
make -j8 gnu CORE=atmosphere AUTOCLEAN=true
