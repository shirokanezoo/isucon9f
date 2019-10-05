#!/bin/bash

for file in `\find *.sql -maxdepth 1 -type f | sort`; do
    echo $file
    mysql -uroot isutrain < $file
done
