# Project name
PROJNECT=stm32f469_dap
# STM32_SDK_DIR?=""
#STM32_SDK_DIR?= ../../../../../..
#　这个变量用来指定单片机芯片的型号，编译时传递给底层的hal文件
DEVICE=STM32F469xx
#　开发板的名称
BOARD=stm32f469-discovery
# BOARD=STM32469I-Discovery

BINDIR=bin
INCDIR=
# 注意不要将子目录添加到变量中
SRCDIR=board \
	   cmsis-dap \
	   daplink_if \
	   default \
	   drag_n_drop \
	   family \
	   hic_hal \
	   rtos \
	   setings \
	   target \
	   usb \
	   usb2uart   
INCDIR=$(SRCDIR)

CC=arm-none-eabi-gcc
CXX=arm-none-eabi-g++
LD=arm-none-eabi-ld
AR=arm-none-eabi-ar
AS=arm-none-eabi-as
CP=arm-none-eabi-objcopy
OD=arm-none-eabi-objdump
NM=arm-none-eabi-nm
SIZE=arm-none-eabi-size
A2L=arm-none-eabi-addr2line

# Find USER header directories
INC=$(shell find -L $(INCDIR) -name '*.h' -exec dirname {} \; | uniq)    # 这个命令非常智能，只要添加根目录，可以找出所有包含.h的目录
INCLUDES+=$(INC:%=-I%)

# Find source files
ASOURCES=$(shell find -L $(SRCDIR) -name '*.s')      #这个命令会递归的向下查找所有 .s .c .cpp文件，因此SRCDIR不要包含子目录
CSOURCES=$(shell find -L $(SRCDIR) -name '*.c')
CXXSOURCES=$(shell find -L $(SRCDIR) -name '*.cpp')

# CMSIS 
#INCLUDES+= -I../inc/
INCLUDES+= -I$(STM32_SDK_DIR)/Drivers/CMSIS/Core/Include/                 # 内核以及内核外设相关的头文件
INCLUDES+= -I$(STM32_SDK_DIR)/Drivers/CMSIS/Device/ST/STM32F4xx/Include/  # 设备底层寄存器访问接口
INCLUDES+= -I$(STM32_SDK_DIR)/Drivers/CMSIS/RTOS2/Include/

#INCLUDES+= -I$(STM32_SDK_DIR)/Middlewares/ST/STM32_Audio/Addons/PDM/Inc   # 和MP3音频有关

#------------------------------- BSP -------------------------------
# include $(STM32_SDK_DIR)/Drivers/BSP/$(BOARD)/bsp.mk
# INCLUDES+=$(BSP_INC) $(BSP_COMPONENTS_INC)
# CSOURCES+=$(BSP_SOURCES) $(BSP_COMPONENTS_SRC)

#------------------------------- HAL -------------------------------
include $(STM32_SDK_DIR)/Drivers/STM32F4xx_HAL_Driver/stm32f4xx_hal.mk
INCLUDES+=$(HAL_INC)
CSOURCES+=$(HAL_SOURCES)

################################## ADD YOUR CONPONENTS HERE ###########################
#FreeRTOS_PATH=$(STM32_SDK_DIR)/Middlewares/Third_Party/FreeRTOS/Source
#include $(FreeRTOS_PATH)/Makefile
#INCLUDES+=$(FreeRTOS_INC)
#CSOURCES+=$(FreeRTOS_SRC)

#include $(STM32_SDK_DIR)/Middlewares/Third_Party/FatFs/FatFS.mk
#INCLUDES+=$(FatFS_INC)
#CSOURCES+=$(FatFS_SRC)

# include $(STM32_SDK_DIR)/Middlewares/ST/STM32_USB_Device_Library/usb.mk
# INCLUDES+=$(USB_INC)
# CSOURCES+=$(USB_SRC)

# add this source so that you can re-target printf to uart
# note! if you want printf() to work, you need re-define  ＇UART_HandleTypeDef UART_LOG_Handle＇
# in you program, then initialize it.
# INCLUDES+=-I$(STM32_SDK_DIR)/utilities/Log
# CSOURCES+=$(STM32_SDK_DIR)/utilities/Log/uart_log.c

# if you want to link micro-lib to your program, please add this the following
# components. micro-lib includes some functions which is already in the stdlib,
# but have a faster speed, as well as some useful tools.
INCLUDES+=-I$(STM32_SDK_DIR)/utilities/micro_lib/ 
CSOURCES+=$(STM32_SDK_DIR)/utilities/micro_lib/micro_lib.c

#######################################################################################

# Find libraries
# INCLUDES_LIBS=-L$(STM32_SDK_DIR)/Middlewares/ST/STM32_Audio/Addons/PDM/Lib
# LINK_LIBS=-lPDMFilter_CM4_GCC_wc32

# Create object list
OBJECTS=$(ASOURCES:%.s=%.o)
OBJECTS+=$(CSOURCES:%.c=%.o)
OBJECTS+=$(CXXSOURCES:%.cpp=%.o)
# Create dependent file
DEPENDENT:=$(patsubst %c,%d,$(CSOURCES))
DEPENDENT+=$(patsubst %cpp,%d,$(CXXSOURCES))
# Define output files ELF & IHEX
BINELF=outp.elf
BINHEX=outp.hex
BINARY=outp.bin

# MCU FLAGS
MCUFLAGS=-mcpu=cortex-m4 -mthumb -mlittle-endian \
-mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb-interwork

