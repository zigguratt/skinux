# Install Arch Linux on a persistent USB flash drive
This guide describes in detail how to go from a bare Arch Linux command prompt to a fully-functioning, albeit quite minimal graphical environment on a USB flash drive that can be plugged into any computer that supports booting from a USB device. If desired, this guide can also be used to  install Arch directly on a desktop or laptop machine with a few changes. This will be left as an exercise for the reader.

## Arch Linux
Arch Linux bills itself as
>a lightweight and flexible Linux® distribution that tries to Keep It Simple.

Lightweight and flexible, yes. In spades. Simple? Not so much. But they can get away with saying that by defining _simplicity_ as "without unnecessary additions or modifications". Arch is a Linux distribution that doesn't hold your hand except by way of extensive documentation. It has many advantages, amongst which are the complete lack of bloatware and the rolling release model. You will never have to upgrade to a new version of Arch: simply execute `pacman -Syu` on occasion to update any software that has been modified since the last invocation of that command. Likewise, you'll never have software on your system that you didn't put there yourself.

## Getting started
This guide will attempt to leave you with a USB flash drive that can act as your entire working system — one that is bootable on a variety of machines, including Apple laptops. I'm using this very setup on my early 2015 MacBook Pro with 16GB RAM. Of course, your mileage _will_ vary. Please let me know when you run into issues and I'll do my best to help.

