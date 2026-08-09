#!/usr/bin/env bash
sudo pacman -S --needed \
  rocm-hip-sdk \
  rocm-opencl-runtime \
  rocm-core \
  hip-runtime-amd

echo '/opt/rocm/lib' | sudo tee /etc/ld.so.conf.d/rocm.conf
sudo ldconfig
