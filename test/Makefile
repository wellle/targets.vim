all:
	@rm -f *.out
	@vim -N -u NONE --noplugin -S test.vim
	@git diff --no-index test1.ok test1.out && echo "test1 OK" || echo "test1 failed"
	@git diff --no-index test2.ok test2.out && echo "test2 OK" || echo "test2 failed"
