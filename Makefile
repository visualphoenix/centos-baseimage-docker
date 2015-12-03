.DEFAULT_GOAL := build

runit-2.1.2-1.el6.x86_64.rpm:
	docker build -t test-builder -f Dockerfile.build . 
	docker run -a stdout -a stderr --rm test-builder | tar xzf -
	rm runit-debuginfo-2.1.2-1.el6.x86_64.rpm

build: runit-2.1.2-1.el6.x86_64.rpm
	docker build -t test .
	docker run -d --name test test
clean:
	rm *.rpm
