default: build

build:
	rebar compile

test: build
	rebar eunit

clean:
	rebar clean
