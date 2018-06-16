# kvm-backup
All domains backup for KVM/QEMU

Use at your own risk! This is in early alpha and hasn't been well tested.

Instructions:
Download the script and set executable permissions for at least the user who will be executing it:
chmod u+x kvm-backup_0.1a.sh

Modify the script's Backup Directory in your favorite text editor and change the variable BACKUP_ROOT to define the target backup location.

Execute as superuser or your QEMU/KVM user. User must be able to read QEMU/KVM disks, create snapshots, and have write and execute permissions on the target storage for backups.


TODO:
1. Better exception handling including snapshot removal and reverting to base disks when backup fails to complete.
2. On-the-fly compression to avoid using the full disk space of the VM's disks on the target storage before compressing in-place.
3. Everything else.

Feel free to tear me and this code apart in the bug tracker, as there is much work to be done.
