################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../software/.metadata/.plugins/org.eclipse.cdt.make.core/specs.c 

OBJS += \
./software/.metadata/.plugins/org.eclipse.cdt.make.core/specs.o 

C_DEPS += \
./software/.metadata/.plugins/org.eclipse.cdt.make.core/specs.d 


# Each subdirectory must supply rules for building sources it contributes
software/.metadata/.plugins/org.eclipse.cdt.make.core/%.o: ../software/.metadata/.plugins/org.eclipse.cdt.make.core/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: GCC C Compiler'
	arm-linux-gnueabihf-gcc -DPARALLEL -I/usr/local/Quartus-EDS-14.0/embedded/ip/altera/hps/altera_hps/hwlib/include -O0 -g3 -Wall -c -fmessage-length=0 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


