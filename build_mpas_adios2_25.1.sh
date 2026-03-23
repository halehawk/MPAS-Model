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

#if use adios2
cp Makefile.adios2 Makefile

#install_pnetcdf_flib which is scorpio flib not flib_legacy can be used in this script
#cp Makefile.pnetcdf Makefile
export ADIOS2_DIR=/glade/work/haiyingx/ADIOS2/install_gcc_chunk/
export PIO=/glade/derecho/scratch/haiyingx/scorpio-scorpio-v1.8.0/install_adios2_25.1_8step_32MB/


#if want to use gptl timing, enable my gptl installation and use it in the make
#export GPTL=/glade/u/apps/derecho/24.12/spack/opt/spack/gptl/8.1.1/cray-mpich/8.1.29/gcc/12.4.0/idx7
#export GPTL=/glade/derecho/scratch/haiyingx/GPTL/install_mpas



#make -j8 gnu CORE=init_atmosphere AUTOCLEAN=true TIMER_LIB=gptl
#make -j8 gnu CORE=atmosphere AUTOCLEAN=true TIMER_LIB=gptl
make -j8 gnu CORE=init_atmosphere AUTOCLEAN=true
make -j8 gnu CORE=atmosphere AUTOCLEAN=true
