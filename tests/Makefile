
all: 4k.bin 2048k.bin 524288k.bin


%k.bin:
	dd if=/dev/urandom of=$@ bs=1024 count=$*