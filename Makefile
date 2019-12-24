all:
	dune build src/bootalog.a

test:
	dune runtest

clean:
	dune clean