#  __packed=__packed
DEFS=-DUSE_STDPERIPH_DRIVER=" " -D$(DEVICE)=" " \
		-DDAPLINK_VERSION="253" -DDAPLINK_BUILD_KEY="0x9B939E8F" \
		-DHID_ENDPOINT -DMSC_ENDPOINT -DCDC_ENDPOINT -DWEBUSB_INTERFACE -DWINUSB_INTERFACE \
		-DDRAG_N_DROP_SUPPORT -DDAPLINK_IF \
		-DINTERFACE_STM32F103XB -DDAPLINK_HIC_ID="0x97969908" \
		-DDAPLINK_NO_ASSERT_FILENAMES \
		-DOS_CLOCK="72000000"

CFLAGS=-c $(MCUFLAGS) $(INCLUDES) $(DEFS)  --specs=nano.specs
CXXFLAGS=-c $(MCUFLAGS) $(DEFS) $(INCLUDES) -std=c++11

# Need following option for LTO as LTO will treat retarget functions as
# unused without following option
# 使用重定向标准库函数，并且不会引起冲突
CFLAGS+=-fno-builtin

# LINKER FLAGS
LDSCRIPT=$(BOARD).ld
LDFLAGS =-T $(LDSCRIPT) $(MCUFLAGS) \
			--specs=nosys.specs --specs=nano.specs \
			-Wl,-Map=$(BINDIR)/output.map \
			-Wl,-gc-sections\
			$(INCLUDES_LIBS) $(LINK_LIBS)

###
# Build Rules
.PHONY: all release release-memopt debug clean

debug: CFLAGS+=-g
debug: CXXFLAGS+=-g
debug: LDFLAGS+=-g
debug: release

all: release-memopt

# 可以统计内存占用情况
release-memopt-blame: CFLAGS+=-g
release-memopt-blame: CXXFLAGS+=-g
release-memopt-blame: LDFLAGS+=-g -Wl,-Map=$(BINDIR)/output.map
release-memopt-blame: release-memopt
release-memopt-blame:
	@echo "Top 10 space consuming symbols from the object code ...\n"
	$(NM) -A -l -C -td --reverse-sort --size-sort $(BINDIR)/$(BINELF) | head -n10 | cat -n # Output legend: man nm
	@echo "\n... and corresponging source files to blame.\n"
	$(NM) --reverse-sort --size-sort -S -tx $(BINDIR)/$(BINELF) | head -10 | cut -d':' -f2 | cut -d' ' -f1 | $(A2L) -e $(BINDIR)/$(BINELF) | cat -n # Output legend: man addr2line

# 优化内存,效果非常显著
release-memopt: DEFS+=-DCUSTOM_NEW -DNO_EXCEPTIONS
release-memopt: CFLAGS+=-Os -ffunction-sections -fdata-sections -fno-builtin # -flto
release-memopt: CXXFLAGS+=-Os -fno-exceptions -ffunction-sections -fdata-sections -fno-builtin -fno-rtti # -flto
#fno-buildin 不使用内联函数
release-memopt: LDFLAGS+=-Os -Wl,-gc-sections  -flto
release-memopt: release

release:  $(BINDIR)/$(BINHEX) $(BINDIR)/$(BINARY)

$(BINDIR)/$(BINHEX): $(BINDIR)/$(BINELF)
	$(CP) -O ihex $< $@
	@echo "Objcopy from ELF to IHEX complete!\n"

$(BINDIR)/$(BINARY):$(BINDIR)/$(BINELF)
	$(CP) -S -O binary $< $@
	@echo "Objcopy from ELF to BIN complete!\n"
##
# C++ linking is used.
#
# Change
#   $(CXX) $(OBJECTS) $(LDFLAGS) -o $@ to 
#   $(CC) $(OBJECTS) $(LDFLAGS) -o $@ if
#   C linker is required.
$(BINDIR)/$(BINELF): $(OBJECTS)
	mkdir -p $(@D)
	$(CXX) $(LDFLAGS) $^ -o $@
	@echo "Linking complete!\n"
	$(SIZE) $(BINDIR)/$(BINELF)

# Include all .d files 
# 这一行必须添加在$(BINDIR)/$(BINELF)目标的后面，否则只能编译改变后相关的文件，不能重新链接，
# 原因还没想明白
-include $(DEPENDENT)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -MMD $< -o $@
	@echo "Compiled "$<"!\n"

%.o: %.c
	$(CC) $(CFLAGS) -MMD $< -o $@
	@echo "Compiled "$<"!\n"

%.o: %.s
	$(CC) $(CFLAGS) $< -o $@
	@echo "Assambled "$<"!\n"

clean:
	rm -f $(DEPENDENT) $(OBJECTS) $(BINDIR)/$(BINELF) $(BINDIR)/$(BINHEX) $(BINDIR)/output.map

j-flash:debug
	@openocd  -f $(STM32_SDK_DIR)/scripts/openocd/stm32f469_discovery_jlink.cfg\
	 -c init \
	 -c targets \
	 -c "halt" \
	 -c "flash write_image erase bin/$(BINELF)" \
	 -c "verify_image bin/outp.elf" \
	 -c "flash info 0"\
	 -c "reset run" \
	 -c shutdown

st-flash: release
	openocd -f  board/stm32f429discovery.cfg\
    -c "init" \
    -c "reset init" \
    -c "flash probe 0"\
    -c "flash info 0"\
    -c "program bin/"$(BINELF)" verify reset" \
    -c "reset run"\
    -c "shutdown"