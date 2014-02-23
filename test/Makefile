all:
	@rm -f *.out
	@vim -N -u NONE --noplugin -S test.vim
	@git diff --no-index test1.ok test1.out && echo "test1 OK" || echo "test1 failed"
