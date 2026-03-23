# MPAS-Model Build Notes: Scorpio / ADIOS2 I/O Backend Support

## Overview

This document describes the modifications made to MPAS-Model to support the
[Scorpio](https://github.com/E3SM-Project/scorpio) library as an alternative I/O
backend, including ADIOS2 support. It also documents the new memory-monitoring
utility and the available build configurations on NCAR Derecho.

---

## New Files

### `src/framework/proc_status_vm.F90` and `src/core_atmosphere/proc_status_vm.F`

Fortran module `proc_status_vm` providing per-process memory diagnostics by
reading Linux `/proc/self/status` and `/proc/self/smaps`.

**Public interface:**

| Symbol | Type | Description |
|---|---|---|
| `VmStatusInfo` | derived type | Holds all `Vm*` fields from `/proc/self/status` (in kB, defaulting to -1) |
| `get_vm_status(info)` | subroutine | Populates a `VmStatusInfo` struct from `/proc/self/status` |
| `prt_vm_status(location, rank)` | subroutine | Prints a formatted table of all VM fields with a location tag and MPI rank |
| `get_smaps_status()` | subroutine | Scans `/proc/self/smaps` and prints heap/anonymous regions with RSS utilization below 75% |
| `log_addr(msg, addr, file, line)` | subroutine | Logs a memory address in hex with source file/line context |
| `shr_malloc_trim()` | subroutine | Calls C `malloc_trim(0)` to release free memory back to the OS |
| `shr_count_malloc(msg)` | subroutine | Prints NVHPC allocator debug info (no-op on other compilers) |

**`VmStatusInfo` fields** (all integers, kB units):
`VmPeak`, `VmSize`, `VmLck`, `VmPin`, `VmHWM`, `VmRSS`, `VmData`,
`VmStk`, `VmExe`, `VmLib`, `VmPTE`, `VmPMD`, `VmSwap`, `HugetlbPages`

**Note:** The two files are identical in content; the `.F90` version lives under
`src/framework/` and the `.F` version under `src/core_atmosphere/`.

---

## Modified Framework Files

### `src/framework/mpas_io_types.inc`

Added ADIOS2 as a new I/O format constant:

```fortran
integer, parameter :: MPAS_IO_ADIOS = 14
```

This value (`14`) matches the Scorpio `PIO_iotype_adios` constant.

### `src/framework/mpas_io.F`

Key changes:

- **Scorpio compatibility**: Added `#ifdef MPAS_SCORPIO_SUPPORT` guards to
  conditionally use Scorpio-specific modules (`spio_err`) instead of legacy PIO
  modules (`piolib_mod`, `pionfatt_mod`).
- **Buffer size parameter**: `MPAS_io_init` now accepts an optional
  `io_buffer_size` argument (8-byte integer, bytes) which is passed to
  `pio_set_buffer_size_limit` before PIO initialization.
- **Aggregator count**: The `num_aggregator` argument to `PIO_init` changed from
  hardcoded `0` to `4`.
- **ADIOS2 I/O type**: When `ioformat == MPAS_IO_ADIOS`, the PIO iotype is set
  to `PIO_iotype_adios` (requires `MPAS_SCORPIO_SUPPORT`).
- **Log level**: After initialization, Scorpio log level is set to 0 via
  `pio_set_log_level(0)`; PIO log level is set to 2 via `PIO_set_log_level(2)`.

### `src/framework/mpas_framework.F`

- Reads two new namelist config options: `config_num_aggregator` and
  `config_buffer_size`.
- Converts `config_buffer_size` (integer, MB) to bytes (`kind=8`) before passing
  to `MPAS_io_init`.
- Logs the aggregator count alongside task count and stride.

### `src/framework/mpas_stream_manager.F`

- Exports `MPAS_IO_ADIOS` from the `mpas_io` module.
- Maps XML stream `io_type` integer code `14` to `MPAS_IO_ADIOS`.

### `src/framework/xml_stream_parser.c`

- Recognizes `"adios"` as a valid `io_type` string in stream XML files (both
  input and output stream sections, and the mesh stream attribute reader).
- Maps `"adios"` → `i_iotype = 14`.
- Logs `"adios2"` as the I/O type label in the run log.
- Added debug `printf` statements for `iotype` and `xml_iotype` (useful for
  verifying stream XML parsing).

### `src/core_atmosphere/mpas_atm_core.F`

- Uses `proc_status_vm` module to call `prt_vm_status('MPAS:after-IO-write', rank)`
  after each output stream write in both the time-stepping loop and the
  initialize/finalize loop. This prints per-rank VM memory statistics immediately
  after I/O to monitor memory usage during model runs.

### `src/core_atmosphere/Registry.xml`

Contains the namelist definitions for the two new config options:

- `config_num_aggregator` — number of PIO aggregator tasks
- `config_buffer_size` — PIO buffer size in MB

### `src/core_atmosphere/Makefile` and `src/framework/Makefile`

Updated to compile `proc_status_vm.F` / `proc_status_vm.F90` and link against
Scorpio libraries when `MPAS_SCORPIO_SUPPORT` is defined.

---

## Build Configurations

Three Makefile variants are provided. Copy the desired one to `Makefile` before
building.

| File | I/O Backend | Notes |
|---|---|---|
| `Makefile.orig` | ParallelIO (PIO) | Standard MPAS build using the system `parallelio` module |
| `Makefile.pnetcdf` | Scorpio + pnetcdf | Uses Scorpio's pnetcdf backend; requires `$PIO` set to a Scorpio install with `flib` (not `flib_legacy`) |
| `Makefile.adios2` | Scorpio + ADIOS2 | Uses Scorpio's ADIOS2 backend; adds `-lstdc++` to C/CXX link flags |

**Key difference between Makefile.adios2 and Makefile.orig/pnetcdf:**
`Makefile.adios2` adds `-lstdc++` to `CFLAGS_OPT` and `CXXFLAGS_OPT` to satisfy
ADIOS2 C++ linkage requirements.

---

## Build Scripts

### `build_mpas_env24.12.sh` — Build with PIO (standard)

Builds MPAS using the system `parallelio` module on Derecho with the
`ncarenv/24.12` environment.

```bash
# Environment setup
module load gcc
module remove hdf5 netcdf
module load parallel-netcdf netcdf-mpi
module load parallelio

# Select standard PIO Makefile
cp Makefile.orig Makefile

# Build both cores
make -j8 gnu CORE=init_atmosphere AUTOCLEAN=true
make -j8 gnu CORE=atmosphere AUTOCLEAN=true
```

Optional: set `$GPTL` and add `TIMER_LIB=gptl` to enable GPTL timing.

### `build_mpas_adios2_25.1.sh` — Build with Scorpio + ADIOS2

Builds MPAS using a custom Scorpio installation with ADIOS2 backend.

```bash
# Environment setup
module load gcc
module remove hdf5 netcdf
module load parallel-netcdf netcdf-mpi

# Select ADIOS2 Makefile
cp Makefile.adios2 Makefile

# Point to custom Scorpio and ADIOS2 installations
export ADIOS2_DIR=/glade/work/haiyingx/ADIOS2/install_gcc_chunk/
export PIO=/glade/derecho/scratch/haiyingx/scorpio-scorpio-v1.8.0/install_adios2_25.1_8step_32MB/

# Build both cores
make -j8 gnu CORE=init_atmosphere AUTOCLEAN=true
make -j8 gnu CORE=atmosphere AUTOCLEAN=true
```

---

## Enabling ADIOS2 I/O at Runtime

In the stream XML configuration file, set `io_type="adios2"` on any stream:

```xml
<stream name="output"
        io_type="adios2"
        ...>
```

The parser matches any string containing `"adios"` (case-sensitive) and routes
it to `MPAS_IO_ADIOS` (code 14).

---

## Memory Monitoring Output

When `prt_vm_status` is called, it prints a two-line table to stdout:

```
    VmPeak    VmSize     VmLck     VmPin     VmHWM     VmRSS    VmData     VmStk
    123456    120000         0         0    100000     95000     80000      1024  ...  [VmStatus] MPAS:after-IO-write       42
```

All values are in kB. The tag and MPI rank appear at the end of the value row.
