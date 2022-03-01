
all: 4k.bin 2m.bin 512m.bin


%k.bin:
	dd if=/dev/urandom of=$@ bs=1024 count=$*

%m.bin:
	dd if=/dev/urandom of=$@ bs=1048576 count=$*