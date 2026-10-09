obj-m += secmon.o

ccflags-y += -Wall -Wextra -Werror

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

.PHONY: all clean
