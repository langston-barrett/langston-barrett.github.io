# Debugging

## Tips

- Try `set -x` in Bash
- Use the `gdb` Python interface (see [gdb](gdb.md))
- Use `strace`

## Tools

- [gdb](gdb.md)
- [rr](https://rr-project.org/)
- [valgrind](https://valgrind.org/)
- Linux:
  - [strace](https://strace.io/)
  - [perf](https://www.man7.org/linux/man-pages/man1/perf.1.html)

## creduce

[creduce](https://embed.cs.utah.edu/creduce/)

```sh
apt-get update && apt-get install -y creduce
creduce --sllooww --timeout 60 --n $(nproc) reduce.sh file.c
```

## halfempty

[halfempty](https://github.com/googleprojectzero/halfempty)

```sh
git clone --branch=master --depth=1 --single-branch https://github.com/googleprojectzero/halfempty
cd halfempty
apt-get update -q
apt-get install -q -y libglib2.0-dev
make -j
```

```sh
#!/usr/bin/env bash

set -eux

result=1
trap 'exit ${result}' EXIT TERM ALRM

if grep interesting /dev/stdin; then
    result=0 # We want this input
else
    result=1 # We don't want this input
fi
exit "${result}"
```

```sh
./halfempty/halfempty --stable --gen-intermediate --output=halfempty.out test.sh input-file
```

## Further reading

- [Debugging tactics](https://twitter.com/richcampbell/status/1332352909451911170?s=09)
- [Why Code Rusts (or, Why Tests Spontanously Fail)](https://checkeagle.com/checklists/tdda/wcr/)
