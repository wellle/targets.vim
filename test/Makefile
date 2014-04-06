all:
	@rm -f *.out
	@vim -N -u NONE --noplugin -S test.vim
	@git diff --no-index test1.ok test1.out && echo "test1 OK" || echo "test1 failed"
	@git diff --no-index test2.ok test2.out && echo "test2 OK" || echo "test2 failed"
	@git diff --no-index test3.ok test3.out && echo "test3 OK" || echo "test3 failed"
	@git diff --no-index test4.ok test4.out && echo "test4 OK" || echo "test4 failed"
