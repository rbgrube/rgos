AS = nasm
QEMU = qemu-system-i386
LD = i686-elf-ld
CLANG = clang
GDB = gdb

BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
BIN_DIR = $(BUILD_DIR)/bin
DEBUG_DIR = $(BUILD_DIR)/debug
IMG_DIR = $(BUILD_DIR)/image

RGOS_IMG = $(IMG_DIR)/rgos.img
BIOS_BOOTLOADER_STAGE1_SRC = boot/bootloader/bios/RGOS_stage1_bootloader.asm
BIOS_BOOTLOADER_STAGE2_SRC = boot/bootloader/bios/RGOS_stage2_bootloader.asm
BIOS_BOOTLOADER_BIN = $(BIN_DIR)

RGOS_KERNEL_SRC = src/kernel
KERNEL_OBJ = $(OBJ_DIR)/kernel
RGOS_KERNEL_BIN = $(BIN_DIR)/kernel.bin
RGOS_KERNEL_LINKERSCRIPT = $(RGOS_KERNEL_SRC)/kernel.ld

VOLUME_PATH = /Volumes/RGOS

.PHONY: all clean run build_rgos create_rgos attach_rgos partition_rgos detach_rgos assemble_bootloader_stage1_bios compile_kernel link_kernel mount_rgos copy_kernel assemble_bootloader_stage2_bios

# Function to create directories
define make-dir
	@mkdir -p $1
endef

# Ensure necessary directories exist
$(BIN_DIR) $(OBJ_DIR) $(IMG_DIR) $(DEBUG_DIR) $(KERNEL_OBJ):
	$(call make-dir,$@)

# ----------------------------------------
#  Build the Bootloader
# ----------------------------------------

# Assemble the bootloader binary from source
assemble_bootloader_stage1_bios: $(BIOS_BOOTLOADER_STAGE1_SRC) $(BIN_DIR) $(DEBUG_DIR)
	@echo "Assembling rgos bootloader..."
	$(AS) -f bin -D RAW_BINARY $(BIOS_BOOTLOADER_STAGE1_SRC) -o $(BIOS_BOOTLOADER_BIN)/RGOS_stage1_bootloader.bin
	$(AS) -f elf -F dwarf -g $(BIOS_BOOTLOADER_STAGE1_SRC) -o $(DEBUG_DIR)/RGOS_stage1_bootloader.o
	$(LD) -m elf_i386 -Ttext 0x7C00 --oformat elf32-i386 -o $(DEBUG_DIR)/RGOS_stage1_bootloader.elf $(DEBUG_DIR)/RGOS_stage1_bootloader.o
	rm -rf $(DEBUG_DIR)/RGOS_stage1_bootloader.o

# Assemble the bootloader binary from source
assemble_bootloader_stage2_bios: $(BIOS_BOOTLOADER_STAGE2_SRC) $(BIN_DIR) $(DEBUG_DIR)
	@echo "Assembling rgos bootloader..."
	$(AS) -f bin -D RAW_BINARY $(BIOS_BOOTLOADER_STAGE2_SRC) -o $(BIOS_BOOTLOADER_BIN)/RGOS_stage2_bootloader.bin
	$(AS) -f elf -F dwarf -g  $(BIOS_BOOTLOADER_STAGE2_SRC) -o $(DEBUG_DIR)/RGOS_stage2_bootloader.o
	$(LD) -m elf_i386 -Ttext 0x8000 --oformat elf32-i386 -o $(DEBUG_DIR)/RGOS_stage2_bootloader.elf $(DEBUG_DIR)/RGOS_stage2_bootloader.o
	rm -rf $(DEBUG_DIR)/RGOS_stage2_bootloader.o


# ----------------------------------------
#  Build RGOS Kernel
# ----------------------------------------


