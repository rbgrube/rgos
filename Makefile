# Command Paths
AS = nasm
QEMU = qemu-system-i386
LD = i686-elf-ld
CLANG = clang
GDB = gdb

BUILD_DIR = build

BIN = $(BUILD_DIR)/bin
DEBUG = $(BUILD_DIR)/debug
IMAGE = $(BUILD_DIR)/image
OBJ = $(BUILD_DIR)/obj

RGOS_IMG = $(IMAGE)/rgos.img

STAGE_1_BOOTLOADER_SRC = boot/bootloader/bios/RGOS_stage1_bootloader.asm
STAGE_1_BOOTLOADER = $(BIN)/RGOS_stage1_bootloader.bin

STAGE_2_BOOTLOADER_SRC = boot/bootloader/bios/second_stage/src
STAGE_2_LINKERSCRIPT = boot/bootloader/bios/second_stage/linker.ld
STAGE_2_BOOTLOADER = $(BIN)/RGOS_stage2_bootloader.bin
STAGE_2_BOOTLOADER_INC = boot/bootloader/bios/second_stage/include
STAGE2_OBJ_PATH = $(OBJ)/stage2

KERNEL = $(BIN)/kernel.bin
KERNEL_SRC = src/kernel
KERNEL_LINKERSCRIPT = src/kernel/kernel.ld


define make-dir
	@mkdir -p $1
endef

# Ensure necessary directories exist
$(BIN) $(OBJ) $(IMAGE) $(DEBUG) $(STAGE2_OBJ_PATH):
	$(call make-dir,$@)

all: $(RGOS_IMG) install_stage1 install_stage2 install_kernel

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

KERNEL_C_SRCS := $(wildcard $(KERNEL_SRC)/*.c)
KERNEL_OBJS := $(patsubst $(KERNEL_SRC)/%.c, $(OBJ)/%.o, $(KERNEL_C_SRCS))

build_kernel: $(KERNEL_C_SRCS) $(OBJ) $(KERNEL_LINKERSCRIPT) $(DEBUG)

	@for file in $(KERNEL_C_SRCS); do \
		obj_file="$(OBJ)/$$(basename $$file .c).o"; \
		echo "Compiling $$file -> $$obj_file"; \
		$(CLANG) --target=i686-elf -ffreestanding -c $$file -o $$obj_file; \
	done; \

	$(LD) -m elf_i386 -T$(KERNEL_LINKERSCRIPT) --oformat elf32-i386  -o $(DEBUG)/kernel.elf $(KERNEL_OBJS)

	objcopy -O binary $(DEBUG)/kernel.elf $(KERNEL)

install_kernel: build_kernel $(RGOS_IMG)

	@echo "Mounting FAT partition..."; \
	PARTITION_INFO=$$(sudo hdiutil attach $(RGOS_IMG)); \
	PARTITION_ID=$$(echo $$PARTITION_INFO | grep DOS_FAT_32 | awk '{print $$1}'); \
	DISK_ID=$$(echo "$$PARTITION_ID" | head -n 1 | awk '{print $$1}'); \
	MOUNT_VOL=$$(echo $$PARTITION_INFO | grep DOS_FAT_32 | awk '/\/Volumes\// {match($$0, /\/Volumes\/.*/); print substr($$0, RSTART)}'); \
	echo "Partition $$PARTITION_ID mounted at $$MOUNT_VOL"; \
	echo "Copying kernel into image..."; \
	sudo cp $(KERNEL) "$$MOUNT_VOL"; \
	echo "Detaching $$DISK_ID"; \
	hdiutil detach "$$DISK_ID"; \

# Executes
run: all

	@echo "Running bootloader in QEMU..."
	$(QEMU) -d int -no-reboot -drive file=$(RGOS_IMG),format=raw -monitor stdio
	
run_GDB: all

	@echo "Running bootloader in QEMU..."
	$(QEMU) -d int -no-reboot -drive file=$(RGOS_IMG),format=raw -monitor stdio -S -gdb tcp::1234 &
	$(GDB) -ex "target remote localhost:1234" $(DEBUG)/RGOS_stage2_bootloader.elf

clean:
	@echo "Cleaning up build directories and files..."
	sudo rm -rf $(BUILD_DIR)/*
