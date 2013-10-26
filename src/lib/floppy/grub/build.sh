#!/bin/sh
cat stage1 stage2 /dev/zero | dd count=360 bs=1024 > grub.img
