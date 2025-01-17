#!/bin/bash

# Copyright 2019-2020 Maxence Thevenet, Axel Huebl
#
# This file is part of WarpX.
#
# License: BSD-3-Clause-LBNL
#
# Refs.:
#   https://jsrunvisualizer.olcf.ornl.gov/?s4f0o11n6c7g1r11d1b1l0=
#   https://docs.olcf.ornl.gov/systems/summit_user_guide.html#cuda-aware-mpi

#BSUB -P <allocation ID>
#BSUB -W 00:10
#BSUB -nnodes 2
#BSUB -alloc_flags smt4
#BSUB -J WarpX
#BSUB -o WarpXo.%J
#BSUB -e WarpXe.%J

# make output group-readable by default
umask 0027

# fix problems with collectives since RHEL8 update: OLCFHELP-3545
# disable all the IBM optimized barriers and drop back to HCOLL or OMPI's barrier implementations
export OMPI_MCA_coll_ibm_skip_barrier=true

# libfabric 1.6+: limit the visible devices
# Needed for ADIOS2 SST staging/streaming workflows since RHEL8 update
#   https://github.com/ornladios/ADIOS2/issues/2887
#export FABRIC_IFACE=mlx5_0   # ADIOS SST: select interface (1 NIC on Summit)
#export FI_OFI_RXM_USE_SRX=1  # libfabric: use shared receive context from MSG provider

# ROMIO has a hint for GPFS named IBM_largeblock_io which optimizes I/O with operations on large blocks
export IBM_largeblock_io=true

# MPI-I/O: ROMIO hints for parallel HDF5 performance
export OMPI_MCA_io=romio321
export ROMIO_HINTS=./romio-hints
#   number of hosts: unique node names minus batch node
NUM_HOSTS=$(( $(echo $LSB_HOSTS | tr ' ' '\n' | uniq | wc -l) - 1 ))
cat > romio-hints << EOL
   romio_cb_write enable
   romio_ds_write enable
   cb_buffer_size 16777216
   cb_nodes ${NUM_HOSTS}
   EOL

# OpenMP: 1 thread per MPI rank
export OMP_NUM_THREADS=1

# run WarpX
jsrun -r 6 -a 1 -g 1 -c 7 -l GPU-CPU -d packed -b rs --smpiargs="-gpu" <path/to/executable> <input file> > output.txt
