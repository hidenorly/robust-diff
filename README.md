# robust-diff

This robust-diff with cdiff.py can enumerate difference between files which are stored under specified directories. 

The remarkable points are
 - Robust file search
 - Comment ignored diff with cdiff.py which can ignore C/C++ style comments.

Then you can enumerate the actual diff in case of file moved case and comment addition/removal, etc.

```
ruby robust-diff.rb --help
Usage: -s sourceDir -t destDir -o outputDir
    -s, --srcDir=                    Specify srcDir (old)
    -t, --dstDir=                    Specify dstDir (new)
    -f, --filter=                    Specify filename filter regexp
    -I, --ignoreRegExp=              Specify ignore regexp for diff -I
    -d, --useDiff                    Specify if you want to use normal diff command
    -o, --output=                    Specify output path
    -u, --useSourceNameForOutput     Specify if you want to output with the source file basis
    -m, --outputNotFoundFiles        Specify if you want to output not found files
    -j, --numOfThreads=              Specify number of threads (default:10)
    -v, --verbose                    Enable verbose
```

# Example to use

## Basic usage

```
$ ruby robust-diff.rb -s ./test/old -t ./test/new -o result
```

## Advanced usage : specify the file filter

```
$ ruby robust-diff.rb -s old -t new -f "\.patch$" -o result
```

Diff for file with ending with .patch

## Advanced usage : missing files output

```
$ ruby robust-diff.rb -s ./test/old -t ./test/new -o result -m
```

## Advanced usage : diff with normal diff command

```
$ ruby robust-diff.rb -s ./test/old -t ./test/new -o result --useDiff
```
