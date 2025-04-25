# Command Paths
AS = nasm
QEMU = qemu-system-i386
LD = i686-elf-ld
CLANG = clang
GDB = gdb

#BOCHS=bochs

BUILD_DIR = build

BIN = $(BUILD_DIR)/bin
DEBUG = $(BUILD_DIR)/debug
IMAGE = $(BUILD_DIR)/image
OBJ = $(BUILD_DIR)/obj
SYSROOT = $(BUILD_DIR)/sysroot

RGOS_IMG = $(IMAGE)/rgos.img

STAGE_1_BOOTLOADER_SRC = src/bootloader/legacy/RGOS_stage1_bootloader.asm
STAGE_1_BOOTLOADER = $(BIN)/RGOS_stage1_bootloader.bin

STAGE_2_BOOTLOADER_SRC = src/bootloader/legacy/second_stage/src
STAGE_2_LINKERSCRIPT = src/bootloader/legacy/second_stage/linker.ld
STAGE_2_BOOTLOADER = $(BIN)/RGOS_stage2_bootloader.bin
STAGE_2_BOOTLOADER_INC = src/bootloader/legacy/second_stage/include
STAGE2_OBJ_PATH = $(OBJ)/stage2

KERNEL = $(SYSROOT)/boot/kernel.bin
KERNEL_SRC = src/kernel
KERNEL_LINKERSCRIPT = src/kernel/kernel.ld
KERNEL_OBJ_PATH = $(OBJ)/kernel
KERNEL_INC_PATH = $(KERNEL_SRC)/include

#BOCHS_CFG = config/bochs.cfg 

define make-dir
	@mkdir -p $1
endef

# Ensure necessary directories exist
$(BIN) $(OBJ) $(IMAGE) $(DEBUG) $(STAGE2_OBJ_PATH) $(KERNEL_OBJ_PATH) $(SYSROOT):
	$(call make-dir,$@)

all: $(RGOS_IMG) install_stage1 install_stage2 build_kernel copy_sysroot

# Create RGOS image with partitions
$(RGOS_IMG): $(IMAGE)

	@if [ ! -f $(RGOS_IMG) ]; then \
		echo "Creating disk image..."; \
		dd if=/dev/zero of=$(RGOS_IMG) bs=1M count=128; \
		echo "Attaching disk image..."; \
		DISK_ID=$$(hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount $(RGOS_IMG)); \
		echo "Attched at $$DISK_ID"; \
		echo "Partitioning Image..."; \
		diskutil partitionDisk $$DISK_ID 2 MBR "Free Space" "RGOSBOOT2" 32Kb FAT32 "RGOS" R; \
		echo "Detaching disk image..."; \
		hdiutil detach $$DISK_ID; \
	fi

# Build stage1
$(STAGE_1_BOOTLOADER): $(BIN) $(DEBUG) $(OBJ) $(STAGE_1_BOOTLOADER_SRC)
	@echo "Assembling rgos bootloader..."
	$(AS) -f bin -D RAW_BINARY $(STAGE_1_BOOTLOADER_SRC) -o $(BIN)/RGOS_stage1_bootloader.bin
	$(AS) -f elf -F dwarf -g $(STAGE_1_BOOTLOADER_SRC) -o $(OBJ)/RGOS_stage1_bootloader.o
	$(LD) -m elf_i386 -g -Ttext 0x7C00 --oformat elf32-i386 -o $(DEBUG)/RGOS_stage1_bootloader.elf $(OBJ)/RGOS_stage1_bootloader.o
	rm -rf $(DEBUG)/RGOS_stage1_bootloader.o

# Install stage1
install_stage1: $(STAGE_1_BOOTLOADER)
	@echo "Installing first stage bootloader..."
	dd if=$(STAGE_1_BOOTLOADER) of=$(RGOS_IMG) bs=446 count=1 conv=notrunc

# Build stage2
STG2_ASM_SRCS := $(wildcard $(STAGE_2_BOOTLOADER_SRC)/*.asm) $(wildcard $(STAGE_2_BOOTLOADER_SRC)/**/*.asm)
STG2_ASM_OBJS := $(patsubst $(STAGE_2_BOOTLOADER_SRC)/%.asm, $(STAGE2_OBJ_PATH)/%.o, $(STG2_ASM_SRCS))

