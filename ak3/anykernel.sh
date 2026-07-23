properties() { '
kernel.string=Poco F5 | Redmi Note 12 Turbo
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=marble
device.name2=marblein
supported.versions=
supported.patchlevels=
'; }

block=boot;
is_slot_device=auto;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

. tools/ak3-core.sh;

ui_print " "
ui_print "███████╗ ██████╗ ██╗███████╗"
ui_print "╚══███╔╝██╔═══██╗██║██╔════╝"
ui_print "  ███╔╝ ██║   ██║██║███████╗"
ui_print " ███╔╝  ██║   ██║██║╚════██║"
ui_print "███████╗╚██████╔╝██║███████║"
ui_print "╚══════╝ ╚═════╝ ╚═╝╚══════╝"
ui_print " "
ui_print "        Kernel by Pablo Escobar"
ui_print " "

is_supported_rom() {
    local value=""

    if grep -qiE 'aospa|neoteric' \
        /system_root/system/build.prop \
        /product/etc/build.prop 2>/dev/null; then
        return 0
    fi

    if [ -f /product/etc/build.prop ]; then
        value="$(
            grep -iE \
                '^(ro\.(infinity|lunaris|ascp)\.maintainer|persist\.sys\.axion_maintainer)=' \
                /product/etc/build.prop \
            | cut -d= -f2- \
            | tr '[:upper:]' '[:lower:]' \
            | tr -d '[:space:]'
        )"
    elif [ -f /system_root/system/build.prop ]; then
        value="$(
            grep -iE \
                '^(ro\.(infinity|lunaris|ascp)\.maintainer|persist\.sys\.axion_maintainer)=' \
                /system_root/system/build.prop \
            | cut -d= -f2- \
            | tr '[:upper:]' '[:lower:]' \
            | tr -d '[:space:]'
        )"
    fi

    case "$value" in
        *pabloescobar*|*ashwani*)
            return 0
            ;;
    esac

    return 1
}

ui_print "Checking ROM compatibility..."

if ! is_supported_rom; then
    ui_print " "
    ui_print "──────────────────────────────────────"
    ui_print "            Unsupported ROM"
    ui_print "──────────────────────────────────────"
    ui_print " This kernel only supports"
    ui_print " Pablo Escobar's ROMs."
    ui_print "──────────────────────────────────────"
    abort "Installation aborted."
fi

ui_print "Supported ROM detected."

backup_current_boot() {
  backup_dir="/sdcard/marble-kernel-backup";
  slot_name="${SLOT:-noslot}";
  stamp="$(date +%Y%m%d-%H%M%S 2>/dev/null || date +%s)";
  backup_img="${backup_dir}/boot-marble-${slot_name}-${stamp}.img";
  backup_txt="${backup_dir}/boot-marble-${slot_name}-${stamp}.txt";

  ui_print "Backing up current boot image...";
  mkdir -p "$backup_dir" || abort "Unable to create ${backup_dir}. Aborting...";

  if [ ! -s "$BOOTIMG" ]; then
    abort "Dumped boot image is missing. Backup failed; aborting for safety.";
  fi;

  cp -f "$BOOTIMG" "$backup_img" || abort "Unable to save boot backup. Aborting...";
  {
    echo "device=marble/marblein";
    echo "slot=${slot_name}";
    echo "source_block=${BLOCK}";
    echo "created=${stamp}";
    echo "backup=${backup_img}";
  } > "$backup_txt" 2>/dev/null || true;

  ui_print "Backup saved:";
  ui_print "  ${backup_img}";
}

dump_boot;
backup_current_boot;
write_boot;