To get started, you need to download the latest [Arch ISO](https://www.archlinux.org/download/). Once you have the ISO file on your system you need to write it to a spare USB flash drive using something like [Etcher](https://etcher.io/), a cross-platform tool ideally suited for this task. This flash drive doesn't have to be very big; 8GB should be more than sufficient. I would highly recommend using USB 3-compatible flash drives and ports for this exercise. Your experience will be substandard with anything slower.

Once you've written the Arch ISO, shut down your computer and insert both the Arch ISO USB flash drive and a large-capacity, blank USB flash drive into your machine. Start your computer and do whatever you need to do to get a boot menu. On Apple machines you hold down `alt/option` until you get a screen that lets you choose a boot device. USB drives appear here as orange slabs. Other machines need either `F2`, `F12` or something similar. It will usually tell you on the first screen, but it might time out quickly so read fast! Choose the Arch ISO USB device and continue the boot process. You'll end up at a very unfriendly-looking command prompt. We're ready to start the installation process.

## Set up the partitions
I have to emphasize here that you need to be _very_ careful when choosing the device on which to install the system. Your machine's built-in drive will show up in the lists of available drives. _DO NOT CHOOSE IT!_ The `parted` utility gives the best descriptions of each storage device. Here is an example of partial output from `parted -l` on my current system:
```
Model: ATA APPLE SSD SM0512 (scsi)
Disk /dev/sda: 500GB
Sector size (logical/physical): 512B/4096B
Partition Table: gpt
Disk Flags:

Model: SanDisk Ultra Fit (scsi)
Disk /dev/sdb: 250GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:
```

You can clearly see from this output that `/dev/sda` is the Apple SSD in the laptop and `/dev/sdb` is the large USB flash drive on which I've installed Arch.

### Partition your flash drive
For this task we're going to make use of the `gdisk` utility. Using the device information gleaned from the `parted` output, type the following at the prompt:
```
# gdisk /dev/sdX
```

where _X_ is the correct device letter. In this guide all commands will be preceded by either `#` or `$`, indicating a Linux command prompt. Don't type these symbols.

After `gdisk` starts, type `n` to create a new partition. This and the following assumes that your large USB flash drive is blank. If it isn't, either panic and pull the drive out of the machine, or delete any existing partitions with `d`.

Partition your system so it looks like this:
```
Number  Start (sector)    End (sector)  Size       Code  Name
   1            2048           22527   10.0 MiB    EF02  BIOS boot partition
   2           22528         1046527   500.0 MiB   EF00  EFI System
   3         1046528       454031359   232.0 GiB   8300  Linux filesystem
```

Use the device codes shown. `gdisk` will ask for a code after the creation of each partition. The first two partitions need to be exactly as shown. The third is the main partition on which the system will be installed.

Once you've set up your partitions issue the `w` command to write the partition table to the USB flash drive and exit `gdisk`. Next you're going to format the partitions with the appropriate filesystems. Issue the following commands replacing _X_ with the correct device letter:
```
# mkfs.fat -F32 /dev/sdX2
# mkfs.ext4 /dev/sdX3
```

## Set up for `arch-chroot`
I won't say much about `arch-chroot` except  that it drops you into a system that believes the directory into which you've been `chrooted` is the root of the filesystem. `chroot` = _change root_. This will allow you to continue setup as if you've booted into this system . First we need to mount our partitions so that they can be set up:
```
# mount /dev/sdX3 /mnt
# mkdir /mnt/boot
# mount /dev/sdX2 /mnt/boot
```

### Enable networking for `pacstrap`
`pacstrap` is a utility that sets up your initial filesystem. It requires Internet access to do so, however. If your machine is wired to an Ethernet network you can skip this command. If you're wireless do the following, choosing the correct wireless network and providing its password:
```
# wifi-menu -o
```

In either case, issue a `ping` command to ensure you're connected to the Internet:
```
# ping 8.8.8.8
```

If you just connected wirelessly it'll take `ping` a few seconds to show a proper response. Just wait and re-issue the command until you get a response. If you don't, then you're on your own; troubleshooting wireless connections is beyond the scope of this guide.

### Final `chroot` set up
It's time to populate the main partition with the base software system, the base development system, and `git`, which we'll need later on.
```
# pacstrap /mnt base base-devel git
```

This takes a while so go and smoke a cigarette, or maybe do some vaping. I don't condone either activity, of course. Next we will update the filesystem table, `fstab`, with information about our partitions. This will be the actual `fstab` used by the live system.
```
# genfstab -U /mnt >> /mnt/etc/fstab
```

Now we're ready to drop into our new system, or at least pretend to: 
```
# arch-chroot /mnt
```

## The Chroot Zone
To paraphrase Rod Serling:
>You are about to enter another dimension, a dimension not only of
>sight and sound but of mind. A journey into a wondrous land of
>imagination. Next stop, the Chroot Zone!

Now we can start configuring our new system. Anything we do here will appear in the final system. To begin, set the hostname:
```
# echo <your-hostname> > /etc/hostname
```

replacing `<your-hostname>` with a suitably clever host name.

### Set up the system's time zone, locale, and clock
Linux is notoriously picky about time zones and locales. Do the following, replacing references to Toronto, Canada, and America with your own location. Be warned: it's quite a mouthful. Take care and double-check your typing. Some of us are `vi`-challenged so `nano` will do as a replacement.
```
# ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
# echo LANG=en_CA.UTF-8 >> /etc/environment
# echo LANG=en_CA.UTF-8 > /etc/locale.conf
# export LANG=en_CA.UTF-8
# hwclock --systohc --utc
# vi /etc/locale.gen # Uncomment en_CA.UTF-8
# locale-gen
```

Linux should have nothing to complain about if you executed these steps successfully.

### Set the `ext4` journal to write to memory
The `ext4` filesystem maintains a journal of activities that can be replayed at a later date. Since we're on a medium that really doesn't like being written to very often, we need to set the journal to write to memory. Edit `journald.conf` and uncomment the following two lines, providing the values indicated below:
```
# vi /etc/systemd/journald.conf
Storage=volatile
SystemMaxUse=16M
```

### Set the `ext4` partition to `noatime`
The `noatime` flag will tell the filesystem not to record the last accessed date of a file. This reduces writes to the flash drive, extending its life. Edit the `fstab` file and change `relatime` to `noatime` in the line that contains `ext4`.
```
# vi /etc/fstab
```

### Install bootloaders
We've almost finished configuring our system for its first boot. In order for it to start up successfully we need a bootloader. A bootloader is a small program stored in the MBR or GUID partition table that helps to load an operating system into memory. Without going into greater detail, suffice it to say we need one. Our system will be able to boot from both BIOS- and UEFI-based machines. To support this we need to install both `grub` and `efibootmgr`. For this we'll use the Arch package manager, `pacman`:
```
# pacman --noconfirm -S grub efibootmgr
```

Execute the following commands to configure them and write them to the `boot` partition:
```
# grub-install --target=i386-pc --boot-directory /boot /dev/sdX
# grub-install --target=x86_64-efi --efi-directory /boot --boot-directory /boot --removable
# grub-mkconfig -o /boot/grub/grub.cfg
```

### Install drivers to support a live, persistent system
Our system needs to handle hardware on whatever machine it finds itself booting on. The following set of drivers for wireless, touchpad, and video should work for a large variety of machines:
```
# pacman --noconfirm -S ifplugd iw wpa_supplicant dialog acpi xf86-input-synaptics
# pacman --noconfirm -S xf86-video-ati xf86-video-intel xf86-video-nouveau xf86-video-vesa
```

## Reboot into our new system
We're ready to see if all of our hard work has paid off! First we need to escape from this fake system root. Then we'll unmount our partitions, supplying the `-R` recursive option to `umount` so that the `boot` partition also gets unmounted. No, `umount` is not a typo for `unmount`. It's `umount`. Get over it. Finally, shut down the computer.
```
# exit
# umount -R /mnt
# poweroff
```

Remove the Arch ISO USB flash drive and power back up, holding/pressing whatever key you pressed/held the first time through as described at the start of this guide. Choose your large USB stick and you'll soon be dumped at a login prompt. If it all blows up in your face, clean it off and try everything again. This is usually an iterative process, going back to fix errors and trying again. Type `root` and hit `enter/return` to continue.

## Final configuration
We're in the home stretch. We just have a couple of configuration steps to do and then we'll set up a graphical environment to make it all pretty.

### Activate NTP and set up networking
NTP is a protocol designed to synchronize the clocks of computers over a network. It ensures that your system clock is always accurate and in sync with the world at large. With this command we enable NTP on our system.
```
# timedatectl set-ntp true
```

Now we have to set up networking again. The first time we set it up we were in the Arch installation context. We're now sitting in our actual booted system which has no idea what occurred during installation. If you're on a wired connection you can skip this step. Again, make sure you're connected to the Internet before proceeding.
```
# wifi-menu -o
# ping 8.8.8.8
```

## Set up a graphical environment
Your new Arch system is now completely usable as it is. Everything is in place for you to be able to sit and stare at a command prompt. If you would like to do more than that, the following steps will provide a graphical environment in which you can browse your heart out.

I've come up with a list of software necessary to support such an environment. It's very minimal but completely workable. I've also put together a file that will overlay our system to provide pre-sets for many things. After you've installed this software you'll have a graphical system that gives you everything you need to start installing the software that _you_ want on your system, not someone else's idea of what you should want.

### Clone the `skinux` repository
We'll use `git` to retrieve this very `skinux` repository:
```
# git clone https://github.com/zigguratt/skinux.git
# cd skinux
```

### Install system software
Now we'll use `pacman` again to install the system software. If you want to see what will be installed, take a look in `software.txt` before you start. This process takes a very long time in relative terms. Break out that puzzle you've been dying to do, or maybe read Lord of the Rings.
```
# pacman --noconfirm -S $(< software.txt)
```

### Overlay pre-sets onto the system
As mentioned, I've developed pre-set configurations and initial support files that we'll overlay onto our system. These determine how the system will look and act when you log in for the first time. Everything is configurable so if you object to my choices you can change it all to be less beautiful.

In order to apply the pre-sets, we need to move `overlay.tgz` to the root of the filesystem and unarchive it. This action puts all files in their right places. Make _sure_ you're at `/` and not in some other directory or you'll be left wondering why nothing works. We need `--no-same-owner` to make sure all of the extracted files are owned by the `root` user and not by whoever the fool was who put this thing together. Once we're done we can remove `overlay.tgz`. Also, we have no further need for the `skinux` repo so it can be nuked:
```
# mv overlay.tgz /
# cd /
# tar zxf overlay.tgz --no-same-owner
# rm overlay.tgz
# cd
# rm -rf skinux
```

### Unmute the audio channels
By default ALSA, the Linux low-level sound driver, mutes all channels. Don't ask. In order to hear anything when you log in, you need to unmute the main audio channel. First get a list of all available channels, then `sset` the main channel to `unmute`:
```
# amixer # Find the muted main channel
# amixer sset <the muted main channel> unmute
```

It's usually the first (or only) channel in the list. You'll be able to change everything about sound on the system after we're finished. But this ALSA behaviour trips people up so it's best to address it early.

## Create a regular user
One does not simply log in as root. For normal day-to-day operation you operate as a user with standard privileges, only acquiring root privileges as necessary. Issue the `useradd` command, replacing `Regular User` and `user` with your own choices unless of course your name is actually _Regular User_. After that, add this new user to the `sudoers` system as one who can elevate their privileges. Finally, provide a password for this user.
```
# useradd -c "Regular User" \
    -G video,audio,power,disk,storage,optical,lp,scanner \
    -d /home/user -m -s /bin/bash user
# echo "%user ALL=(ALL:ALL) ALL" > /etc/sudoers.d/user
# chmod 440 /etc/sudoers.d/user
# passwd user
```

## Install the `yaourt` package manager
Yaourt is a package manager that facilitates the installation of software not sanctioned by the Arch Linux maintainers. This unsanctioned software lives in the Arch User Repository (AUR). There's nothing scary about doing  this; the maintainers want to maintain a minimal system. Everything beyond that they don't guarantee. We'll need to install some of this software so we'll need `yaourt`. Throughout this guide we've been operating as `root`. Yaourt doesn't want you to install software as the root user, so we first switch identities to the user we just created. We then install the necessary software and delete the remains of the installation. You'll see a lot of output from these commands.
```
# su - user # remember to use the username you chose previously!
$ git clone https://aur.archlinux.org/package-query.git
$ cd package-query
$ makepkg --noconfirm -si
$ cd
$ git clone https://aur.archlinux.org/yaourt.git
$ cd yaourt
$ makepkg --noconfirm -si
$ cd
$ rm -rf package-query yaourt
```

## Install some packages from the AUR
Now that we have `yaourt` available to us we can install some support software:

* `kalu` is an update checker and notifier. It will notify you when there are updates available for your system;
* `cmst` is a graphical interface to the network connection manager that was installed earlier. `connman`;
* `pa-applet-git` is a tray applet that lets you monitor and change the sound volume;
* `facetimehd-firmware` enables the webcam on most Apple laptops;
* `gtk-engine-unico` is a theme engine required by some of the software we've installed;
* `bcwc-pcie-git` is a webcam driver.

You'll now have time to complete that puzzle you started earlier or finish _The Return of the King_. Don't be alarmed by the red flashing warning message that says
```
Unsupported package: Potentially dangerous !
```

It says that for Every. Single. Package.
```
$ yaourt --noconfirm -S kalu
$ yaourt --noconfirm -S cmst
$ yaourt --noconfirm -S pa-applet-git
$ yaourt --noconfirm -S facetimehd-firmware
$ yaourt --noconfirm -S gtk-engine-unico
$ yaourt --noconfirm -S bcwc-pcie-git
```

Now we can go back to `root` and remove software that was used only to support installation:
```
$ exit
# pacman --noconfirm -Rcns gnome-common
```

## Set the network connection and login managers to start on boot
We want these two services to be up and running right from the start. Issue the following commands to have them automatically start on boot.
```
# systemctl enable connman
# systemctl enable slim
```

## Disable the root account
All that's left to do is disable `root` login for obvious security purposes:
```
# passwd -l root
```

## Reboot into your new system
We're done! Whew. That was a long and involved process. Reboot!
```
# reboot
```

Don't forget to hold down whatever key is necessary to get to a boot menu and choose your large USB flash drive. If all has gone as expected, when the reboot completes you'll see a simple grey login screen. Type the username you chose previously and then that user's password. Your desktop will appear shortly thereafter. Right click your mouse for a menu.

Check out `Settings > Shortcuts` for keyboard shortcuts and invisible features such as making any window more or less transparent and moving windows to certain positions on the screen. Run `Settings > Menu` to change or add to the right-click menu.

This is an extremely bare-bones system. In fact aside from accessories and settings, the only real software that's installed is `xterm`, a terminal emulator. There's a chance you'll want a browser on your new system. Open a terminal: `Applications > Terminal,` and type one of the following:
```
$ sudo pacman --noconfirm -S opera
$ sudo pacman --noconfirm -S midori
$ sudo pacman --noconfirm -S firefox
$ sudo pacman --noconfirm -S chromium
```

You can use the aforementioned `Menu` and `Shortcuts` accessories to add your selected browser to the right-click menu and assign a convenient shortcut key. Use this procedure to add any further software you install. You also have the option of editing the Openbox XML configuration files directly. They're hiding here:
```
~/.config/openbox/
```

## Conclusion
Enjoy your new, lightweight, powerful, portable operating system! You just put a lot of work into setting it up. If you have any questions or issues I'll do my best to address them. I would love to hear of this being installed on non-Apple hardware, or of a successful reboot on a second system. I'm also very open to suggestions as to how this can be improved upon or corrected. Sadly, I probably won't entertain suggestions to change window managers or task bars. That can be decided upon after the fact by anyone who uses this guide. I would like this to be the most minimal system possible whilst still enjoying a full graphical workspace experience so any suggestions as to how to make it _more_ minimal are welcome.
