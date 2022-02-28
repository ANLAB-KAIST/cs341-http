.PHONY: all clean

all: http-server http-client

CPP_FLAGS=-std=c++17 -pthread

http-server: http-server.cpp common.hpp
	c++ ${CPP_FLAGS} -o http-server http-server.cpp

http-client: http-client.cpp common.hpp
	c++ ${CPP_FLAGS} -o http-client http-client.cpp

clean:
	rm -f http-server http-client