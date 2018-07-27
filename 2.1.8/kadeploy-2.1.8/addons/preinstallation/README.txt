init.ash		     : Main script
partition.ash		     : partitioning script
preinstall.conf          : configuration file used by the scripts
fdisk.txt		     : script fdisk

to build preinstallation archive, in the current directory, do:
tar -zcvf /tmp/preinstall.tgz ./

your preinstall is now in /tmp ready to use!

################################################################################

If you want to do some hacking, you can add many features, just remember to limit your binaries needs to what is embedded in the deployment kernel.