compile_kernel: $(RGOS_KERNEL_SRC) $(KERNEL_OBJ)
	@echo "Compiling rgos kernel..."
	$(CLANG) --target=i686-elf -ffreestanding -c $(RGOS_KERNEL_SRC)/*.c -o $(KERNEL_OBJ)/kernel.o

link_kernel: $(RGOS_KERNEL_SRC) $(KERNEL_OBJ) $(RGOS_KERNEL_LINKERSCRIPT)
	@echo "Linking rgos kernel..."
	$(LD) -T $(RGOS_KERNEL_LINKERSCRIPT) -o $(RGOS_KERNEL_BIN) $(KERNEL_OBJ)/kernel.o --oformat binary

# ----------------------------------------
#  Create and Prepare Disk Image
# ----------------------------------------

# Create an empty rgos disk image
create_rgos: $(IMG_DIR)
	@echo "Creating disk image..."
	dd if=/dev/zero of=$(RGOS_IMG) bs=1M count=128

# Attach the rgos disk image to the system
attach_rgos:
	@echo "Attaching disk image..."
	$(eval DISK_ID = $(shell hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount $(RGOS_IMG) | grep '/dev/disk' | xargs))
	@echo "Disk attached as $(DISK_ID)"

# Partition the attached disk image
partition_rgos:
	@echo "Partitioning Image..."
	diskutil partitionDisk $(DISK_ID) 2 MBR "Free Space" "RGOSBOOT2" 32Kb FAT32 "RGOS" R
	
mount_rgos:
	@echo "Mounting the partition..."
	$(eval PARTITION_ID = $(shell diskutil list | grep "$(DISK_ID)" | awk '{print $$1}' | cut -d' ' -f1))
	@ echo "$(PARTITION_ID)"
	sudo diskutil unmount /Volumes/RGOS || true
	@mkdir -p $(VOLUME_PATH)
	sudo mount -t msdos $(PARTITION_ID)s1 $(VOLUME_PATH)
	@echo "Partition mounted at $(VOLUME_PATH)"

copy_kernel: mount_rgos
	@echo "Copying kernel into image..."
	sudo cp $(RGOS_KERNEL_BIN) $(VOLUME_PATH)/kernel.bin
	sudo sync
	sudo umount $(VOLUME_PATH)
	rm -rf $(VOLUME_PATH)

# Detach the rgos disk image from the system
detach_rgos:
	@echo "Detaching disk image..."
	hdiutil detach $(DISK_ID)

# ----------------------------------------
#  Build the Complete Disk Image
# ----------------------------------------

build_rgos: assemble_bootloader_stage1_bios assemble_bootloader_stage2_bios compile_kernel link_kernel create_rgos attach_rgos partition_rgos mount_rgos copy_kernel detach_rgos 
	@echo "Copying stage 1 bootloader into final bootsector..."
	dd if=$(BIOS_BOOTLOADER_BIN)/RGOS_stage1_bootloader.bin of=$(RGOS_IMG) bs=446 count=1 conv=notrunc

	@echo "Copying 32kb of stage 2 bootloader into sector 2"
	dd if=$(BIOS_BOOTLOADER_BIN)/RGOS_stage2_bootloader.bin of=$(RGOS_IMG) bs=512 seek=1 count=64 conv=notrunc

# ----------------------------------------
#  Run the Bootloader in QEMU
# ----------------------------------------

run: build_rgos

	@echo "Running bootloader in QEMU..."
	$(QEMU) -d int -no-reboot -drive file=$(RGOS_IMG),format=raw -monitor stdio
	

run_GDB: build_rgos

	@echo "Running bootloader in QEMU..."
	$(QEMU) -d int -no-reboot -drive file=$(RGOS_IMG),format=raw -monitor stdio -S -gdb tcp::1234 &
	
	$(GDB) -ex "target remote localhost:1234" $(DEBUG_DIR)/RGOS_stage2_bootloader.elf


# ----------------------------------------
#  Clean Up
# ----------------------------------------

clean:
	@echo "Cleaning up build directories and files..."
	sudo rm -rf $(OBJ_DIR) $(BIN_DIR) $(DEBUG_DIR) $(IMG_DIR) $(RGOS_IMG)

# Default target to build and run the bootloader
all: run