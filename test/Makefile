all: | test check

clean:
	@rm -f *.{out,diff}

test: clean
	@vim -N -u NONE --noplugin -S test.vim
	@# @/usr/bin/vim -N -u NONE --noplugin -S test.vim # test old vim version

check:
	@git diff --no-index test1.ok test1.out > test1.diff && rm test1.diff && echo "test1 OK" || echo "test1 failed, check test1.diff"
	@git diff --no-index test2.ok test2.out > test2.diff && rm test2.diff && echo "test2 OK" || echo "test2 failed, check test2.diff"
	@git diff --no-index test3.ok test3.out > test3.diff && rm test3.diff && echo "test3 OK" || echo "test3 failed, check test3.diff"
	@git diff --no-index test4.ok test4.out > test4.diff && rm test4.diff && echo "test4 OK" || echo "test4 failed, check test4.diff"
	@git diff --no-index test5.ok test5.out > test5.diff && rm test5.diff && echo "test5 OK" || echo "test5 failed, check test5.diff"
	@git diff --no-index test6.ok test6.out > test6.diff && rm test6.diff && echo "test6 OK" || echo "test6 failed, check test6.diff"
	@git diff --no-index test7.ok test7.out > test7.diff && rm test7.diff && echo "test7 OK" || echo "test7 failed, check test7.diff"
	@git diff --no-index test8.ok test8.out > test8.diff && rm test8.diff && echo "test8 OK" || echo "test8 failed, check test8.diff"
	@git diff --no-index test9.ok test9.out > test9.diff && rm test9.diff && echo "test9 OK" || echo "test9 failed, check test9.diff"
	@git diff --no-index testM.ok testM.out > testM.diff && rm testM.diff && echo "testM OK" || echo "testM failed, check testM.diff"