$(STAGE_2_BOOTLOADER): $(BIN) $(DEBUG) $(STAGE2_OBJ_PATH) $(STAGE_2_LINKERSCRIPT) $(STAGE_2_BOOTLOADER_INC) $(STG2_ASM_SRCS)
	@for file in $(STG2_ASM_SRCS); do \
		rel_path=$${file#$(STAGE_2_BOOTLOADER_SRC)/}; \
		obj_file="$(STAGE2_OBJ_PATH)/$${rel_path%.asm}.o"; \
		mkdir -p $$(dirname $$obj_file); \
		echo "Assembling $$file -> $$obj_file"; \
		$(AS) -f elf -F dwarf -g -I$(STAGE_2_BOOTLOADER_INC) $$file -o $$obj_file; \
	done; \

	$(LD) -g -m elf_i386 -T$(STAGE_2_LINKERSCRIPT) --oformat elf32-i386 -o $(DEBUG)/RGOS_stage2_bootloader.elf $(STG2_ASM_OBJS)

	objcopy -O binary $(DEBUG)/RGOS_stage2_bootloader.elf $(STAGE_2_BOOTLOADER)

# Install stage2
install_stage2: $(STAGE_2_BOOTLOADER)
	@echo "Copying 32kb of stage 2 bootloader into sector 2"
	dd if=$(STAGE_2_BOOTLOADER) of=$(RGOS_IMG) bs=512 seek=1 count=64 conv=notrunc


# Build kernel

KERNEL_C_SRCS := $(wildcard $(KERNEL_SRC)/*.c) $(wildcard $(KERNEL_SRC)/**/*.c)
KERNEL_OBJS := $(patsubst $(KERNEL_SRC)/%.c, $(KERNEL_OBJ_PATH)/%.o, $(KERNEL_C_SRCS))
KERNEL_ASM_SRCS := $(wildcard $(KERNEL_SRC)/*.asm) $(wildcard $(KERNEL_SRC)/**/*.asm)
KERNEL_ASM_OBJS := $(patsubst $(KERNEL_SRC)/%.asm, $(KERNEL_OBJ_PATH)/%.o, $(KERNEL_ASM_SRCS))

$(KERNEL): $(SYSROOT)
	mkdir -p $(SYSROOT)/boot

build_kernel: $(KERNEL_C_SRCS) $(KERNEL_ASM_SRCS) $(KERNEL_OBJ_PATH) $(KERNEL_LINKERSCRIPT) $(DEBUG) $(KERNEL_INC_PATH) $(KERNEL)

	@for file in $(KERNEL_ASM_SRCS); do \
		rel_path=$${file#$(KERNEL_SRC)/}; \
		obj_file="$(KERNEL_OBJ_PATH)/$${rel_path%.asm}.o"; \
		mkdir -p $$(dirname $$obj_file); \
		echo "Assembling $$file -> $$obj_file"; \
		$(AS) -f elf -F dwarf -g $$file -o $$obj_file; \
	done; \

	@for file in $(KERNEL_C_SRCS); do \
		rel_path=$${file#$(KERNEL_SRC)/}; \
		obj_file="$(KERNEL_OBJ_PATH)/$${rel_path%.c}.o"; \
		mkdir -p $$(dirname $$obj_file); \
		echo "Compiling $$file -> $$obj_file"; \
		$(CLANG) -g --target=i686-elf -ffreestanding -c -I$(KERNEL_INC_PATH) $$file -o $$obj_file; \
	done; \

	$(LD) -m elf_i386 -T$(KERNEL_LINKERSCRIPT) --oformat elf32-i386 -z noexecstack  -o $(DEBUG)/kernel.elf $(KERNEL_OBJS) $(KERNEL_ASM_OBJS)

	objcopy -O binary $(DEBUG)/kernel.elf $(KERNEL)


copy_sysroot: $(SYSROOT) $(RGOS_IMG)

	@echo "Mounting FAT partition..."; \
	PARTITION_INFO=$$(sudo hdiutil attach $(RGOS_IMG)); \
	PARTITION_ID=$$(echo $$PARTITION_INFO | grep DOS_FAT_32 | awk '{print $$1}'); \
	DISK_ID=$$(echo "$$PARTITION_ID" | head -n 1 | awk '{print $$1}'); \
	MOUNT_VOL=$$(echo $$PARTITION_INFO | grep DOS_FAT_32 | awk '/\/Volumes\// {match($$0, /\/Volumes\/.*/); print substr($$0, RSTART)}'); \
	echo "Partition $$PARTITION_ID mounted at $$MOUNT_VOL"; \
	echo "Copying kernel into image..."; \
	sudo cp -a $(SYSROOT)/. "$$MOUNT_VOL"; \
	echo "Detaching $$DISK_ID"; \
	hdiutil detach "$$DISK_ID"; \

# Executes
run: all

	@echo "Running bootloader in QEMU..."
	$(QEMU) -d int -no-reboot -drive file=$(RGOS_IMG),format=raw -monitor stdio
	
# Executes
run_bochs: all $(BOCHS_CFG)

	@echo "Running in Bochs..."
	$(BOCHS) -f $(BOCHS_CFG)
	

run_GDB: all

	@echo "Running bootloader in QEMU..."
	$(QEMU) -d int -no-reboot  -drive file=$(RGOS_IMG),format=raw -monitor stdio -S -gdb tcp::1234 &
	$(GDB) -ex "target remote localhost:1234" $(DEBUG)/RGOS_stage2_bootloader.elf

clean:
	@echo "Cleaning up build directories and files..."
	sudo rm -rf $(BUILD_DIR)/*
